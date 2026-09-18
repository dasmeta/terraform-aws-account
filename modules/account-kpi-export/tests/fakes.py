"""Small stdlib fakes shared by account KPI export HTTP tests."""

import io
import json
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlparse


class FakeResponse:
    def __init__(self, payload, status=200):
        self.payload = payload
        self.status = status
        self.closed = False

    def read(self):
        return json.dumps(self.payload).encode("utf-8")

    def getcode(self):
        return self.status

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()
        return False

    def close(self):
        self.closed = True


class ReadFailureResponse(FakeResponse):
    def __init__(self, error):
        super().__init__({})
        self.error = error

    def read(self):
        raise self.error


def http_error(status, payload=None, url="https://example.invalid/api"):
    return HTTPError(
        url, status, "server reply", {},
        io.BytesIO(json.dumps(payload or {"error": "reply"}).encode("utf-8")),
    )


class ScriptedOpener:
    def __init__(self, outcomes):
        self.outcomes = list(outcomes)
        self.requests = []
        self.timeouts = []

    def __call__(self, request, timeout):
        self.requests.append(request)
        self.timeouts.append(timeout)
        outcome = self.outcomes.pop(0)
        if isinstance(outcome, Exception):
            try:
                raise outcome
            finally:
                if isinstance(outcome, HTTPError):
                    outcome.close()
        return outcome


class FakeCloudBrowserTransport:
    def __init__(self):
        self.calls = []
        self.account_responses = []
        self.metric_responses = []
        self.post_outcomes = []

    def __call__(self, method, url, token, body=None, **kwargs):
        self.calls.append({"method": method, "url": url, "token": token, "body": body})
        if method == "GET" and url.split("?", 1)[0].endswith("/api/accounts"):
            return self.account_responses.pop(0)
        if method == "GET" and url.split("?", 1)[0].endswith("/api/metric-datas"):
            return self.metric_responses.pop(0)
        if method == "POST" and url.endswith("/api/metric-datas"):
            outcome = self.post_outcomes.pop(0)
            if isinstance(outcome, Exception):
                raise outcome
            return outcome
        raise AssertionError("unexpected request: {0} {1}".format(method, url))

    def query_for(self, call):
        parsed = parse_qs(urlparse(call["url"]).query)
        result = {}
        for key, values in parsed.items():
            value = values[0]
            if key.endswith("[id][$eq]"):
                value = int(value)
            result[key] = value
        return result


def strapi_account(identifier=101, account_id="111122223333", client_id=42, provider_id=9):
    return {
        "id": identifier,
        "attributes": {
            "accountId": account_id,
            "client": {"data": {"id": client_id}},
            "provider": {"data": {"id": provider_id}},
        },
    }


def flat_account(identifier=101, account_id="111122223333", client_id=42, provider_id=9):
    return {
        "id": identifier,
        "accountId": account_id,
        "client": {"id": client_id},
        "provider": {"id": provider_id},
    }


def strapi_metric(value, identifier=201):
    return {"id": identifier, "attributes": {"value": value}}


def flat_metric(value, identifier=201):
    return {"id": identifier, "value": value}
