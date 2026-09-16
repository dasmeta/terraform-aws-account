"""AWS Lambda orchestration for account-scoped weekly KPI exports."""

import json
import os
import re
from http.client import HTTPException
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from urllib.error import HTTPError, URLError

from aws_metrics import collect_cost, collect_security_score
from cloudbrowser import AccountResolutionError, CloudBrowserClient, MetricConflictError
from grafana import END_SECONDS_PLACEHOLDER, WINDOW_PLACEHOLDER, collect_application_metrics
from http_client import AmbiguousWriteError, HttpResponseError
from reporting_period import previous_week


_ACCOUNT_ARN = re.compile(r"^arn:[^:]+:lambda:[^:]+:(\d{12}):function:[^:]+(?:[:].*)?$")
_EVENTS = {"application", "aws"}
_CONFIG_KEYS = {"timezone", "cloudbrowser", "application", "cost", "security", "metrics"}
_APPLICATION_KEYS = {"enabled", "grafana_url", "datasource_uid", "uptime_query", "latency_query", "token_key"}
_CONFIG_GROUPS = {
    "cloudbrowser": {"base_url", "client_id", "aws_provider_id", "token_key"},
    "cost": {"enabled"},
    "security": {"enabled", "region"},
    "metrics": {"cost", "security", "uptime", "latency"},
}
_AWS_ACCESS_DENIED_CODE = re.compile(
    r"^(?:AccessDenied(?:Exception)?|Unauthorized(?:Operation|Exception)?)$"
)
_AWS_AUTH_CODE = re.compile(
    r"^(?:ExpiredToken(?:Exception)?|InvalidClientTokenId|SignatureDoesNotMatch|UnrecognizedClientException)$"
)
_SECRET_ERROR_MESSAGES = frozenset(
    {"missing secret ARN", "invalid secret", "missing secret token"}
)
_MALFORMED_RESPONSE_MESSAGES = frozenset(
    {
        "CloudBrowser response has no data list",
        "CloudBrowser entity is invalid",
        "CloudBrowser entity attributes are invalid",
        "Cost Explorer returned a missing TimePeriod",
        "Cost Explorer returned a malformed TimePeriod",
        "Cost Explorer returned a non-daily TimePeriod",
        "Cost Explorer returned malformed ResultsByTime",
        "Cost Explorer returned a malformed daily bucket",
        "Cost Explorer returned an incomplete UnblendedCost total",
        "Cost Explorer returned an invalid UnblendedCost amount",
        "Cost Explorer returned a non-finite UnblendedCost",
        "Cost Explorer returned no UnblendedCost totals",
        "Cost Explorer did not return every daily TimePeriod",
        "Grafana returned an unsuccessful response",
        "Grafana returned malformed data",
        "Grafana scalar result must contain one value",
        "Grafana vector result is malformed",
        "Grafana vector series must contain one value",
    }
)


class JobFailedError(RuntimeError):
    """A retryable invocation failure whose details have not been logged."""


def _invalid_config():
    raise ValueError("invalid CONFIG_JSON")


def _is_positive_integer(value):
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _nonempty_string(value):
    return isinstance(value, str) and bool(value.strip())


def _valid_grafana_query_template(value):
    return (
        _nonempty_string(value)
        and WINDOW_PLACEHOLDER in value
        and END_SECONDS_PLACEHOLDER in value
    )


def _configuration(environment):
    raw_config = environment.get("CONFIG_JSON")
    if not isinstance(raw_config, str):
        _invalid_config()
    try:
        config = json.loads(raw_config)
    except (TypeError, ValueError):
        _invalid_config()
    if not isinstance(config, dict) or set(config) != _CONFIG_KEYS:
        _invalid_config()
    for group, keys in _CONFIG_GROUPS.items():
        if not isinstance(config.get(group), dict) or set(config[group]) != keys:
            _invalid_config()
    if not _nonempty_string(config["timezone"]):
        _invalid_config()
    cloudbrowser = config["cloudbrowser"]
    if not (
        _nonempty_string(cloudbrowser["base_url"])
        and _is_positive_integer(cloudbrowser["client_id"])
        and _is_positive_integer(cloudbrowser["aws_provider_id"])
        and _nonempty_string(cloudbrowser["token_key"])
    ):
        _invalid_config()
    application = config.get("application")
    if (
        not isinstance(application, dict)
        or "enabled" not in application
        or not set(application).issubset(_APPLICATION_KEYS)
        or not isinstance(application["enabled"], bool)
    ):
        _invalid_config()
    if application["enabled"] and (
        set(application) != _APPLICATION_KEYS
        or not all(
            _nonempty_string(application[key])
            for key in ("grafana_url", "datasource_uid", "uptime_query", "latency_query", "token_key")
        )
        or not all(
            _valid_grafana_query_template(application[key])
            for key in ("uptime_query", "latency_query")
        )
    ):
        _invalid_config()
    if not isinstance(config["cost"]["enabled"], bool):
        _invalid_config()
    if not isinstance(config["security"]["enabled"], bool) or not _nonempty_string(config["security"]["region"]):
        _invalid_config()
    if not all(_is_positive_integer(value) for value in config["metrics"].values()):
        _invalid_config()
    return config


def _event_job(event):
    if (
        not isinstance(event, dict)
        or set(event) != {"job"}
        or not isinstance(event["job"], str)
        or event["job"] not in _EVENTS
    ):
        raise ValueError("invalid scheduler event")
    return event["job"]


def _runtime_account(context):
    arn = getattr(context, "invoked_function_arn", None)
    if not isinstance(arn, str):
        raise ValueError("invalid Lambda invocation ARN")
    match = _ACCOUNT_ARN.fullmatch(arn)
    if match is None:
        raise ValueError("invalid Lambda invocation ARN")
    return match.group(1)


def _summary(job, account, window, metrics):
    return {
        "job": job,
        "account": account,
        "period": {"start_date": window.start_date.isoformat(), "end_date": window.end_date.isoformat()},
        "record_date": window.record_date,
        "metrics": metrics,
    }


def _emit(output, summary):
    output(json.dumps(summary, sort_keys=True, separators=(",", ":")))


def _failed(output, summary):
    _emit(output, summary)
    raise JobFailedError("weekly KPI job failed") from None


def _metric_entries(job, config):
    if job == "application":
        enabled = config["application"]["enabled"]
        return [{"name": "uptime", "status": "pending" if enabled else "skipped"}, {"name": "latency", "status": "pending" if enabled else "skipped"}]
    return [
        {"name": "cost", "status": "pending" if config["cost"]["enabled"] else "skipped"},
        {"name": "security", "status": "pending" if config["security"]["enabled"] else "skipped"},
    ]


def _client(name, clients, factory, region=None):
    aliases = {"secretsmanager": ("secretsmanager", "secrets_manager"), "cost_explorer": ("cost_explorer", "ce"), "securityhub": ("securityhub",)}
    for alias in aliases[name]:
        if alias in clients:
            return clients[alias]
    service = {"secretsmanager": "secretsmanager", "cost_explorer": "ce", "securityhub": "securityhub"}[name]
    if factory is None:
        import boto3
        factory = boto3.client
    kwargs = {} if region is None else {"region_name": region}
    return factory(service, **kwargs)


def _secret_tokens(secret_client, secret_arn, cloudbrowser_key, grafana_key=None):
    if not _nonempty_string(secret_arn):
        raise ValueError("missing secret ARN")
    response = secret_client.get_secret_value(SecretId=secret_arn)
    if not isinstance(response, dict) or not isinstance(response.get("SecretString"), str):
        raise ValueError("invalid secret")
    try:
        tokens = json.loads(response["SecretString"])
    except (TypeError, ValueError):
        raise ValueError("invalid secret") from None
    if not isinstance(tokens, dict):
        raise ValueError("invalid secret")
    required = [cloudbrowser_key] + ([grafana_key] if grafana_key is not None else [])
    values = {}
    for key in required:
        value = tokens.get(key)
        if not _nonempty_string(value):
            raise ValueError("missing secret token")
        values[key] = value
    return values


def _round_number(value, places):
    try:
        decimal_value = Decimal(str(value))
    except (InvalidOperation, ValueError):
        raise ValueError("metric value is invalid") from None
    if not decimal_value.is_finite():
        raise ValueError("metric value is invalid")
    rounded = decimal_value.quantize(Decimal("1").scaleb(-places), rounding=ROUND_HALF_UP)
    return float(rounded)


def _application_pair(value_uptime, value_latency):
    """Defend the pair contract at the orchestration boundary as well."""

    try:
        uptime = Decimal(str(value_uptime))
        latency = Decimal(str(value_latency))
    except (InvalidOperation, ValueError):
        raise ValueError("application metric value is invalid") from None
    if not uptime.is_finite() or not latency.is_finite() or uptime < 0 or uptime > 100 or latency < 0:
        raise ValueError("application metric value is invalid")
    return uptime, latency


def _http_reason(status):
    if status == 401:
        return "http_unauthorized"
    if status == 403:
        return "http_forbidden"
    if status == 429:
        return "http_throttled"
    if isinstance(status, int) and not isinstance(status, bool) and 500 <= status <= 599:
        return "http_server_error"
    if status == "network":
        return "network_error"
    return None


def _aws_reason(error):
    response = getattr(error, "response", None)
    if not isinstance(response, dict):
        return None
    error_data = response.get("Error")
    if not isinstance(error_data, dict):
        return None
    code = error_data.get("Code")
    if not isinstance(code, str):
        return None
    if _AWS_ACCESS_DENIED_CODE.fullmatch(code):
        return "aws_access_denied"
    if _AWS_AUTH_CODE.fullmatch(code):
        return "aws_auth"
    return None


def _failure_reason(error):
    """Return one safe diagnostic category without exposing exception content."""

    if isinstance(error, AmbiguousWriteError):
        return "ambiguous_write"
    if isinstance(error, AccountResolutionError):
        return "account_resolution"
    aws_reason = _aws_reason(error)
    if aws_reason is not None:
        return aws_reason
    if isinstance(error, HttpResponseError):
        return _http_reason(error.status) or "unexpected_error"
    if isinstance(error, HTTPError):
        return _http_reason(error.code) or "unexpected_error"
    if isinstance(error, TimeoutError):
        return "timeout"
    if isinstance(error, (URLError, OSError, HTTPException)):
        return "network_error"
    if isinstance(error, ValueError):
        message = str(error)
        if message in _SECRET_ERROR_MESSAGES:
            return "secret_invalid"
        if message == "CloudBrowser token contains unsafe characters":
            return "authentication"
        if message in _MALFORMED_RESPONSE_MESSAGES:
            return "malformed_response"
    return "unexpected_error"


def _set_failed(entry, stage, error):
    entry["status"] = "failed"
    entry["stage"] = stage
    entry["reason"] = _failure_reason(error)


def _set_write_status(entry, operation):
    try:
        entry["status"] = operation()
    except MetricConflictError:
        entry["status"] = "conflict"
    except Exception as error:
        _set_failed(entry, "write", error)


def _has_failure(entries):
    return any(entry["status"] in ("failed", "conflict") for entry in entries)


def handle(event, context, environment=None, now=None, clients=None, factories=None, client_factory=None, output=None):
    """Run one scheduler job with injectable dependencies for focused tests."""

    environment = os.environ if environment is None else environment
    clients = {} if clients is None else clients
    factories = {} if factories is None else factories
    if not isinstance(factories, dict):
        raise ValueError("factories must be a mapping")
    if client_factory is None:
        client_factory = factories.get("client") or factories.get("aws_client")
    output = print if output is None else output
    job = _event_job(event)
    config = _configuration(environment)
    account = _runtime_account(context)
    invoked_at = datetime.now(timezone.utc) if now is None else now
    if not isinstance(invoked_at, datetime) or invoked_at.tzinfo is None or invoked_at.utcoffset() is None:
        raise ValueError("now must be timezone-aware")
    window = previous_week(invoked_at.astimezone(timezone.utc), config["timezone"])
    entries = _metric_entries(job, config)
    summary = _summary(job, account, window, entries)
    enabled_entries = [entry for entry in entries if entry["status"] == "pending"]
    if not enabled_entries:
        _emit(output, summary)
        return summary

    application = config["application"]
    cloudbrowser_config = config["cloudbrowser"]
    try:
        secret_client = _client("secretsmanager", clients, client_factory)
        tokens = _secret_tokens(
            secret_client,
            environment.get("SECRET_ARN"),
            cloudbrowser_config["token_key"],
            application["token_key"] if job == "application" else None,
        )
    except Exception as error:
        for entry in enabled_entries:
            _set_failed(entry, "bootstrap_secret", error)
        _failed(output, summary)

    try:
        cloudbrowser = clients.get("cloudbrowser")
        if cloudbrowser is None:
            cloudbrowser_factory = clients.get("cloudbrowser_factory") or factories.get("cloudbrowser")
            if cloudbrowser_factory is None:
                cloudbrowser = CloudBrowserClient(
                    cloudbrowser_config["base_url"], tokens[cloudbrowser_config["token_key"]],
                    cloudbrowser_config["client_id"], cloudbrowser_config["aws_provider_id"],
                )
            else:
                cloudbrowser = cloudbrowser_factory(
                    cloudbrowser_config["base_url"], tokens[cloudbrowser_config["token_key"]],
                    cloudbrowser_config["client_id"], cloudbrowser_config["aws_provider_id"],
                )
        cloudbrowser_account = cloudbrowser.resolve_account(account)
    except Exception as error:
        for entry in enabled_entries:
            _set_failed(entry, "bootstrap_cloudbrowser_account", error)
        _failed(output, summary)

    if job == "application":
        uptime_entry, latency_entry = entries
        try:
            collector = clients.get("application_collector", collect_application_metrics)
            uptime, latency = collector(
                application["grafana_url"], application["datasource_uid"], application["uptime_query"],
                application["latency_query"], window.start_utc, window.end_utc,
                tokens[application["token_key"]],
            )
            uptime, latency = _application_pair(uptime, latency)
            rounded = {"uptime": _round_number(uptime, 6), "latency": _round_number(latency, 6)}
        except Exception as error:
            _set_failed(uptime_entry, "source", error)
            _set_failed(latency_entry, "source", error)
        else:
            _set_write_status(uptime_entry, lambda: cloudbrowser.write_metric(config["metrics"]["uptime"], cloudbrowser_account, rounded["uptime"], window.record_date))
            _set_write_status(latency_entry, lambda: cloudbrowser.write_metric(config["metrics"]["latency"], cloudbrowser_account, rounded["latency"], window.record_date))
    else:
        cost_entry, security_entry = entries
        if cost_entry["status"] == "pending":
            try:
                cost_client = _client("cost_explorer", clients, client_factory)
                value = collect_cost(cost_client, account, window.start_date, window.end_date)
                rounded_cost = _round_number(value, 4)
            except Exception as error:
                _set_failed(cost_entry, "source", error)
            else:
                _set_write_status(cost_entry, lambda: cloudbrowser.write_metric(config["metrics"]["cost"], cloudbrowser_account, rounded_cost, window.record_date))
        if security_entry["status"] == "pending":
            try:
                security_client = _client("securityhub", clients, client_factory, config["security"]["region"])
                value = collect_security_score(security_client, account)
                rounded_security = _round_number(value, 4)
            except Exception as error:
                _set_failed(security_entry, "source", error)
            else:
                _set_write_status(security_entry, lambda: cloudbrowser.write_metric(config["metrics"]["security"], cloudbrowser_account, rounded_security, window.record_date))

    if _has_failure(entries):
        _failed(output, summary)
    _emit(output, summary)
    return summary


def lambda_handler(event, context):
    """AWS Lambda entry point."""

    return handle(event, context)
