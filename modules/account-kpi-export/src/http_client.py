"""Bounded authenticated JSON HTTP requests for CloudBrowser."""

import json
import time
from http.client import HTTPException
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener


class HttpResponseError(RuntimeError):
    """A permanent HTTP response failure, without request credentials."""

    def __init__(self, status):
        self.status = status
        super().__init__("CloudBrowser request failed with HTTP status {0}".format(status))


class AmbiguousWriteError(RuntimeError):
    """A POST may have reached CloudBrowser but its result is unknown."""

    def __init__(self, status=None):
        self.status = status
        detail = "network error" if status is None else "HTTP status {0}".format(status)
        super().__init__("CloudBrowser write outcome is ambiguous ({0})".format(detail))


class _RejectRedirectHandler(HTTPRedirectHandler):
    """Surface every redirect as an HTTP error before credentials can move hosts."""

    def http_error_302(self, request, response, code, message, headers):
        raise HTTPError(request.full_url, code, message, headers, response)

    http_error_301 = http_error_303 = http_error_307 = http_error_308 = http_error_302


_default_opener = build_opener(_RejectRedirectHandler()).open
_USER_AGENT = "account-kpi-export/1.0"


def _is_transient_status(status):
    return status == 429 or 500 <= status <= 599


def _response_payload(response):
    raw = response.read()
    if not raw:
        return None
    return json.loads(raw.decode("utf-8"))


def _validate_token(token):
    if not isinstance(token, str) or not token or any(
        ord(character) < 33 or ord(character) > 126 for character in token
    ):
        raise ValueError("CloudBrowser token contains unsafe characters") from None


def _validate_authenticated_url(url):
    if not isinstance(url, str):
        raise ValueError("authenticated URL must be a string") from None
    try:
        parsed = urlsplit(url)
    except ValueError:
        raise ValueError("authenticated URL is invalid") from None
    if (
        parsed.scheme.lower() != "https"
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
    ):
        raise ValueError("authenticated URL must use HTTPS without userinfo") from None
    return parsed


def validate_base_url(url, service_name):
    """Return a safe service base URL without query or fragment components."""

    _validate_authenticated_url(url)
    if "?" in url or "#" in url:
        raise ValueError("{0} base URL cannot include query or fragment".format(service_name)) from None
    return url.rstrip("/")


def request_json(
    method, url, token, body=None, timeout=15, max_attempts=3,
    opener=None, sleeper=time.sleep, idempotent=False,
):
    """Send JSON, retrying transient reads and explicitly idempotent queries."""

    method = method.upper()
    if method not in ("GET", "POST"):
        raise ValueError("only GET and POST requests are supported")
    if timeout <= 0 or max_attempts < 1:
        raise ValueError("timeout and max_attempts must be positive")
    if not isinstance(idempotent, bool):
        raise ValueError("idempotent must be a boolean")
    _validate_token(token)
    _validate_authenticated_url(url)
    if opener is None:
        opener = _default_opener

    encoded_body = None
    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/json",
        "User-Agent": _USER_AGENT,
    }
    if body is not None:
        encoded_body = json.dumps(body, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"

    for attempt in range(max_attempts):
        request = Request(url, data=encoded_body, headers=headers, method=method)
        try:
            with opener(request, timeout=timeout) as response:
                return _response_payload(response)
        except HTTPError as error:
            if method == "POST" and not idempotent and _is_transient_status(error.code):
                raise AmbiguousWriteError(error.code) from None
            if (method == "GET" or idempotent) and _is_transient_status(error.code) and attempt + 1 < max_attempts:
                sleeper(2 ** attempt)
                continue
            raise HttpResponseError(error.code) from None
        except (URLError, TimeoutError, OSError, HTTPException):
            if method == "POST" and not idempotent:
                raise AmbiguousWriteError() from None
            if attempt + 1 < max_attempts:
                sleeper(2 ** attempt)
                continue
            raise HttpResponseError("network") from None

    raise AssertionError("request retry loop ended unexpectedly")
