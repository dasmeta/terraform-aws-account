"""Reporting-window calculations for weekly account KPI collection."""

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo


@dataclass(frozen=True)
class ReportingWindow:
    """The previous local Monday-to-Monday reporting interval."""

    start_date: date
    end_date: date
    start_utc: datetime
    end_utc: datetime
    record_date: str


def _as_utc_iso_milliseconds(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat(timespec="milliseconds").replace(
        "+00:00", "Z"
    )


def previous_week(now: datetime, timezone_name: str) -> ReportingWindow:
    """Return the prior complete local Monday-through-Monday reporting window."""

    if now.tzinfo is None or now.utcoffset() is None:
        raise ValueError("now must be timezone-aware")

    local_zone = ZoneInfo(timezone_name)
    local_now = now.astimezone(local_zone)
    current_monday = local_now.date() - timedelta(days=local_now.weekday())
    start_date = current_monday - timedelta(days=7)
    end_date = current_monday
    record_local_date = start_date + timedelta(days=2)

    start_local = datetime.combine(start_date, time.min, tzinfo=local_zone)
    end_local = datetime.combine(end_date, time.min, tzinfo=local_zone)
    record_utc = datetime.combine(record_local_date, time.min, tzinfo=timezone.utc)

    return ReportingWindow(
        start_date=start_date,
        end_date=end_date,
        start_utc=start_local.astimezone(timezone.utc),
        end_utc=end_local.astimezone(timezone.utc),
        record_date=_as_utc_iso_milliseconds(record_utc),
    )
