"""Grafana Prometheus application measurements."""

from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from urllib.parse import quote, urlencode

from http_client import request_json, validate_base_url


START_SECONDS_PLACEHOLDER = "$__account_kpi_start_seconds"
END_SECONDS_PLACEHOLDER = "$__account_kpi_end_seconds"
WINDOW_PLACEHOLDER = "$__account_kpi_window"


def _boundary_seconds(value):
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() is None:
        raise ValueError("Grafana query boundaries must be timezone-aware")
    return int(value.astimezone(timezone.utc).timestamp())


def _substitute_query_boundaries(query, start_utc, end_utc):
    start_seconds = _boundary_seconds(start_utc)
    end_seconds = _boundary_seconds(end_utc)
    window_seconds = end_seconds - start_seconds
    if window_seconds <= 0:
        raise ValueError("Grafana query boundaries must form a positive interval")
    has_start = START_SECONDS_PLACEHOLDER in query
    has_end = END_SECONDS_PLACEHOLDER in query
    has_window = WINDOW_PLACEHOLDER in query
    if not has_window or not has_end:
        raise ValueError(
            "Grafana query must include account KPI window and end placeholders"
        )
    substituted = query.replace(WINDOW_PLACEHOLDER, "{0}s".format(window_seconds)).replace(
        END_SECONDS_PLACEHOLDER, str(end_seconds)
    )
    if has_start:
        substituted = substituted.replace(START_SECONDS_PLACEHOLDER, str(start_seconds))
    return substituted


def _query_url(grafana_url, datasource_uid, query, start_utc, end_utc):
    grafana_url = validate_base_url(grafana_url, "Grafana")
    if not isinstance(datasource_uid, str) or not datasource_uid:
        raise ValueError("Grafana datasource UID must be a non-empty string")
    if not isinstance(query, str) or not query:
        raise ValueError("Grafana query must be a non-empty string")
    query = _substitute_query_boundaries(query, start_utc, end_utc)

    epoch = int(end_utc.astimezone(timezone.utc).timestamp())
    encoded_uid = quote(datasource_uid, safe="")
    return "{0}/api/datasources/proxy/uid/{1}/api/v1/query?{2}".format(
        grafana_url,
        encoded_uid,
        urlencode({"query": query, "time": epoch}),
    )


def _finite_decimal(raw_value):
    if isinstance(raw_value, bool) or raw_value is None:
        raise ValueError("Grafana returned a non-numeric value")
    try:
        value = Decimal(str(raw_value))
    except (InvalidOperation, ValueError):
        raise ValueError("Grafana returned a non-numeric value") from None
    if not value.is_finite():
        raise ValueError("Grafana returned a non-finite value")
    return value


def _extract_value(payload):
    if not isinstance(payload, dict) or payload.get("status") != "success":
        raise ValueError("Grafana returned an unsuccessful response")

    data = payload.get("data")
    if not isinstance(data, dict):
        raise ValueError("Grafana returned malformed data")

    result_type = data.get("resultType")
    result = data.get("result")
    if result_type == "scalar":
        if not isinstance(result, list) or len(result) != 2:
            raise ValueError("Grafana scalar result must contain one value")
        raw_value = result[1]
    elif result_type == "vector":
        if not isinstance(result, list) or len(result) != 1:
            raise ValueError("Grafana vector result must contain exactly one series")
        series = result[0]
        if not isinstance(series, dict):
            raise ValueError("Grafana vector result is malformed")
        value = series.get("value")
        if not isinstance(value, list) or len(value) != 2:
            raise ValueError("Grafana vector series must contain one value")
        raw_value = value[1]
    else:
        raise ValueError("Grafana returned an unsupported result type")

    return _finite_decimal(raw_value)


def query_grafana(
    grafana_url,
    datasource_uid,
    query,
    start_utc,
    end_utc,
    token,
    transport=None,
):
    """Run one instant Prometheus query through Grafana's datasource proxy."""

    if transport is None:
        transport = request_json
    payload = transport(
        "GET",
        _query_url(grafana_url, datasource_uid, query, start_utc, end_utc),
        token,
    )
    return _extract_value(payload)


def collect_application_metrics(
    grafana_url,
    datasource_uid,
    uptime_query,
    latency_query,
    start_utc,
    end_utc,
    token,
    transport=None,
):
    """Collect and validate uptime and latency as one application pair."""

    uptime = query_grafana(
        grafana_url,
        datasource_uid,
        uptime_query,
        start_utc,
        end_utc,
        token,
        transport=transport,
    )
    latency = query_grafana(
        grafana_url,
        datasource_uid,
        latency_query,
        start_utc,
        end_utc,
        token,
        transport=transport,
    )

    if uptime < Decimal("0") or uptime > Decimal("100"):
        raise ValueError("Grafana uptime must be between 0 and 100")
    if latency < Decimal("0"):
        raise ValueError("Grafana latency must be non-negative")
    return uptime, latency
