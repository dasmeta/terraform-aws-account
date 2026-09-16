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


def _cloudwatch_value(payload, ref_id, start_milliseconds, end_milliseconds, empty_value=None):
    if not isinstance(payload, dict) or not isinstance(payload.get("results"), dict):
        raise ValueError("Grafana CloudWatch response is malformed")
    result = payload["results"].get(ref_id)
    if not isinstance(result, dict) or result.get("status") != 200:
        raise ValueError("Grafana CloudWatch query was unsuccessful")
    frames = result.get("frames")
    if not isinstance(frames, list):
        raise ValueError("Grafana CloudWatch response is malformed")
    if not frames and empty_value is not None:
        return empty_value
    if len(frames) != 1:
        raise ValueError("Grafana CloudWatch query must return exactly one series")
    data = frames[0].get("data") if isinstance(frames[0], dict) else None
    values = data.get("values") if isinstance(data, dict) else None
    if (
        not isinstance(values, list)
        or len(values) != 2
        or not isinstance(values[0], list)
        or not isinstance(values[1], list)
        or len(values[0]) != len(values[1])
    ):
        raise ValueError("Grafana CloudWatch response is malformed")
    if any(
        not isinstance(timestamp, (int, float)) or isinstance(timestamp, bool)
        for timestamp in values[0]
    ):
        raise ValueError("Grafana CloudWatch response is malformed")
    in_window = [
        raw_value
        for timestamp, raw_value in zip(values[0], values[1])
        if start_milliseconds <= timestamp < end_milliseconds
    ]
    if not in_window and empty_value is not None:
        return empty_value
    if len(in_window) != 1:
        raise ValueError("Grafana CloudWatch query must return one in-window value")
    return _finite_decimal(in_window[0])


def collect_cloudwatch_alb_metrics(
    grafana_url,
    datasource_uid,
    region,
    load_balancer,
    start_utc,
    end_utc,
    token,
    transport=None,
):
    """Collect prior-window ALB availability and average latency through Grafana."""

    grafana_url = validate_base_url(grafana_url, "Grafana")
    for name, value in (
        ("datasource UID", datasource_uid),
        ("region", region),
        ("load balancer", load_balancer),
    ):
        if not isinstance(value, str) or not value.strip():
            raise ValueError("Grafana CloudWatch {0} must be non-empty".format(name))

    start_seconds = _boundary_seconds(start_utc)
    end_seconds = _boundary_seconds(end_utc)
    window_seconds = end_seconds - start_seconds
    if window_seconds <= 0:
        raise ValueError("Grafana query boundaries must form a positive interval")
    start_milliseconds = start_seconds * 1000
    end_milliseconds = end_seconds * 1000
    common = {
        "datasource": {"type": "cloudwatch", "uid": datasource_uid},
        "region": region,
        "namespace": "AWS/ApplicationELB",
        "dimensions": {"LoadBalancer": load_balancer},
        "period": str(window_seconds),
        "queryMode": "Metrics",
        "metricQueryType": 0,
        "matchExact": True,
    }
    queries = [
        dict(common, refId="A", metricName="RequestCount", statistic="Sum"),
        dict(
            common,
            refId="B",
            metricName="HTTPCode_Target_5XX_Count",
            statistic="Sum",
        ),
        dict(
            common,
            refId="C",
            metricName="TargetResponseTime",
            statistic="Average",
        ),
    ]
    if transport is None:
        transport = request_json
    payload = transport(
        "POST",
        "{0}/api/ds/query".format(grafana_url),
        token,
        body={
            "from": str(start_milliseconds),
            "to": str(end_milliseconds),
            "queries": queries,
        },
        idempotent=True,
    )
    request_count = _cloudwatch_value(
        payload, "A", start_milliseconds, end_milliseconds
    )
    error_count = _cloudwatch_value(
        payload,
        "B",
        start_milliseconds,
        end_milliseconds,
        empty_value=Decimal("0"),
    )
    latency = _cloudwatch_value(
        payload, "C", start_milliseconds, end_milliseconds
    )
    if request_count <= 0:
        raise ValueError("Grafana ALB request count must be positive")
    if error_count < 0 or error_count > request_count:
        raise ValueError("Grafana ALB error count is invalid")
    if latency < 0:
        raise ValueError("Grafana latency must be non-negative")
    uptime = (Decimal("1") - error_count / request_count) * Decimal("100")
    return uptime, latency
