import json
import sys
import threading
import traceback
import unittest
from http.client import IncompleteRead
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fakes import FakeResponse, ReadFailureResponse, ScriptedOpener, http_error
from http_client import AmbiguousWriteError, HttpResponseError, _default_opener, request_json


class HttpClientTests(unittest.TestCase):
    def test_get_retries_url_error_then_returns_json_with_bounded_timeout(self):
        response = FakeResponse({"data": [1]})
        opener = ScriptedOpener([URLError("offline"), response])
        pauses = []

        result = request_json(
            "GET", "https://cb.example/api/accounts", "very-secret-token",
            opener=opener, sleeper=pauses.append, timeout=7, max_attempts=3,
        )

        self.assertEqual(result, {"data": [1]})
        self.assertEqual(len(opener.requests), 2)
        self.assertEqual(opener.timeouts, [7, 7])
        self.assertEqual(pauses, [1])
        self.assertTrue(response.closed)
        self.assertEqual(
            opener.requests[0].get_header("Authorization"), "Bearer very-secret-token"
        )
        self.assertEqual(opener.requests[0].get_header("Accept"), "application/json")
        self.assertEqual(
            opener.requests[0].get_header("User-agent"), "account-kpi-export/1.0"
        )

    def test_get_retries_429_and_5xx_only(self):
        first_error = http_error(429)
        second_error = http_error(503)
        opener = ScriptedOpener([
            first_error, second_error, FakeResponse({"ok": True}),
        ])
        pauses = []

        self.assertEqual(
            request_json("GET", "https://cb.example/api/x", "secret", opener=opener,
                         sleeper=pauses.append, max_attempts=3),
            {"ok": True},
        )
        self.assertEqual(len(opener.requests), 3)
        self.assertEqual(pauses, [1, 2])
        self.assertTrue(first_error.fp.closed)
        self.assertTrue(second_error.fp.closed)

    def test_get_retries_timeout_raised_while_reading_response(self):
        opener = ScriptedOpener([
            ReadFailureResponse(TimeoutError("response read timed out")),
            FakeResponse({"ok": True}),
        ])
        pauses = []

        self.assertEqual(
            request_json("GET", "https://cb.example/api/x", "secret", opener=opener,
                         sleeper=pauses.append),
            {"ok": True},
        )
        self.assertEqual(len(opener.requests), 2)
        self.assertEqual(pauses, [1])

    def test_get_retries_incomplete_read_raised_while_reading_response(self):
        opener = ScriptedOpener([
            ReadFailureResponse(IncompleteRead(b"partial", 20)),
            FakeResponse({"ok": True}),
        ])
        pauses = []

        self.assertEqual(
            request_json("GET", "https://cb.example/api/x", "secret", opener=opener,
                         sleeper=pauses.append),
            {"ok": True},
        )
        self.assertEqual(len(opener.requests), 2)
        self.assertEqual(pauses, [1])

    def test_get_permanent_4xx_fails_without_retry_and_hides_token(self):
        opener = ScriptedOpener([http_error(401, {"detail": "nope"})])

        with self.assertRaises(HttpResponseError) as captured:
            request_json("GET", "https://cb.example/api/x", "very-secret-token", opener=opener)

        self.assertEqual(captured.exception.status, 401)
        self.assertEqual(len(opener.requests), 1)
        self.assertNotIn("very-secret-token", str(captured.exception))

    def test_post_is_attempted_once_for_network_failure_and_is_ambiguous(self):
        opener = ScriptedOpener([URLError("lost response")])

        with self.assertRaises(AmbiguousWriteError) as captured:
            request_json(
                "POST", "https://cb.example/api/metric-datas", "very-secret-token",
                body={"data": {"value": 1.2}}, opener=opener, max_attempts=3,
            )

        self.assertEqual(len(opener.requests), 1)
        self.assertNotIn("very-secret-token", str(captured.exception))
        self.assertEqual(
            json.loads(opener.requests[0].data.decode("utf-8")), {"data": {"value": 1.2}}
        )
        self.assertEqual(opener.requests[0].get_header("Content-type"), "application/json")

    def test_post_429_and_5xx_are_ambiguous_without_retries(self):
        for status in (429, 500):
            with self.subTest(status=status):
                opener = ScriptedOpener([http_error(status)])
                with self.assertRaises(AmbiguousWriteError):
                    request_json("POST", "https://cb.example/api/x", "secret", opener=opener)
                self.assertEqual(len(opener.requests), 1)

    def test_idempotent_post_retries_transient_failures_like_a_read(self):
        opener = ScriptedOpener(
            [URLError("offline"), http_error(503), FakeResponse({"results": {}})]
        )
        pauses = []

        result = request_json(
            "POST",
            "https://grafana.example/api/ds/query",
            "secret",
            body={"queries": []},
            idempotent=True,
            opener=opener,
            sleeper=pauses.append,
            max_attempts=3,
        )

        self.assertEqual(result, {"results": {}})
        self.assertEqual(len(opener.requests), 3)
        self.assertEqual(pauses, [1, 2])

    def test_idempotent_post_exhaustion_is_not_reported_as_an_ambiguous_write(self):
        opener = ScriptedOpener([http_error(503)])

        with self.assertRaises(HttpResponseError) as captured:
            request_json(
                "POST",
                "https://grafana.example/api/ds/query",
                "secret",
                body={"queries": []},
                idempotent=True,
                opener=opener,
                max_attempts=1,
            )

        self.assertEqual(captured.exception.status, 503)

    def test_post_permanent_4xx_fails_immediately(self):
        opener = ScriptedOpener([http_error(422)])
        with self.assertRaises(HttpResponseError) as captured:
            request_json("POST", "https://cb.example/api/x", "secret", body={"data": {}}, opener=opener)
        self.assertEqual(captured.exception.status, 422)
        self.assertEqual(len(opener.requests), 1)

    def test_default_opener_does_not_follow_cross_origin_post_redirects(self):
        target_requests = []
        origin_requests = []

        class TargetHandler(BaseHTTPRequestHandler):
            def _record(self):
                target_requests.append({
                    "method": self.command,
                    "authorization": self.headers.get("Authorization"),
                })
                self.send_response(200)
                self.end_headers()

            do_GET = _record
            do_POST = _record

            def log_message(self, format_string, *args):
                pass

        target = ThreadingHTTPServer(("127.0.0.1", 0), TargetHandler)
        target_thread = threading.Thread(target=target.serve_forever)
        target_thread.start()

        class RedirectHandler(BaseHTTPRequestHandler):
            def do_POST(self):
                origin_requests.append(self.command)
                self.send_response(302)
                self.send_header(
                    "Location", "http://127.0.0.1:{0}/target".format(target.server_port)
                )
                self.end_headers()

            def log_message(self, format_string, *args):
                pass

        origin = ThreadingHTTPServer(("127.0.0.1", 0), RedirectHandler)
        origin_thread = threading.Thread(target=origin.serve_forever)
        origin_thread.start()
        try:
            request = Request(
                "http://127.0.0.1:{0}/origin".format(origin.server_port),
                data=b'{"data":{"value":1}}', headers={"Authorization": "Bearer redirect-secret"},
                method="POST",
            )
            with self.assertRaises(HTTPError) as captured:
                _default_opener(request, timeout=15)
        finally:
            origin.shutdown()
            origin.server_close()
            origin_thread.join()
            target.shutdown()
            target.server_close()
            target_thread.join()

        self.assertEqual(captured.exception.code, 302)
        captured.exception.close()
        self.assertEqual(origin_requests, ["POST"])
        self.assertEqual(target_requests, [])

    def test_network_and_http_error_tracebacks_do_not_include_original_token_context(self):
        token = "very-secret-token"
        cases = [
            ScriptedOpener([URLError("network failure: " + token)]),
            ScriptedOpener([http_error(401, url="https://cb.example/?token=" + token)]),
        ]
        for opener in cases:
            with self.subTest(opener=opener):
                try:
                    request_json("GET", "https://cb.example/api/x", token, opener=opener,
                                 max_attempts=1)
                except HttpResponseError:
                    self.assertNotIn(token, traceback.format_exc())
                else:
                    self.fail("request did not fail")

    def test_unsafe_bearer_token_is_rejected_without_appearing_in_traceback(self):
        token = "unsafe\r\nInjected-Header: value"
        opener = ScriptedOpener([])
        try:
            request_json("GET", "https://cb.example/api/x", token, opener=opener)
        except ValueError:
            self.assertNotIn(token, traceback.format_exc())
        else:
            self.fail("unsafe token did not fail")
        self.assertEqual(opener.requests, [])

    def test_rejects_non_https_userinfo_and_hostless_urls_before_opening(self):
        for url in (
            "http://cloudbrowser.example/api/accounts",
            "https://token@cloudbrowser.example/api/accounts",
            "https:///api/accounts",
        ):
            with self.subTest(url=url):
                opener = ScriptedOpener([])
                with self.assertRaises(ValueError):
                    request_json("GET", url, "secret", opener=opener)
                self.assertEqual(opener.requests, [])


if __name__ == "__main__":
    unittest.main()
