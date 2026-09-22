"""Behavioral tests for account-scoped AWS KPI collectors."""

from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
import sys
import unittest


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from aws_metrics import (
    _finding_status,
    _reduce_control_status,
    collect_cost,
    collect_security_score,
)


ACCOUNT_ID = "111122223333"


class FakeCostExplorer:
    def __init__(self, pages):
        self.pages = list(pages)
        self.calls = []

    def get_cost_and_usage(self, **kwargs):
        self.calls.append(kwargs)
        return self.pages.pop(0)


class FakeSecurityHub:
    def __init__(self, standard_pages, finding_pages):
        self.standard_pages = list(standard_pages)
        self.finding_pages = list(finding_pages)
        self.standard_calls = []
        self.finding_calls = []

    def get_enabled_standards(self, **kwargs):
        self.standard_calls.append(kwargs)
        return self.standard_pages.pop(0)

    def get_findings(self, **kwargs):
        self.finding_calls.append(kwargs)
        return self.finding_pages.pop(0)


def cost_bucket(start, amount, unit="USD", end=None):
    if end is None:
        end = start + timedelta(days=1)
    return {
        "TimePeriod": {"Start": start.isoformat(), "End": end.isoformat()},
        "Total": {"UnblendedCost": {"Amount": amount, "Unit": unit}},
    }


def cost_page(*buckets, next_token=None):
    page = {
        "ResultsByTime": list(buckets)
    }
    if next_token:
        page["NextPageToken"] = next_token
    return page


def finding(control_id=None, status="PASSED", generator_id=None):
    compliance = {}
    if control_id is not None:
        compliance["SecurityControlId"] = control_id
    if status is not None:
        compliance["Status"] = status
    result = {"Compliance": compliance}
    if generator_id is not None:
        result["GeneratorId"] = generator_id
    return result


class CollectCostTests(unittest.TestCase):
    start_date = date(2026, 9, 7)
    end_date = date(2026, 9, 14)

    def weekly_buckets(self, amounts=None):
        if amounts is None:
            amounts = ["0"] * 7
        return [
            cost_bucket(self.start_date + timedelta(days=index), amount)
            for index, amount in enumerate(amounts)
        ]

    def test_collect_cost_uses_daily_account_filter_and_sums_signed_buckets(self):
        buckets = self.weekly_buckets(
            ["10.00", "-3.25", "-2.75", "0", "1", "-1", "0"]
        )
        cost_explorer = FakeCostExplorer(
            [
                cost_page(*buckets[:3], next_token="page-2"),
                cost_page(*buckets[3:]),
            ]
        )

        result = collect_cost(
            cost_explorer,
            ACCOUNT_ID,
            self.start_date,
            self.end_date,
        )

        self.assertEqual(result, Decimal("4.00"))
        self.assertEqual(
            cost_explorer.calls,
            [
                {
                    "TimePeriod": {"Start": "2026-09-07", "End": "2026-09-14"},
                    "Granularity": "DAILY",
                    "Metrics": ["UnblendedCost"],
                    "Filter": {
                        "Dimensions": {
                            "Key": "LINKED_ACCOUNT",
                            "Values": [ACCOUNT_ID],
                        }
                    },
                },
                {
                    "TimePeriod": {"Start": "2026-09-07", "End": "2026-09-14"},
                    "Granularity": "DAILY",
                    "Metrics": ["UnblendedCost"],
                    "Filter": {
                        "Dimensions": {
                            "Key": "LINKED_ACCOUNT",
                            "Values": [ACCOUNT_ID],
                        }
                    },
                    "NextPageToken": "page-2",
                },
            ],
        )

    def test_collect_cost_organization_scope_omits_account_filter_and_sums_totals(self):
        cost_explorer = FakeCostExplorer(
            [cost_page(*self.weekly_buckets(["10", "20", "30", "40", "50", "60", "70"]))]
        )

        result = collect_cost(
            cost_explorer,
            ACCOUNT_ID,
            self.start_date,
            self.end_date,
            scope="organization",
        )

        self.assertEqual(result, Decimal("280"))
        self.assertEqual(
            cost_explorer.calls,
            [
                {
                    "TimePeriod": {"Start": "2026-09-07", "End": "2026-09-14"},
                    "Granularity": "DAILY",
                    "Metrics": ["UnblendedCost"],
                }
            ],
        )

    def test_collect_cost_rejects_unknown_scope_before_calling_aws(self):
        cost_explorer = FakeCostExplorer([])

        with self.assertRaisesRegex(ValueError, "scope"):
            collect_cost(
                cost_explorer,
                ACCOUNT_ID,
                self.start_date,
                self.end_date,
                scope="unknown",
            )

        self.assertEqual(cost_explorer.calls, [])

    def test_collect_cost_allows_negative_totals_and_zero(self):
        for amounts, expected in ((["-4.50"] + ["0"] * 6, "-4.50"), (["0"] * 7, "0")):
            with self.subTest(expected=expected):
                self.assertEqual(
                    collect_cost(
                        FakeCostExplorer([cost_page(*self.weekly_buckets(amounts))]),
                        ACCOUNT_ID,
                        self.start_date,
                        self.end_date,
                    ),
                    Decimal(expected),
                )

    def test_collect_cost_rejects_empty_missing_invalid_nonfinite_or_inconsistent_data(self):
        valid_buckets = self.weekly_buckets()
        cases = [
            [{"ResultsByTime": []}],
            [{"ResultsByTime": [{"Total": {}}]}],
            [cost_page(cost_bucket(self.start_date, "not-a-number"))],
            [cost_page(cost_bucket(self.start_date, "NaN"))],
            [cost_page(cost_bucket(self.start_date, "Infinity"))],
            [
                cost_page(*valid_buckets[:6], next_token="next"),
                cost_page(cost_bucket(self.end_date - timedelta(days=1), "2", unit="EUR")),
            ],
        ]

        for pages in cases:
            with self.subTest(pages=pages):
                with self.assertRaises(ValueError):
                    collect_cost(
                        FakeCostExplorer(pages),
                        ACCOUNT_ID,
                        self.start_date,
                        self.end_date,
                    )

    def test_collect_cost_requires_each_daily_bucket_once_across_pages(self):
        valid_buckets = self.weekly_buckets()
        malformed_bucket = {
            "TimePeriod": {"Start": "not-a-date", "End": "2026-09-08"},
            "Total": {"UnblendedCost": {"Amount": "0", "Unit": "USD"}},
        }
        cases = {
            "missing": [cost_page(*valid_buckets[:6], next_token="next"), cost_page()],
            "duplicate": [
                cost_page(*valid_buckets[:4], next_token="next"),
                cost_page(*valid_buckets[4:], valid_buckets[0]),
            ],
            "malformed": [cost_page(malformed_bucket)],
            "overlapping": [
                cost_page(
                    cost_bucket(
                        self.start_date,
                        "0",
                        end=self.start_date + timedelta(days=2),
                    ),
                    *valid_buckets[1:],
                )
            ],
            "out_of_range": [
                cost_page(
                    *valid_buckets,
                    cost_bucket(self.end_date, "0"),
                )
            ],
            "non_contiguous": [
                cost_page(
                    valid_buckets[0],
                    *valid_buckets[2:],
                )
            ],
        }

        for name, pages in cases.items():
            with self.subTest(name=name):
                with self.assertRaises(ValueError):
                    collect_cost(
                        FakeCostExplorer(pages),
                        ACCOUNT_ID,
                        self.start_date,
                        self.end_date,
                    )


class CollectSecurityScoreTests(unittest.TestCase):
    def test_collect_security_score_pages_filters_and_reduces_controls(self):
        securityhub = FakeSecurityHub(
            [
                {
                    "StandardsSubscriptions": [
                        {"StandardsStatus": "PENDING_REGISTRATION"}
                    ],
                    "NextToken": "standards-2",
                },
                {
                    "StandardsSubscriptions": [
                        {
                            "StandardsSubscriptionArn": "arn:aws:securityhub:us-east-1:111122223333:subscription/aws-foundational-security-best-practices/v/1.0.0",
                            "StandardsStatus": "READY",
                        }
                    ]
                },
            ],
            [
                {
                    "Findings": [
                        finding("iam.1", "PASSED"),
                        finding("s3.1", "WARNING"),
                        finding("ec2.1", "FAILED"),
                    ],
                    "NextToken": "findings-2",
                },
                {
                    "Findings": [
                        finding("iam.1", "FAILED"),
                        finding("s3.1", "NOT_AVAILABLE"),
                        finding("ec2.1", "PASSED"),
                        finding("rds.1", "PASSED"),
                    ]
                },
            ],
        )

        result = collect_security_score(securityhub, ACCOUNT_ID)

        self.assertEqual(result, Decimal("25"))
        self.assertEqual(securityhub.standard_calls, [{}, {"NextToken": "standards-2"}])
        expected_filters = {
            "AwsAccountId": [{"Value": ACCOUNT_ID, "Comparison": "EQUALS"}],
            "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}],
            "WorkflowStatus": [{"Value": "SUPPRESSED", "Comparison": "NOT_EQUALS"}],
            "ProductName": [
                {"Value": "Security Hub", "Comparison": "EQUALS"},
                {"Value": "Security Hub CSPM", "Comparison": "EQUALS"},
            ],
        }
        self.assertEqual(
            securityhub.finding_calls,
            [
                {"Filters": expected_filters},
                {"Filters": expected_filters, "NextToken": "findings-2"},
            ],
        )

    def test_collect_security_score_excludes_findings_without_canonical_control_id(self):
        securityhub = FakeSecurityHub(
            [{"StandardsSubscriptions": [{"StandardsStatus": "READY"}]}],
            [
                {
                    "Findings": [
                        finding(
                            status="PASSED",
                            generator_id="aws-foundational-security-best-practices/v/1.0.0/Config.1",
                        ),
                        finding("   ", "PASSED"),
                    ]
                }
            ],
        )

        with self.assertRaisesRegex(ValueError, "scoreable"):
            collect_security_score(securityhub, ACCOUNT_ID)

    def test_security_status_mapping_and_duplicate_precedence_are_explicit(self):
        passed = _finding_status(finding("control-1", "PASSED"))
        warning = _finding_status(finding("control-1", "WARNING"))
        not_available = _finding_status(finding("control-1", "NOT_AVAILABLE"))
        failed = _finding_status(finding("control-1", "FAILED"))

        self.assertEqual(passed, ("Passed", 1))
        self.assertEqual(warning, ("Unknown", 2))
        self.assertEqual(not_available, ("Unknown", 2))
        self.assertEqual(failed, ("Failed", 3))

        controls = {}
        _reduce_control_status(controls, "control-1", passed)
        _reduce_control_status(controls, "control-1", warning)
        _reduce_control_status(controls, "control-1", passed)
        self.assertEqual(controls["control-1"], ("Unknown", 2))

        _reduce_control_status(controls, "control-1", failed)
        _reduce_control_status(controls, "control-1", not_available)
        self.assertEqual(controls["control-1"], ("Failed", 3))

    def test_collect_security_score_rejects_invalid_raw_status(self):
        securityhub = FakeSecurityHub(
            [{"StandardsSubscriptions": [{"StandardsStatus": "READY"}]}],
            [{"Findings": [finding("control-1", "UNKNOWN")]}],
        )

        with self.assertRaisesRegex(ValueError, "UNKNOWN"):
            collect_security_score(securityhub, ACCOUNT_ID)

    def test_collect_security_score_requires_ready_standards_and_scoreable_data(self):
        no_standards = FakeSecurityHub([{"StandardsSubscriptions": []}], [])
        with self.assertRaisesRegex(ValueError, "READY standard"):
            collect_security_score(no_standards, ACCOUNT_ID)

        for status in (
            "PENDING",
            "PENDING_REGISTRATION",
            "INCOMPLETE",
            "DELETING",
            "FAILED",
        ):
            with self.subTest(status=status):
                securityhub = FakeSecurityHub(
                    [{"StandardsSubscriptions": [{"StandardsStatus": status}]}], []
                )
                with self.assertRaisesRegex(ValueError, "READY standard"):
                    collect_security_score(securityhub, ACCOUNT_ID)

        no_data = FakeSecurityHub(
            [{"StandardsSubscriptions": [{"StandardsStatus": "READY"}]}],
            [{"Findings": [finding(), finding("control-without-status", None)]}],
        )
        with self.assertRaisesRegex(ValueError, "scoreable"):
            collect_security_score(no_data, ACCOUNT_ID)


if __name__ == "__main__":
    unittest.main()
