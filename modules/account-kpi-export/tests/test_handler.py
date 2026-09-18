"""Behavioral tests for weekly KPI Lambda orchestration."""

from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import io
import json
from pathlib import Path
import sys
import traceback
import unittest


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from cloudbrowser import AccountResolutionError, MetricConflictError
from handler import JobFailedError, handle
from http_client import AmbiguousWriteError, HttpResponseError


NOW = datetime(2026, 9, 15, 8, tzinfo=timezone.utc)
ARN = "arn:aws:lambda:eu-central-1:111122223333:function:account-kpi-export"
TOKENS = {"cloudbrowser": "cloudbrowser-token", "grafana": "grafana-token"}
SENSITIVE = "https://secrets.example/secret-path?token=super-secret-token&client=42"


class AwsClientError(RuntimeError):
    def __init__(self, code, message=SENSITIVE):
        self.response = {"Error": {"Code": code, "Message": message}}
        super().__init__(message)


def config(application=False, cost=True, security=True):
    return {
        "timezone": "Asia/Yerevan",
        "cloudbrowser": {
            "base_url": "https://cloudbrowser.example",
            "client_id": 42,
            "aws_provider_id": 9,
            "token_key": "cloudbrowser",
        },
        "application": {
            "enabled": application,
            "source_type": "prometheus",
            "grafana_url": "https://grafana.example",
            "datasource_uid": "prometheus",
            "uptime_query": "avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)",
            "latency_query": "avg_over_time(latency[$__account_kpi_window] @ $__account_kpi_end_seconds)",
            "token_key": "grafana",
        },
        "cost": {"enabled": cost},
        "security": {"enabled": security, "region": "eu-central-1"},
        "metrics": {"cost": 12, "security": 4, "uptime": 24, "latency": 26},
    }


def aws_only_config(cost=True, security=True):
    value = config(application=False, cost=cost, security=security)
    value["application"] = {"enabled": False}
    return value


def cloudwatch_application_config():
    value = config(application=True)
    value["application"] = {
        "enabled": True,
        "source_type": "cloudwatch_alb",
        "grafana_url": "https://grafana.example",
        "datasource_uid": "cloudwatch",
        "region": "eu-central-1",
        "load_balancer": "app/example/123",
        "token_key": "grafana",
    }
    return value


class Context:
    invoked_function_arn = ARN


class FakeSecrets:
    def __init__(self, value=None):
        self.value = value if value is not None else json.dumps(TOKENS)
        self.calls = []

    def get_secret_value(self, **kwargs):
        self.calls.append(kwargs)
        return {"SecretString": self.value}


class FakeCloudBrowser:
    def __init__(self, outcomes=None, resolution_error=None):
        self.outcomes = list(outcomes or [])
        self.resolution_error = resolution_error
        self.resolutions = []
        self.writes = []

    def resolve_account(self, account_id):
        self.resolutions.append(account_id)
        if self.resolution_error is not None:
            raise self.resolution_error
        return 101

    def write_metric(self, metric_id, account_id, value, record_date):
        self.writes.append((metric_id, account_id, value, record_date))
        outcome = self.outcomes.pop(0) if self.outcomes else "created"
        if isinstance(outcome, Exception):
            raise outcome
        return outcome


class FakeCostExplorer:
    def __init__(self, result=Decimal("12.34567"), error=None):
        self.result = result
        self.error = error
        self.calls = []

    def get_cost_and_usage(self, **kwargs):
        self.calls.append(kwargs)
        if self.error:
            raise self.error
        start = date.fromisoformat(kwargs["TimePeriod"]["Start"])
        end = date.fromisoformat(kwargs["TimePeriod"]["End"])
        results = []
        current = start
        first = True
        while current < end:
            next_day = current + timedelta(days=1)
            amount = str(self.result) if first else "0"
            results.append({
                "TimePeriod": {"Start": current.isoformat(), "End": next_day.isoformat()},
                "Total": {"UnblendedCost": {"Amount": amount, "Unit": "USD"}},
            })
            current = next_day
            first = False
        return {"ResultsByTime": results}


class FakeSecurityHub:
    def __init__(self, findings=None, error=None):
        self.findings = findings if findings is not None else [
            {"Compliance": {"SecurityControlId": "x", "Status": "PASSED"}}
        ]
        self.error = error
        self.standard_calls = []

    def get_enabled_standards(self, **kwargs):
        self.standard_calls.append(kwargs)
        if self.error:
            raise self.error
        return {"StandardsSubscriptions": [{"StandardsStatus": "READY"}]}

    def get_findings(self, **kwargs):
        return {"Findings": self.findings}


class HandlerTests(unittest.TestCase):
    def run_job(self, event, cfg=None, clients=None, output=None):
        env = {"CONFIG_JSON": json.dumps(config() if cfg is None else cfg), "SECRET_ARN": "arn:secret"}
        return handle(event, Context(), environment=env, now=NOW, clients=clients or {}, output=output)

    def test_rejects_invalid_or_extra_scheduler_events(self):
        for event in ({}, {"job": "other"}, {"job": []}, {"job": {}}, {"job": "aws", "date": "2026-01-01"}, ["aws"]):
            with self.subTest(event=event):
                with self.assertRaises(ValueError):
                    self.run_job(event)

    def test_rejects_malformed_configuration_and_lambda_arn(self):
        with self.assertRaises(ValueError):
            self.run_job({"job": "aws"}, cfg={})
        bad_context = type("Context", (), {"invoked_function_arn": "arn:aws:lambda:x:bad:function:y"})()
        with self.assertRaises(ValueError):
            handle({"job": "aws"}, bad_context, environment={"CONFIG_JSON": json.dumps(config()), "SECRET_ARN": "arn:secret"}, now=NOW)

    def test_disabled_job_skips_without_secret_or_cloudbrowser_access(self):
        secret = FakeSecrets()
        cb = FakeCloudBrowser()
        output = []
        result = self.run_job(
            {"job": "application"}, config(application=False),
            {"secretsmanager": secret, "cloudbrowser": cb}, output.append,
        )
        self.assertEqual(secret.calls, [])
        self.assertEqual(cb.resolutions, [])
        self.assertEqual(result["metrics"], [{"name": "uptime", "status": "skipped"}, {"name": "latency", "status": "skipped"}])
        self.assertEqual(json.loads(output[0]), result)

    def test_disabled_application_minimal_config_skips_without_any_clients(self):
        secret = FakeSecrets()
        cb = FakeCloudBrowser()
        cost = FakeCostExplorer()
        security = FakeSecurityHub()
        output = []

        result = self.run_job(
            {"job": "application"}, aws_only_config(),
            {"secretsmanager": secret, "cloudbrowser": cb, "cost_explorer": cost, "securityhub": security}, output.append,
        )

        self.assertEqual(secret.calls, [])
        self.assertEqual(cb.resolutions, [])
        self.assertEqual(cost.calls, [])
        self.assertEqual(security.standard_calls, [])
        self.assertEqual(result["metrics"], [{"name": "uptime", "status": "skipped"}, {"name": "latency", "status": "skipped"}])
        self.assertEqual(json.loads(output[0]), result)

    def test_aws_job_accepts_minimal_disabled_application_config(self):
        result = self.run_job(
            {"job": "aws"}, aws_only_config(security=False),
            {"secretsmanager": FakeSecrets(), "cloudbrowser": FakeCloudBrowser(), "cost_explorer": FakeCostExplorer()},
        )

        self.assertEqual(result["metrics"], [{"name": "cost", "status": "created"}, {"name": "security", "status": "skipped"}])

    def test_disabled_application_allows_empty_or_null_grafana_values_but_enabled_requires_them(self):
        disabled = config(application=False, cost=False, security=False)
        disabled["application"].update({
            "grafana_url": "", "datasource_uid": None, "uptime_query": "", "latency_query": None, "token_key": "",
        })
        result = self.run_job({"job": "application"}, disabled, output=lambda _: None)
        self.assertEqual([metric["status"] for metric in result["metrics"]], ["skipped", "skipped"])

        enabled = config(application=True)
        del enabled["application"]["uptime_query"]
        with self.assertRaises(ValueError):
            self.run_job({"job": "application"}, enabled)

    def test_enabled_application_requires_window_and_end_placeholders(self):
        for query in (
            "avg_over_time(up[7d])",
            "avg_over_time(up[$__account_kpi_window])",
            "avg_over_time(up[7d] @ $__account_kpi_end_seconds)",
        ):
            with self.subTest(query=query):
                enabled = config(application=True)
                enabled["application"]["uptime_query"] = query
                with self.assertRaises(ValueError):
                    self.run_job({"job": "application"}, enabled)

    def test_cloudwatch_application_requires_region_and_load_balancer(self):
        for key in ("region", "load_balancer"):
            with self.subTest(key=key):
                enabled = cloudwatch_application_config()
                enabled["application"][key] = ""
                with self.assertRaises(ValueError):
                    self.run_job({"job": "application"}, enabled)

    def test_application_rejects_unknown_source_type(self):
        enabled = config(application=True)
        enabled["application"]["source_type"] = "unknown"

        with self.assertRaises(ValueError):
            self.run_job({"job": "application"}, enabled)

    def test_application_collects_pair_before_writes_and_rounds_json_numbers(self):
        secret = FakeSecrets()
        cb = FakeCloudBrowser()
        collected = []

        def application_collector(*args):
            collected.append(args)
            return Decimal("99.1234567"), Decimal("0.1234567")

        result = self.run_job(
            {"job": "application"}, config(application=True),
            {"secretsmanager": secret, "cloudbrowser": cb, "application_collector": application_collector},
        )
        self.assertEqual(secret.calls, [{"SecretId": "arn:secret"}])
        self.assertEqual(len(collected), 1)
        self.assertEqual(collected[0][4], datetime(2026, 9, 6, 20, tzinfo=timezone.utc))
        self.assertEqual(collected[0][5], datetime(2026, 9, 13, 20, tzinfo=timezone.utc))
        self.assertEqual(cb.resolutions, ["111122223333"])
        self.assertEqual([write[:3] for write in cb.writes], [(24, 101, 99.123457), (26, 101, 0.123457)])
        self.assertTrue(all(isinstance(write[2], float) for write in cb.writes))
        self.assertEqual(cb.writes[0][3], "2026-09-09T00:00:00.000Z")
        self.assertEqual(result["period"], {"start_date": "2026-09-07", "end_date": "2026-09-14"})
        self.assertEqual([metric["status"] for metric in result["metrics"]], ["created", "created"])

    def test_cloudwatch_application_dispatches_alb_settings_and_writes_pair(self):
        cb = FakeCloudBrowser()
        collected = []

        def application_collector(*args):
            collected.append(args)
            return Decimal("99.5"), Decimal("0.25")

        result = self.run_job(
            {"job": "application"},
            cloudwatch_application_config(),
            {
                "secretsmanager": FakeSecrets(),
                "cloudbrowser": cb,
                "application_collector": application_collector,
            },
        )

        self.assertEqual(len(collected), 1)
        self.assertEqual(collected[0][0:4], (
            "https://grafana.example",
            "cloudwatch",
            "eu-central-1",
            "app/example/123",
        ))
        self.assertEqual(collected[0][4], datetime(2026, 9, 6, 20, tzinfo=timezone.utc))
        self.assertEqual(collected[0][5], datetime(2026, 9, 13, 20, tzinfo=timezone.utc))
        self.assertEqual(collected[0][6], "grafana-token")
        self.assertEqual([write[:3] for write in cb.writes], [
            (24, 101, 99.5),
            (26, 101, 0.25),
        ])
        self.assertEqual([metric["status"] for metric in result["metrics"]], [
            "created",
            "created",
        ])

    def test_invalid_application_pair_does_not_write_either_metric(self):
        cb = FakeCloudBrowser()
        with self.assertRaises(JobFailedError):
            self.run_job(
                {"job": "application"}, config(application=True),
                {"secretsmanager": FakeSecrets(), "cloudbrowser": cb, "application_collector": lambda *args: (_ for _ in ()).throw(ValueError("bad metric"))},
            )
        self.assertEqual(cb.writes, [])

    def test_out_of_range_injected_application_pair_does_not_write_either_metric(self):
        cb = FakeCloudBrowser()
        with self.assertRaises(JobFailedError):
            self.run_job(
                {"job": "application"}, config(application=True),
                {"secretsmanager": FakeSecrets(), "cloudbrowser": cb, "application_collector": lambda *args: (Decimal("100.000001"), Decimal("0"))},
            )
        self.assertEqual(cb.writes, [])

    def test_aws_sources_are_independent_and_round_to_four_places(self):
        cb = FakeCloudBrowser()
        cost = FakeCostExplorer(Decimal("12.34567"))
        security = FakeSecurityHub([
            {"Compliance": {"SecurityControlId": "one", "Status": "PASSED"}},
            {"Compliance": {"SecurityControlId": "two", "Status": "PASSED"}},
            {"Compliance": {"SecurityControlId": "three", "Status": "FAILED"}},
        ])
        result = self.run_job(
            {"job": "aws"}, clients={"secretsmanager": FakeSecrets(), "cloudbrowser": cb, "cost_explorer": cost, "securityhub": security},
        )
        self.assertEqual([write[:3] for write in cb.writes], [(12, 101, 12.3457), (4, 101, 66.6667)])
        self.assertEqual([metric["status"] for metric in result["metrics"]], ["created", "created"])

    def test_injectable_client_factory_avoids_boto3_for_enabled_aws_job(self):
        secret = FakeSecrets()
        cost = FakeCostExplorer()
        calls = []

        def factory(service, **kwargs):
            calls.append((service, kwargs))
            return {"secretsmanager": secret, "ce": cost}[service]

        result = handle(
            {"job": "aws"}, Context(), environment={"CONFIG_JSON": json.dumps(config(security=False)), "SECRET_ARN": "arn:secret"},
            now=NOW, clients={"cloudbrowser": FakeCloudBrowser()}, factories={"client": factory}, output=lambda _: None,
        )
        self.assertEqual([metric["status"] for metric in result["metrics"]], ["created", "skipped"])
        self.assertEqual(calls, [("secretsmanager", {}), ("ce", {})])

    def test_aws_attempts_other_source_after_failure_and_reports_sanitized_summary(self):
        cb = FakeCloudBrowser()
        output = []
        with self.assertRaises(JobFailedError) as raised:
            self.run_job(
                {"job": "aws"},
                clients={"secretsmanager": FakeSecrets(), "cloudbrowser": cb, "cost_explorer": FakeCostExplorer(error=ValueError("cloudbrowser-token leaked")), "securityhub": FakeSecurityHub()},
                output=output.append,
            )
        self.assertNotIn("cloudbrowser-token", str(raised.exception))
        self.assertEqual([write[0] for write in cb.writes], [4])
        summary = json.loads(output[0])
        self.assertEqual(
            summary["metrics"],
            [
                {"name": "cost", "status": "failed", "stage": "source", "reason": "unexpected_error"},
                {"name": "security", "status": "created"},
            ],
        )
        self.assertEqual(set(summary), {"job", "account", "period", "record_date", "metrics"})
        self.assertNotIn("token", output[0])

    def test_bootstrap_failures_tag_every_enabled_metric_without_leaking_sensitive_values(self):
        cases = [
            (
                "secret",
                {"secretsmanager": FakeSecrets(), "cloudbrowser": FakeCloudBrowser()},
                AwsClientError("AccessDeniedException"),
                "bootstrap_secret",
                "aws_access_denied",
            ),
            (
                "account",
                {"secretsmanager": FakeSecrets(), "cloudbrowser": FakeCloudBrowser(resolution_error=AccountResolutionError(SENSITIVE))},
                None,
                "bootstrap_cloudbrowser_account",
                "account_resolution",
            ),
            (
                "secret_auth",
                {"secretsmanager": FakeSecrets(), "cloudbrowser": FakeCloudBrowser()},
                AwsClientError("InvalidClientTokenId"),
                "bootstrap_secret",
                "aws_auth",
            ),
        ]

        for name, clients, secret_error, stage, reason in cases:
            with self.subTest(name=name):
                if secret_error is not None:
                    clients["secretsmanager"].get_secret_value = lambda **kwargs: (_ for _ in ()).throw(secret_error)
                output = []
                with self.assertRaises(JobFailedError) as raised:
                    self.run_job({"job": "aws"}, clients=clients, output=output.append)
                summary = json.loads(output[0])
                self.assertEqual(
                    summary["metrics"],
                    [
                        {"name": "cost", "status": "failed", "stage": stage, "reason": reason},
                        {"name": "security", "status": "failed", "stage": stage, "reason": reason},
                    ],
                )
                self.assertNotIn(SENSITIVE, output[0])
                self.assertNotIn(SENSITIVE, str(raised.exception))
                self.assertNotIn("AwsClientError", output[0])

    def test_source_failures_have_safe_actionable_reasons(self):
        cases = [
            (AwsClientError("AccessDeniedException"), "aws_access_denied"),
            (HttpResponseError(401), "http_unauthorized"),
            (HttpResponseError(403), "http_forbidden"),
            (HttpResponseError(429), "http_throttled"),
            (HttpResponseError(503), "http_server_error"),
            (HttpResponseError("network"), "network_error"),
            (TimeoutError(SENSITIVE), "timeout"),
            (ValueError("Cost Explorer returned malformed ResultsByTime"), "malformed_response"),
            (RuntimeError(SENSITIVE), "unexpected_error"),
        ]

        for error, reason in cases:
            with self.subTest(reason=reason):
                output = []
                with self.assertRaises(JobFailedError) as raised:
                    self.run_job(
                        {"job": "aws"},
                        clients={
                            "secretsmanager": FakeSecrets(),
                            "cloudbrowser": FakeCloudBrowser(),
                            "cost_explorer": FakeCostExplorer(error=error),
                            "securityhub": FakeSecurityHub(),
                        },
                        output=output.append,
                    )
                failed = json.loads(output[0])["metrics"][0]
                self.assertEqual(
                    failed,
                    {"name": "cost", "status": "failed", "stage": "source", "reason": reason},
                )
                self.assertNotIn(SENSITIVE, output[0])
                self.assertNotIn(SENSITIVE, str(raised.exception))
                self.assertNotIn(type(error).__name__, output[0])

    def test_ambiguous_write_has_safe_write_stage_and_reason(self):
        output = []
        with self.assertRaises(JobFailedError):
            self.run_job(
                {"job": "aws"},
                clients={
                    "secretsmanager": FakeSecrets(),
                    "cloudbrowser": FakeCloudBrowser([AmbiguousWriteError(503), "created"]),
                    "cost_explorer": FakeCostExplorer(),
                    "securityhub": FakeSecurityHub(),
                },
                output=output.append,
            )
        self.assertEqual(
            json.loads(output[0])["metrics"][0],
            {"name": "cost", "status": "failed", "stage": "write", "reason": "ambiguous_write"},
        )

    def test_partial_retry_dedupes_success_and_retries_failed_metric(self):
        cb = FakeCloudBrowser(["created", "skipped_duplicate", "created"])
        with self.assertRaises(JobFailedError):
            self.run_job(
                {"job": "aws"},
                clients={"secretsmanager": FakeSecrets(), "cloudbrowser": cb, "cost_explorer": FakeCostExplorer(), "securityhub": FakeSecurityHub(error=ValueError("unavailable"))},
            )
        result = self.run_job(
            {"job": "aws"},
            clients={"secretsmanager": FakeSecrets(), "cloudbrowser": cb, "cost_explorer": FakeCostExplorer(), "securityhub": FakeSecurityHub()},
        )
        self.assertEqual([metric["status"] for metric in result["metrics"]], ["skipped_duplicate", "created"])

    def test_conflicts_are_reported_then_raise_without_exception_context(self):
        output = []
        with self.assertRaises(JobFailedError) as raised:
            self.run_job(
                {"job": "aws"},
                clients={"secretsmanager": FakeSecrets(), "cloudbrowser": FakeCloudBrowser([MetricConflictError("secret detail"), "created"]), "cost_explorer": FakeCostExplorer(), "securityhub": FakeSecurityHub()},
                output=output.append,
            )
        self.assertIsNone(raised.exception.__context__)
        self.assertEqual(json.loads(output[0])["metrics"][0]["status"], "conflict")
        self.assertNotIn("stage", json.loads(output[0])["metrics"][0])
        self.assertNotIn("reason", json.loads(output[0])["metrics"][0])

    def test_secret_errors_do_not_leak_values_or_reach_downstream_clients(self):
        for value in ("not json " + SENSITIVE, json.dumps(["not", "object", SENSITIVE])):
            output = []
            secret = FakeSecrets(value)
            cb = FakeCloudBrowser()
            cost = FakeCostExplorer()
            security = FakeSecurityHub()
            with self.subTest(value=value), self.assertRaises(JobFailedError) as raised:
                self.run_job(
                    {"job": "aws"}, clients={"secretsmanager": secret, "cloudbrowser": cb, "cost_explorer": cost, "securityhub": security}, output=output.append,
                )
            self.assertNotIn(SENSITIVE, str(raised.exception))
            self.assertNotIn(SENSITIVE, output[0])
            self.assertEqual(cb.resolutions, [])
            self.assertEqual(cost.calls, [])
            self.assertEqual(security.standard_calls, [])

        output = []
        with self.assertRaises(JobFailedError):
            handle(
                {"job": "aws"}, Context(), environment={"CONFIG_JSON": json.dumps(config())}, now=NOW,
                clients={"secretsmanager": FakeSecrets()}, output=output.append,
            )
        self.assertNotIn("arn:secret", output[0])

    def test_missing_cloudbrowser_token_fails_before_any_downstream_call(self):
        secret = FakeSecrets(json.dumps({"grafana": "grafana-token"}))
        cb = FakeCloudBrowser()
        cost = FakeCostExplorer()
        security = FakeSecurityHub()
        with self.assertRaises(JobFailedError):
            self.run_job(
                {"job": "aws"},
                clients={"secretsmanager": secret, "cloudbrowser": cb, "cost_explorer": cost, "securityhub": security}, output=lambda _: None,
            )
        self.assertEqual(secret.calls, [{"SecretId": "arn:secret"}])
        self.assertEqual(cb.resolutions, [])
        self.assertEqual(cost.calls, [])
        self.assertEqual(security.standard_calls, [])

    def test_missing_grafana_token_fails_before_any_downstream_call(self):
        secret = FakeSecrets(json.dumps({"cloudbrowser": "cloudbrowser-token"}))
        cb = FakeCloudBrowser()
        cost = FakeCostExplorer()
        security = FakeSecurityHub()
        collector_calls = []
        with self.assertRaises(JobFailedError):
            self.run_job(
                {"job": "application"}, config(application=True),
                {
                    "secretsmanager": secret,
                    "cloudbrowser": cb,
                    "cost_explorer": cost,
                    "securityhub": security,
                    "application_collector": lambda *args: collector_calls.append(args),
                }, output=lambda _: None,
            )
        self.assertEqual(secret.calls, [{"SecretId": "arn:secret"}])
        self.assertEqual(cb.resolutions, [])
        self.assertEqual(cost.calls, [])
        self.assertEqual(security.standard_calls, [])
        self.assertEqual(collector_calls, [])

    def test_aws_job_with_only_valid_cloudbrowser_token_uses_isolated_dependencies(self):
        secret = FakeSecrets(json.dumps({"cloudbrowser": "cloudbrowser-token"}))
        cb = FakeCloudBrowser()
        cost = FakeCostExplorer()
        security = FakeSecurityHub()
        result = self.run_job(
            {"job": "aws"}, aws_only_config(security=False),
            {"secretsmanager": secret, "cloudbrowser": cb, "cost_explorer": cost, "securityhub": security}, output=lambda _: None,
        )
        self.assertEqual(secret.calls, [{"SecretId": "arn:secret"}])
        self.assertEqual(cb.resolutions, ["111122223333"])
        self.assertEqual(cost.calls, [{
            "TimePeriod": {"Start": "2026-09-07", "End": "2026-09-14"},
            "Granularity": "DAILY",
            "Metrics": ["UnblendedCost"],
            "Filter": {"Dimensions": {"Key": "LINKED_ACCOUNT", "Values": ["111122223333"]}},
        }])
        self.assertEqual(security.standard_calls, [])
        self.assertEqual([write[:3] for write in cb.writes], [(12, 101, 12.3457)])
        self.assertEqual(result["metrics"], [{"name": "cost", "status": "created"}, {"name": "security", "status": "skipped"}])

    def test_formatted_handler_failure_traceback_has_no_secret_or_source_detail(self):
        sensitive_detail = "-".join(("never", "log", "secret"))
        try:
            self.run_job(
                {"job": "aws"},
                clients={"secretsmanager": FakeSecrets(), "cloudbrowser": FakeCloudBrowser(), "cost_explorer": FakeCostExplorer(error=ValueError(sensitive_detail)), "securityhub": FakeSecurityHub()},
            )
        except JobFailedError as error:
            trace = "".join(traceback.format_exception(type(error), error, error.__traceback__))
        else:
            self.fail("expected JobFailedError")
        self.assertNotIn(sensitive_detail, trace)
        self.assertNotIn("cloudbrowser-token", trace)


if __name__ == "__main__":
    unittest.main()
