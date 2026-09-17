import unittest
from datetime import datetime, timezone
from pathlib import Path
import sys


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from reporting_period import previous_week


class ReportingPeriodTests(unittest.TestCase):
    def test_previous_week_uses_prior_local_monday_and_wednesday_record_date(self):
        window = previous_week(
            datetime(2026, 9, 15, 8, tzinfo=timezone.utc), "Asia/Yerevan"
        )

        self.assertEqual(window.start_date.isoformat(), "2026-09-07")
        self.assertEqual(window.end_date.isoformat(), "2026-09-14")
        self.assertEqual(window.record_date, "2026-09-09T00:00:00.000Z")

    def test_previous_week_crosses_new_year_by_local_dates(self):
        window = previous_week(
            datetime(2026, 1, 1, 12, tzinfo=timezone.utc), "UTC"
        )

        self.assertEqual(window.start_date.isoformat(), "2025-12-22")
        self.assertEqual(window.end_date.isoformat(), "2025-12-29")
        self.assertEqual(window.record_date, "2025-12-24T00:00:00.000Z")

    def test_previous_week_converts_each_boundary_with_berlin_dst_offset(self):
        window = previous_week(
            datetime(2026, 3, 31, 12, tzinfo=timezone.utc), "Europe/Berlin"
        )

        self.assertEqual(window.start_date.isoformat(), "2026-03-23")
        self.assertEqual(window.end_date.isoformat(), "2026-03-30")
        self.assertEqual(
            window.start_utc.isoformat(), "2026-03-22T23:00:00+00:00"
        )
        self.assertEqual(window.end_utc.isoformat(), "2026-03-29T22:00:00+00:00")
        self.assertEqual(window.record_date, "2026-03-25T00:00:00.000Z")

    def test_record_date_is_the_same_utc_wednesday_across_berlin_dst(self):
        cases = (
            (datetime(2026, 7, 14, 12, tzinfo=timezone.utc), "2026-07-08T00:00:00.000Z"),
            (datetime(2026, 1, 13, 12, tzinfo=timezone.utc), "2026-01-07T00:00:00.000Z"),
        )
        for now, expected in cases:
            with self.subTest(now=now):
                self.assertEqual(previous_week(now, "Europe/Berlin").record_date, expected)

    def test_previous_week_requires_an_aware_invocation_datetime(self):
        with self.assertRaises(ValueError):
            previous_week(datetime(2026, 9, 15, 8), "UTC")


if __name__ == "__main__":
    unittest.main()
