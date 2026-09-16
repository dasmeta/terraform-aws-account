"""Behavioral tests for Grafana application KPI collection."""

from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
import sys
import unittest
from urllib.parse import parse_qs, urlsplit


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from grafana import (
    collect_application_metrics,
    collect_cloudwatch_alb_metrics,
    query_grafana,
)


REPORTING_START = datetime(2026, 9, 7, 0, 0, tzinfo=timezone.utc)
REPORTING_END = datetime(2026, 9, 14, 0, 0, tzinfo=timezone.utc)
QUERY_TEMPLATE = "metric[$__account_kpi_window] @ $__account_kpi_end_seconds"


class FakeGrafanaTransport:
    def __init__(self, payloads):
        self.payloads = list(payloads)
        self.calls = []

    def __call__(self, method, url, token):
        self.calls.append((method, url, token))
        return self.payloads.pop(0)


class FakeGrafanaPostTransport:
    def __init__(self, payload):
        self.payload = payload
        self.calls = []

    def __call__(self, method, url, token, body=None, idempotent=False):
        self.calls.append((method, url, token, body, idempotent))
        return self.payload


def scalar(value):
    return {
        "status": "success",
        "data": {"resultType": "scalar", "result": [REPORTING_END.timestamp(), value]},
    }


def vector(value):
    return {
        "status": "success",
        "data": {
            "resultType": "vector",
            "result": [{"metric": {"job": "api"}, "value": [REPORTING_END.timestamp(), value]}],
        },
    }


class GrafanaQueryTests(unittest.TestCase):
    def test_scalar_query_encodes_uid_query_and_exact_period_end(self):
        transport = FakeGrafanaTransport([scalar("99.125")])

        result = query_grafana(
            "https://grafana.example///",
            "prometheus/primary uid",
            QUERY_TEMPLATE,
            REPORTING_START,
            REPORTING_END,
            "grafana-secret",
            transport=transport,
        )

        self.assertEqual(result, Decimal("99.125"))
        self.assertEqual(len(transport.calls), 1)
        method, url, token = transport.calls[0]
        self.assertEqual(method, "GET")
        self.assertEqual(token, "grafana-secret")
        parsed = urlsplit(url)
        self.assertEqual(
            parsed.path,
            "/api/datasources/proxy/uid/prometheus%2Fprimary%20uid/api/v1/query",
        )
        self.assertEqual(
            parse_qs(parsed.query),
            {
                "query": ["metric[604800s] @ 1789344000"],
                "time": [str(int(REPORTING_END.timestamp()))],
            },
        )

    def test_vector_query_accepts_one_result_and_value(self):
        transport = FakeGrafanaTransport([vector("0.250")])

        result = query_grafana(
            "https://grafana.example",
            "prometheus",
            QUERY_TEMPLATE,
            REPORTING_START,
            REPORTING_END,
            "token",
            transport=transport,
        )

        self.assertEqual(result, Decimal("0.250"))

    def test_grafana_base_url_rejects_unsafe_components_before_transport(self):
        for grafana_url in (
            "http://grafana.example",
            "https://token@grafana.example",
            "https:///api",
            "https://grafana.example?source=unsafe",
            "https://grafana.example#unsafe",
        ):
            with self.subTest(grafana_url=grafana_url):
                transport = FakeGrafanaTransport([scalar("99")])
                with self.assertRaises(ValueError):
                    query_grafana(
                        grafana_url, "prometheus", QUERY_TEMPLATE,
                        REPORTING_START, REPORTING_END, "grafana-secret", transport=transport,
                    )
                self.assertEqual(transport.calls, [])

    def test_grafana_base_url_accepts_https_host_path_and_port(self):
        transport = FakeGrafanaTransport([scalar("99")])

        result = query_grafana(
            "https://grafana.example:8443/prefix/", "prometheus", QUERY_TEMPLATE,
            REPORTING_START, REPORTING_END, "grafana-secret", transport=transport,
        )

        self.assertEqual(result, Decimal("99"))
        self.assertEqual(
            urlsplit(transport.calls[0][1]).path,
            "/prefix/api/datasources/proxy/uid/prometheus/api/v1/query",
        )

    def test_query_substitutes_both_boundary_placeholders_before_url_encoding(self):
        transport = FakeGrafanaTransport([scalar("99")])

        query_grafana(
            "https://grafana.example",
            "prometheus",
            QUERY_TEMPLATE,
            REPORTING_START,
            REPORTING_END,
            "token",
            transport=transport,
        )

        parsed = urlsplit(transport.calls[0][1])
        self.assertEqual(
            parse_qs(parsed.query)["query"],
            ["metric[604800s] @ 1789344000"],
        )

    def test_query_rejects_missing_required_window_or_end_placeholders(self):
        for query in (
            "metric[7d]",
            "metric[$__account_kpi_window]",
            "metric @ $__account_kpi_end_seconds",
            "metric[$__account_kpi_start_seconds]",
        ):
            with self.subTest(query=query), self.assertRaises(ValueError):
                query_grafana(
                    "https://grafana.example",
                    "prometheus",
                    query,
                    REPORTING_START,
                    REPORTING_END,
                    "token",
                    transport=FakeGrafanaTransport([scalar("99")]),
                )

    def test_query_rejects_error_status_and_malformed_payloads(self):
        payloads = [
            {"status": "error", "error": "bad query"},
            None,
            {"status": "success"},
            {"status": "success", "data": {"resultType": "scalar"}},
            {
                "status": "success",
                "data": {"resultType": "scalar", "result": ["only-one"]},
            },
        ]

        for payload in payloads:
            with self.subTest(payload=payload):
                with self.assertRaises(ValueError):
                    query_grafana(
                        "https://grafana.example",
                        "prometheus",
                        QUERY_TEMPLATE,
                        REPORTING_START,
                        REPORTING_END,
                        "token",
                        transport=FakeGrafanaTransport([payload]),
                    )

    def test_query_rejects_matrix_empty_and_multiple_results(self):
        payloads = [
            {
                "status": "success",
                "data": {"resultType": "matrix", "result": []},
            },
            {
                "status": "success",
                "data": {"resultType": "scalar", "result": []},
            },
            {
                "status": "success",
                "data": {"resultType": "vector", "result": []},
            },
            {
                "status": "success",
                "data": {
                    "resultType": "vector",
                    "result": [
                        {"value": [1, "1"]},
                        {"value": [1, "2"]},
                    ],
                },
            },
        ]

        for payload in payloads:
            with self.subTest(payload=payload):
                with self.assertRaises(ValueError):
                    query_grafana(
                        "https://grafana.example",
                        "prometheus",
                        QUERY_TEMPLATE,
                        REPORTING_START,
                        REPORTING_END,
                        "token",
                        transport=FakeGrafanaTransport([payload]),
                    )

    def test_query_rejects_nonfinite_and_non_numeric_values(self):
        for value in ("NaN", "Infinity", "-Infinity", "not-a-number"):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    query_grafana(
                        "https://grafana.example",
                        "prometheus",
                        QUERY_TEMPLATE,
                        REPORTING_START,
                        REPORTING_END,
                        "token",
                        transport=FakeGrafanaTransport([scalar(value)]),
                    )


class ApplicationMetricPairTests(unittest.TestCase):
    def test_collect_application_metrics_fetches_and_returns_validated_pair(self):
        transport = FakeGrafanaTransport([scalar("99.999999"), vector("0.125000")])

        result = collect_application_metrics(
            "https://grafana.example/",
            "prometheus",
            "avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds) * 100",
            "avg_over_time(request_latency_seconds[$__account_kpi_window] @ $__account_kpi_end_seconds)",
            REPORTING_START,
            REPORTING_END,
            "token",
            transport=transport,
        )

        self.assertEqual(result, (Decimal("99.999999"), Decimal("0.125000")))
        self.assertEqual(len(transport.calls), 2)

    def test_collect_application_metrics_rejects_uptime_outside_inclusive_range(self):
        for uptime in ("-0.000001", "100.000001"):
            with self.subTest(uptime=uptime):
                transport = FakeGrafanaTransport([scalar(uptime), scalar("0")])
                with self.assertRaises(ValueError):
                    collect_application_metrics(
                        "https://grafana.example",
                        "prometheus",
                        QUERY_TEMPLATE,
                        QUERY_TEMPLATE,
                        REPORTING_START,
                        REPORTING_END,
                        "token",
                        transport=transport,
                    )

    def test_collect_application_metrics_rejects_negative_latency(self):
        transport = FakeGrafanaTransport([scalar("100"), scalar("-0.001")])

        with self.assertRaises(ValueError):
            collect_application_metrics(
                "https://grafana.example",
                "prometheus",
                QUERY_TEMPLATE,
                QUERY_TEMPLATE,
                REPORTING_START,
                REPORTING_END,
                "token",
                transport=transport,
            )

    def test_collect_application_metrics_fetches_both_before_range_validation(self):
        transport = FakeGrafanaTransport([scalar("101"), scalar("-1")])

        with self.assertRaises(ValueError):
            collect_application_metrics(
                "https://grafana.example",
                "prometheus",
                QUERY_TEMPLATE,
                QUERY_TEMPLATE,
                REPORTING_START,
                REPORTING_END,
                "token",
                transport=transport,
            )

        self.assertEqual(len(transport.calls), 2)

    def test_collect_application_metrics_uses_exact_normal_short_and_long_local_weeks(self):
        windows = {
            "normal": (
                datetime(2026, 9, 7, 0, 0, tzinfo=timezone.utc),
                datetime(2026, 9, 14, 0, 0, tzinfo=timezone.utc),
                168 * 60 * 60,
            ),
            "dst_short": (
                datetime(2026, 3, 22, 23, 0, tzinfo=timezone.utc),
                datetime(2026, 3, 29, 22, 0, tzinfo=timezone.utc),
                167 * 60 * 60,
            ),
            "dst_long": (
                datetime(2026, 10, 18, 22, 0, tzinfo=timezone.utc),
                datetime(2026, 10, 25, 23, 0, tzinfo=timezone.utc),
                169 * 60 * 60,
            ),
        }

        for name, (start, end, expected_seconds) in windows.items():
            with self.subTest(window=name):
                transport = FakeGrafanaTransport([scalar("99"), scalar("0.25")])
                collect_application_metrics(
                    "https://grafana.example",
                    "prometheus",
                    "uptime[$__account_kpi_window] @ $__account_kpi_end_seconds",
                    "latency[$__account_kpi_window] @ $__account_kpi_end_seconds",
                    start,
                    end,
                    "token",
                    transport=transport,
                )
                queries = [
                    parse_qs(urlsplit(call[1]).query)["query"][0]
                    for call in transport.calls
                ]
                expected = "uptime[{0}s] @ {1}".format(
                    expected_seconds, int(end.timestamp())
                )
                self.assertEqual(queries[0], expected)
                self.assertEqual(
                    int(end.timestamp()) - int(start.timestamp()), expected_seconds
                )


def cloudwatch_frame(ref_id, timestamps, values):
    return {
        "status": 200,
        "frames": [
            {
                "schema": {
                    "refId": ref_id,
                    "fields": [
                        {"name": "Time", "type": "time"},
                        {"name": "Value", "type": "number"},
                    ],
                },
                "data": {"values": [timestamps, values]},
            }
        ],
    }


class CloudWatchAlbMetricTests(unittest.TestCase):
    def test_collects_weekly_alb_pair_and_excludes_inclusive_end_boundary(self):
        start_ms = int(REPORTING_START.timestamp() * 1000)
        end_ms = int(REPORTING_END.timestamp() * 1000)
        transport = FakeGrafanaPostTransport(
            {
                "results": {
                    "A": cloudwatch_frame("A", [start_ms, end_ms], [1000, 900]),
                    "B": cloudwatch_frame("B", [start_ms, end_ms], [5, 90]),
                    "C": cloudwatch_frame("C", [start_ms, end_ms], [0.25, 8.5]),
                }
            }
        )

        result = collect_cloudwatch_alb_metrics(
            "https://grafana.example/",
            "cloudwatch",
            "eu-central-1",
            "app/example/123",
            REPORTING_START,
            REPORTING_END,
            "grafana-token",
            transport=transport,
        )

        self.assertEqual(result, (Decimal("99.500"), Decimal("0.25")))
        self.assertEqual(len(transport.calls), 1)
        method, url, token, body, idempotent = transport.calls[0]
        self.assertEqual(method, "POST")
        self.assertEqual(url, "https://grafana.example/api/ds/query")
        self.assertEqual(token, "grafana-token")
        self.assertTrue(idempotent)
        self.assertEqual(body["from"], str(start_ms))
        self.assertEqual(body["to"], str(end_ms))
        self.assertEqual([query["refId"] for query in body["queries"]], ["A", "B", "C"])
        self.assertEqual(
            [query["metricName"] for query in body["queries"]],
            ["RequestCount", "HTTPCode_Target_5XX_Count", "TargetResponseTime"],
        )
        self.assertEqual(
            [query["statistic"] for query in body["queries"]],
            ["Sum", "Sum", "Average"],
        )
        self.assertTrue(all(query["period"] == "604800" for query in body["queries"]))
        self.assertTrue(
            all(
                query["dimensions"] == {"LoadBalancer": "app/example/123"}
                for query in body["queries"]
            )
        )

    def test_treats_an_empty_5xx_series_as_zero(self):
        start_ms = int(REPORTING_START.timestamp() * 1000)
        transport = FakeGrafanaPostTransport(
            {
                "results": {
                    "A": cloudwatch_frame("A", [start_ms], [100]),
                    "B": {"status": 200, "frames": []},
                    "C": cloudwatch_frame("C", [start_ms], [0.125]),
                }
            }
        )

        result = collect_cloudwatch_alb_metrics(
            "https://grafana.example",
            "cloudwatch",
            "eu-central-1",
            "app/example/123",
            REPORTING_START,
            REPORTING_END,
            "token",
            transport=transport,
        )

        self.assertEqual(result, (Decimal("100"), Decimal("0.125")))

    def test_rejects_missing_requests_latency_or_multiple_in_window_points(self):
        start_ms = int(REPORTING_START.timestamp() * 1000)
        payloads = [
            {
                "results": {
                    "A": {"status": 200, "frames": []},
                    "B": cloudwatch_frame("B", [], []),
                    "C": cloudwatch_frame("C", [start_ms], [0.2]),
                }
            },
            {
                "results": {
                    "A": cloudwatch_frame("A", [start_ms], [100]),
                    "B": cloudwatch_frame("B", [start_ms], [1]),
                    "C": {"status": 200, "frames": []},
                }
            },
            {
                "results": {
                    "A": cloudwatch_frame("A", [start_ms, start_ms + 60_000], [100, 50]),
                    "B": cloudwatch_frame("B", [start_ms], [1]),
                    "C": cloudwatch_frame("C", [start_ms], [0.2]),
                }
            },
            {
                "results": {
                    "A": cloudwatch_frame("A", [start_ms], [100]),
                    "B": cloudwatch_frame("B", ["invalid"], [1]),
                    "C": cloudwatch_frame("C", [start_ms], [0.2]),
                }
            },
        ]

        for payload in payloads:
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                collect_cloudwatch_alb_metrics(
                    "https://grafana.example",
                    "cloudwatch",
                    "eu-central-1",
                    "app/example/123",
                    REPORTING_START,
                    REPORTING_END,
                    "token",
                    transport=FakeGrafanaPostTransport(payload),
                )

    def test_rejects_zero_requests_and_error_count_above_requests(self):
        start_ms = int(REPORTING_START.timestamp() * 1000)
        for requests, errors in ((0, 0), (100, 101)):
            payload = {
                "results": {
                    "A": cloudwatch_frame("A", [start_ms], [requests]),
                    "B": cloudwatch_frame("B", [start_ms], [errors]),
                    "C": cloudwatch_frame("C", [start_ms], [0.2]),
                }
            }
            with self.subTest(requests=requests, errors=errors), self.assertRaises(ValueError):
                collect_cloudwatch_alb_metrics(
                    "https://grafana.example",
                    "cloudwatch",
                    "eu-central-1",
                    "app/example/123",
                    REPORTING_START,
                    REPORTING_END,
                    "token",
                    transport=FakeGrafanaPostTransport(payload),
                )


if __name__ == "__main__":
    unittest.main()
