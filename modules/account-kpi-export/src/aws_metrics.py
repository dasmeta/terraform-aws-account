"""Cost Explorer and account-scoped Security Hub measurements."""

from decimal import Decimal, InvalidOperation
from datetime import date, timedelta


_COST_UNIT = "USD"
_COST_SCOPES = {"account", "organization"}
_SECURITY_STATUSES = {
    "FAILED": ("Failed", 3),
    "WARNING": ("Unknown", 2),
    "NOT_AVAILABLE": ("Unknown", 2),
    "PASSED": ("Passed", 1),
}


def _cost_request(account_id, start_date, end_date, scope):
    if scope not in _COST_SCOPES:
        raise ValueError("Unsupported Cost Explorer scope: {0}".format(scope))

    request = {
        "TimePeriod": {"Start": start_date.isoformat(), "End": end_date.isoformat()},
        "Granularity": "DAILY",
        "Metrics": ["UnblendedCost"],
    }
    if scope == "account":
        request["Filter"] = {
            "Dimensions": {"Key": "LINKED_ACCOUNT", "Values": [account_id]}
        }
    return request


def _cost_bucket_period(result):
    time_period = result.get("TimePeriod")
    if not isinstance(time_period, dict):
        raise ValueError("Cost Explorer returned a missing TimePeriod")
    try:
        bucket_start = date.fromisoformat(time_period.get("Start"))
        bucket_end = date.fromisoformat(time_period.get("End"))
    except (TypeError, ValueError):
        raise ValueError("Cost Explorer returned a malformed TimePeriod")
    if bucket_end != bucket_start + timedelta(days=1):
        raise ValueError("Cost Explorer returned a non-daily TimePeriod")
    return bucket_start, bucket_end


def _expected_cost_days(start_date, end_date):
    if end_date <= start_date:
        raise ValueError("Cost Explorer reporting interval must be non-empty")
    expected = set()
    current = start_date
    while current < end_date:
        expected.add(current)
        current += timedelta(days=1)
    return expected


def collect_cost(cost_explorer, account_id, start_date, end_date, scope="account"):
    """Return prior-week account or organization-wide unblended cost."""

    request = _cost_request(account_id, start_date, end_date, scope)
    total = Decimal("0")
    unit = None
    saw_amount = False
    expected_days = _expected_cost_days(start_date, end_date)
    seen_days = set()

    while True:
        response = cost_explorer.get_cost_and_usage(**request)
        results = response.get("ResultsByTime")
        if not isinstance(results, list):
            raise ValueError("Cost Explorer returned malformed ResultsByTime")
        for result in results:
            if not isinstance(result, dict):
                raise ValueError("Cost Explorer returned a malformed daily bucket")
            bucket_start, bucket_end = _cost_bucket_period(result)
            if bucket_start < start_date or bucket_end > end_date:
                raise ValueError("Cost Explorer returned a TimePeriod outside the reporting interval")
            if bucket_start in seen_days:
                raise ValueError("Cost Explorer returned a duplicate daily TimePeriod")
            seen_days.add(bucket_start)

            amount_data = result.get("Total", {}).get("UnblendedCost", {})
            amount = amount_data.get("Amount")
            result_unit = amount_data.get("Unit")
            if amount is None or result_unit is None:
                raise ValueError("Cost Explorer returned an incomplete UnblendedCost total")
            if result_unit != _COST_UNIT:
                raise ValueError("Unsupported Cost Explorer unit: {0}".format(result_unit))
            if unit is not None and result_unit != unit:
                raise ValueError("Cost Explorer returned inconsistent cost units")
            try:
                decimal_amount = Decimal(str(amount))
            except (InvalidOperation, ValueError):
                raise ValueError("Cost Explorer returned an invalid UnblendedCost amount")
            if not decimal_amount.is_finite():
                raise ValueError("Cost Explorer returned a non-finite UnblendedCost")
            total += decimal_amount
            unit = result_unit
            saw_amount = True

        next_token = response.get("NextPageToken")
        if not next_token:
            break
        request["NextPageToken"] = next_token

    if not saw_amount:
        raise ValueError("Cost Explorer returned no UnblendedCost totals")
    if seen_days != expected_days:
        raise ValueError("Cost Explorer did not return every daily TimePeriod")
    return total


def _security_filters(account_id):
    return {
        "AwsAccountId": [{"Value": account_id, "Comparison": "EQUALS"}],
        "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}],
        "WorkflowStatus": [{"Value": "SUPPRESSED", "Comparison": "NOT_EQUALS"}],
        "ProductName": [
            {"Value": "Security Hub", "Comparison": "EQUALS"},
            {"Value": "Security Hub CSPM", "Comparison": "EQUALS"},
        ],
    }


def _has_ready_standard(securityhub):
    request = {}
    enabled = False
    while True:
        response = securityhub.get_enabled_standards(**request)
        if any(
            subscription.get("StandardsStatus") == "READY"
            for subscription in response.get("StandardsSubscriptions", [])
            if isinstance(subscription, dict)
        ):
            enabled = True
        next_token = response.get("NextToken")
        if not next_token:
            return enabled
        request["NextToken"] = next_token


def _control_id(finding):
    compliance = finding.get("Compliance") or {}
    control_id = compliance.get("SecurityControlId")
    if isinstance(control_id, str) and control_id.strip():
        return control_id
    return None


def _finding_status(finding):
    compliance = finding.get("Compliance") or {}
    raw_status = compliance.get("Status")
    if raw_status is None:
        return None
    try:
        return _SECURITY_STATUSES[raw_status]
    except KeyError:
        raise ValueError("Unexpected Security Hub compliance status: {0}".format(raw_status))


def _reduce_control_status(controls, control_id, status):
    """Keep the highest-precedence status for a Security Hub control."""

    previous = controls.get(control_id)
    if previous is None or status[1] > previous[1]:
        controls[control_id] = status


def collect_security_score(securityhub, account_id):
    """Return a Security Hub score from unique active, non-suppressed controls."""

    if not _has_ready_standard(securityhub):
        raise ValueError("Security Hub has no READY standard")

    request = {"Filters": _security_filters(account_id)}
    controls = {}
    while True:
        response = securityhub.get_findings(**request)
        for finding in response.get("Findings", []):
            control_id = _control_id(finding)
            if control_id is None:
                continue
            status = _finding_status(finding)
            if status is None:
                continue
            _reduce_control_status(controls, control_id, status)

        next_token = response.get("NextToken")
        if not next_token:
            break
        request["NextToken"] = next_token

    if not controls:
        raise ValueError("Security Hub returned no scoreable controls")

    passed = sum(1 for status, _ in controls.values() if status == "Passed")
    return Decimal(passed) / Decimal(len(controls)) * Decimal("100")
