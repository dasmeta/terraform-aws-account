import sys
import unittest
from http.client import IncompleteRead
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from cloudbrowser import AccountResolutionError, CloudBrowserClient, MetricConflictError
from http_client import AmbiguousWriteError, request_json
from fakes import (
    FakeCloudBrowserTransport, FakeResponse, ReadFailureResponse, ScriptedOpener,
    flat_account, flat_metric, strapi_account, strapi_metric,
)


RECORD_DATE = "2026-09-09T00:00:00.000Z"


class CloudBrowserTests(unittest.TestCase):
    def setUp(self):
        self.transport = FakeCloudBrowserTransport()
        self.client = CloudBrowserClient(
            "https://cb.example/", "secret", client_id=42, aws_provider_id=9,
            request_json=self.transport,
        )

    def test_resolve_account_accepts_valid_strapi_v4_entity_and_exact_query(self):
        self.transport.account_responses = [{"data": [strapi_account()]}]

        self.assertEqual(self.client.resolve_account("111122223333"), 101)

        query = self.transport.query_for(self.transport.calls[0])
        self.assertEqual(query["filters[accountId][$eq]"], "111122223333")
        self.assertEqual(query["filters[client][id][$eq]"], 42)
        self.assertEqual(query["filters[provider][id][$eq]"], 9)
        self.assertEqual(query["populate[0]"], "provider")
        self.assertEqual(query["populate[1]"], "client")
        self.assertEqual(query["pagination[pageSize]"], "2")

    def test_resolve_account_accepts_valid_flat_entity(self):
        self.transport.account_responses = [{"data": [flat_account()]}]
        self.assertEqual(self.client.resolve_account("111122223333"), 101)

    def test_cloudbrowser_base_url_rejects_unsafe_components_before_transport(self):
        for base_url in (
            "http://cloudbrowser.example",
            "https://token@cloudbrowser.example",
            "https:///api",
            "https://cloudbrowser.example?source=unsafe",
            "https://cloudbrowser.example#unsafe",
        ):
            with self.subTest(base_url=base_url):
                calls = []
                with self.assertRaises(ValueError):
                    CloudBrowserClient(
                        base_url, "secret", client_id=42, aws_provider_id=9,
                        request_json=lambda *args, **kwargs: calls.append(args),
                    )
                self.assertEqual(calls, [])

    def test_cloudbrowser_base_url_accepts_https_host_path_and_port(self):
        transport = FakeCloudBrowserTransport()
        transport.account_responses = [{"data": [flat_account()]}]
        client = CloudBrowserClient(
            "https://cloudbrowser.example:8443/prefix/", "secret",
            client_id=42, aws_provider_id=9, request_json=transport,
        )

        self.assertEqual(client.resolve_account("111122223333"), 101)
        self.assertTrue(transport.calls[0]["url"].startswith(
            "https://cloudbrowser.example:8443/prefix/api/accounts?"
        ))

    def test_resolve_account_rejects_zero_multiple_or_mismatched_identities(self):
        cases = [
            {"data": []},
            {"data": [strapi_account(), strapi_account(identifier=102)]},
            {"data": [flat_account(account_id="999900001111")]},
            {"data": [flat_account(client_id=43)]},
            {"data": [flat_account(provider_id=10)]},
        ]
        for response in cases:
            with self.subTest(response=response):
                self.transport.account_responses = [response]
                with self.assertRaises(AccountResolutionError):
                    self.client.resolve_account("111122223333")

    def test_write_metric_creates_one_exact_row_when_natural_key_is_absent(self):
        self.transport.metric_responses = [{"data": []}]
        self.transport.post_outcomes = [{"data": {"id": 201}}]

        self.assertEqual(self.client.write_metric(12, 101, 123.4567, RECORD_DATE), "created")
        self.assertEqual([call["method"] for call in self.transport.calls], ["GET", "POST"])
        query = self.transport.query_for(self.transport.calls[0])
        self.assertEqual(query["filters[account][id][$eq]"], 101)
        self.assertEqual(query["filters[metric][id][$eq]"], 12)
        self.assertEqual(query["filters[client][id][$eq]"], 42)
        self.assertEqual(query["filters[date][$gte]"], RECORD_DATE)
        self.assertEqual(query["filters[date][$lt]"], "2026-09-10T00:00:00.000Z")
        self.assertNotIn("filters[date][$eq]", query)
        self.assertEqual(query["pagination[pageSize]"], "2")
        self.assertEqual(
            self.transport.calls[1]["body"],
            {"data": {"metric": 12, "client": 42, "account": 101,
                      "value": 123.4567, "date": RECORD_DATE}},
        )

    def test_three_logical_replays_create_exactly_one_row(self):
        existing = strapi_metric("123.4567")
        self.transport.metric_responses = [
            {"data": []},
            {"data": [existing]},
            {"data": [existing]},
        ]
        self.transport.post_outcomes = [{"data": existing}]

        outcomes = [
            self.client.write_metric(12, 101, 123.4567, RECORD_DATE)
            for _ in range(3)
        ]

        self.assertEqual(outcomes, ["created", "skipped_duplicate", "skipped_duplicate"])
        self.assertEqual(
            [call["method"] for call in self.transport.calls],
            ["GET", "POST", "GET", "GET"],
        )
        posts = [call for call in self.transport.calls if call["method"] == "POST"]
        self.assertEqual(len(posts), 1)
        self.assertEqual(posts[0]["body"]["data"]["value"], 123.4567)

    def test_write_metric_skips_only_exact_decimal_numeric_match(self):
        self.transport.metric_responses = [{"data": [strapi_metric("1.2300")]}]
        self.assertEqual(self.client.write_metric(12, 101, 1.23, RECORD_DATE), "skipped_duplicate")
        self.assertEqual([call["method"] for call in self.transport.calls], ["GET"])

    def test_write_metric_rejects_sub_millionth_numeric_change_without_overwrite(self):
        self.transport.metric_responses = [{"data": [flat_metric("1.2300001")]}]

        with self.assertRaises(MetricConflictError):
            self.client.write_metric(12, 101, 1.23, RECORD_DATE)

        self.assertEqual([call["method"] for call in self.transport.calls], ["GET"])

    def test_write_metric_rejects_multiple_existing_rows(self):
        self.transport.metric_responses = [
            {"data": [flat_metric("1.23"), flat_metric("1.23", identifier=202)]}
        ]

        with self.assertRaises(MetricConflictError):
            self.client.write_metric(12, 101, 1.23, RECORD_DATE)

        self.assertEqual([call["method"] for call in self.transport.calls], ["GET"])

    def test_lost_post_response_reconciles_equal_row_without_second_post(self):
        ambiguous = AmbiguousWriteError("POST outcome ambiguous")
        self.transport.metric_responses = [
            {"data": []}, {"data": [strapi_metric("123.4567")]},
        ]
        self.transport.post_outcomes = [ambiguous]

        self.assertEqual(
            self.client.write_metric(12, 101, 123.4567, RECORD_DATE), "reconciled_created"
        )
        self.assertEqual([call["method"] for call in self.transport.calls], ["GET", "POST", "GET"])

    def test_post_response_read_timeout_reconciles_without_a_second_post(self):
        opener = ScriptedOpener([
            FakeResponse({"data": []}),
            ReadFailureResponse(TimeoutError("response lost after commit")),
            FakeResponse({"data": [strapi_metric("123.4567")]}),
        ])

        def transport(method, url, token, body=None):
            return request_json(method, url, token, body=body, opener=opener,
                                sleeper=lambda seconds: None)

        client = CloudBrowserClient(
            "https://cb.example", "secret", client_id=42, aws_provider_id=9,
            request_json=transport,
        )

        self.assertEqual(client.write_metric(12, 101, 123.4567, RECORD_DATE), "reconciled_created")
        self.assertEqual(
            [request.get_method() for request in opener.requests], ["GET", "POST", "GET"]
        )

    def test_post_incomplete_read_reconciles_without_a_second_post(self):
        opener = ScriptedOpener([
            FakeResponse({"data": []}),
            ReadFailureResponse(IncompleteRead(b"partial", 20)),
            FakeResponse({"data": [strapi_metric("123.4567")]}),
        ])

        def transport(method, url, token, body=None):
            return request_json(method, url, token, body=body, opener=opener,
                                sleeper=lambda seconds: None)

        client = CloudBrowserClient(
            "https://cb.example", "secret", client_id=42, aws_provider_id=9,
            request_json=transport,
        )

        self.assertEqual(client.write_metric(12, 101, 123.4567, RECORD_DATE), "reconciled_created")
        self.assertEqual(
            [request.get_method() for request in opener.requests], ["GET", "POST", "GET"]
        )

    def test_ambiguous_post_reconciliation_rejects_unequal_or_multiple_rows(self):
        for response in (
            {"data": [flat_metric("123.4568")]},
            {"data": [flat_metric("123.4567"), flat_metric("123.4567", identifier=202)]},
        ):
            with self.subTest(response=response):
                self.transport.metric_responses = [{"data": []}, response]
                self.transport.post_outcomes = [AmbiguousWriteError("uncertain")]
                with self.assertRaises(MetricConflictError):
                    self.client.write_metric(12, 101, 123.4567, RECORD_DATE)
                self.assertEqual([call["method"] for call in self.transport.calls], ["GET", "POST", "GET"])
                self.transport.calls = []

    def test_ambiguous_post_with_no_row_reraises_original_error_and_never_reposts(self):
        ambiguous = AmbiguousWriteError("uncertain")
        self.transport.metric_responses = [{"data": []}, {"data": []}]
        self.transport.post_outcomes = [ambiguous]
        with self.assertRaises(AmbiguousWriteError) as captured:
            self.client.write_metric(12, 101, 123.4567, RECORD_DATE)
        self.assertIs(captured.exception, ambiguous)
        self.assertEqual([call["method"] for call in self.transport.calls], ["GET", "POST", "GET"])


if __name__ == "__main__":
    unittest.main()
