"""CloudBrowser account lookup and immutable metric-data writes."""

from decimal import Decimal, InvalidOperation
from urllib.parse import urlencode

from http_client import (
    AmbiguousWriteError, request_json as default_request_json, validate_base_url,
)


class AccountResolutionError(RuntimeError):
    """CloudBrowser did not return exactly one valid account identity."""


class MetricConflictError(RuntimeError):
    """A metric natural key already holds a different or duplicate value."""


def _items(payload):
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), list):
        raise ValueError("CloudBrowser response has no data list")
    return payload["data"]


def _entity_fields(entity):
    if not isinstance(entity, dict):
        raise ValueError("CloudBrowser entity is invalid")
    fields = entity.get("attributes", entity)
    if not isinstance(fields, dict):
        raise ValueError("CloudBrowser entity attributes are invalid")
    return fields


def _relation_id(value):
    if not isinstance(value, dict):
        return None
    relation = value.get("data", value)
    if not isinstance(relation, dict):
        return None
    return relation.get("id")


def _decimal(value):
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError):
        raise MetricConflictError("CloudBrowser metric value is not numeric")


class CloudBrowserClient:
    """Operations that preserve CloudBrowser's immutable weekly metric evidence."""

    def __init__(self, base_url, token, client_id, aws_provider_id, request_json=None):
        self.base_url = validate_base_url(base_url, "CloudBrowser")
        self.token = token
        self.client_id = client_id
        self.aws_provider_id = aws_provider_id
        self._request_json = request_json or default_request_json

    def _request(self, method, path, query=None, body=None):
        url = self.base_url + path
        if query:
            url += "?" + urlencode(query)
        return self._request_json(method, url, self.token, body=body)

    def resolve_account(self, runtime_account_id):
        response = self._request("GET", "/api/accounts", {
            "filters[accountId][$eq]": runtime_account_id,
            "filters[client][id][$eq]": self.client_id,
            "filters[provider][id][$eq]": self.aws_provider_id,
            "populate[0]": "provider",
            "populate[1]": "client",
            "pagination[pageSize]": 2,
        })
        accounts = _items(response)
        if len(accounts) != 1:
            raise AccountResolutionError("expected exactly one CloudBrowser account")
        account = accounts[0]
        fields = _entity_fields(account)
        if (
            str(fields.get("accountId")) != str(runtime_account_id)
            or _relation_id(fields.get("client")) != self.client_id
            or _relation_id(fields.get("provider")) != self.aws_provider_id
            or account.get("id") is None
        ):
            raise AccountResolutionError("CloudBrowser account identity did not match")
        return account["id"]

    def _find_metrics(self, metric_id, account_id, record_date):
        return _items(self._request("GET", "/api/metric-datas", {
            "filters[metric][id][$eq]": metric_id,
            "filters[client][id][$eq]": self.client_id,
            "filters[account][id][$eq]": account_id,
            "filters[date][$eq]": record_date,
            "pagination[pageSize]": 2,
        }))

    def _write_state(self, rows, submitted_value):
        if len(rows) > 1:
            raise MetricConflictError("multiple CloudBrowser metric rows match the natural key")
        if not rows:
            return "missing"
        value = _entity_fields(rows[0]).get("value")
        if _decimal(value) == _decimal(submitted_value):
            return "equal"
        raise MetricConflictError("CloudBrowser metric value conflicts with submitted value")

    def write_metric(self, metric_id, account_id, rounded_value, record_date):
        """Create only missing metric rows and reconcile an uncertain single POST."""

        if self._write_state(
            self._find_metrics(metric_id, account_id, record_date), rounded_value
        ) == "equal":
            return "skipped_duplicate"

        body = {"data": {
            "metric": metric_id,
            "client": self.client_id,
            "account": account_id,
            "value": rounded_value,
            "date": record_date,
        }}
        try:
            self._request("POST", "/api/metric-datas", body=body)
            return "created"
        except AmbiguousWriteError as error:
            state = self._write_state(
                self._find_metrics(metric_id, account_id, record_date), rounded_value
            )
            if state == "equal":
                return "reconciled_created"
            raise error
