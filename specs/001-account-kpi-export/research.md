# Research: Weekly Account KPI Export

## Existing Module Pattern

**Decision**: Add a new opt-in child module and leave `cost_report_export` unchanged.

**Rationale**: The repository already delegates scheduled exporters to child modules and consumes
checked-in Lambda packages in Terraform Cloud. Reusing the old cost interface would make Grafana,
Security Hub, authentication, and account relations appear to be cost-webhook settings and would
increase regression risk.

**Alternatives considered**: Expand the legacy child; run a central cross-account collector.

## Upstream Modules

**Decision**: Pin the same compatible upstream families already used by the repository: Lambda
7.21.1 and EventBridge 3.17.1, plus SQS 4.3.1 and CloudWatch metric-alarm 5.7.2.

**Rationale**: Lambda 7.21.1 supports `local_existing_package`; EventBridge 3.17.1 supports Scheduler
time zones, retry policies, and target DLQs. SQS 4.3.1 supports encrypted queues without raising the
root Terraform/provider bounds. The alarm submodule keeps failure monitoring consistent with nearby
DasMeta modules. EventBridge 3.17.1 already requires AWS provider 5.98, so the feature does not add a
new effective provider boundary.

**Alternatives considered**: Direct AWS resources; current major versions that require Terraform
1.5.7 and AWS provider 6.28; the fallback scratch template.

## Runtime and Packaging

**Decision**: Use the maintained `python3.13` Lambda runtime, standard-library HTTP/JSON/date support,
runtime-provided `boto3`, and a deterministic checked-in ZIP.

**Rationale**: AWS lists Python 3.13 on Amazon Linux 2023 with a June 30, 2029 deprecation date.
AWS provider 5.98 validates the Lambda runtime against its SDK enum and depends on Lambda SDK
1.71.2, whose runtime values include `python3.13` and exclude `python3.14`. Provider 6.21 added
Python 3.14 support, so choosing 3.13 preserves the approved effective provider minimum of 5.98.
Avoiding external packages keeps the artifact small and lets a Python 3.9 local interpreter execute
unit tests. A checked-in ZIP matches the
repository's Terraform Cloud convention; a builder with fixed timestamps makes source changes
reviewable and reproducible.

**Alternatives considered**: Python 3.14, which would raise the effective provider boundary to 6.21;
Node.js with bundled dependencies; build-at-plan-time archives; container images.

**Primary sources**:

- https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
- [AWS Python runtime lifecycle](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
- [AWS provider 5.98 SDK dependencies](https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/v5.98.0/go.mod)
- [AWS provider 5.98 Lambda runtime validator](https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/v5.98.0/internal/service/lambda/function.go)
- [Lambda SDK 1.71.2 runtime enum](https://raw.githubusercontent.com/aws/aws-sdk-go-v2/service/lambda/v1.71.2/service/lambda/types/enums.go)
- [AWS provider 6.21 runtime additions](https://github.com/hashicorp/terraform-provider-aws/releases/tag/v6.21.0)
- https://github.com/terraform-aws-modules/terraform-aws-lambda/tree/v7.21.1
- https://github.com/terraform-aws-modules/terraform-aws-eventbridge/tree/v3.17.1
- https://github.com/terraform-aws-modules/terraform-aws-sqs/tree/v4.3.1

## Reporting Period and Dates

**Decision**: Compute the prior local Monday and following Monday from invocation time and the IANA
time zone. Cost Explorer receives date strings with an exclusive end. Grafana receives the exact end
instant converted to UTC. All rows use prior-week Wednesday local midnight converted to UTC.

**Rationale**: This preserves full weeks across month, year, and daylight-saving boundaries and the
existing CloudBrowser report-date convention. Security Hub is a Wednesday execution-time snapshot
associated with that date; it is not described as a reconstructed Sunday value.

**Alternatives considered**: Rolling seven days; fixed UTC boundaries for all sources; current-week
record dates.

## Cost Isolation

**Decision**: Query `UnblendedCost` with `Granularity=DAILY`, inclusive start/exclusive end, and a
`LINKED_ACCOUNT` filter equal to the runtime AWS account ID. Sum every finite signed daily bucket from
every page using `Decimal`; negative credits and refunds are valid weekly-cost inputs.

**Rationale**: The filter prevents organization-wide totals in management accounts while preserving
one CloudBrowser row per deployed account. Cost Explorer does not support resource-scoped IAM for
this action, so IAM uses `Resource="*"` with only `ce:GetCostAndUsage`.

**Alternatives considered**: Organization totals; blended or amortized cost; central assume-role
collection.

**Primary sources**:

- https://docs.aws.amazon.com/aws-cost-management/latest/APIReference/API_GetCostAndUsage.html
- https://docs.aws.amazon.com/service-authorization/latest/reference/list_ce.html

## Security Hub Score

**Decision**: Confirm at least one `StandardsStatus=READY` subscription, then page through active,
non-suppressed Security Hub control findings filtered to the runtime AWS account. The ProductName filter
includes both exact historical `Security Hub` and current `Security Hub CSPM` values. Reduce findings
only by a nonempty canonical `Compliance.SecurityControlId` with Failed > Unknown > Passed precedence;
findings without that ID are No data and never use a `GeneratorId` fallback. Map `FAILED` to Failed,
`WARNING` and `NOT_AVAILABLE` to Unknown, and `PASSED` to Passed. `UNKNOWN` is not a valid raw
`Compliance.Status` value. The score is `passed / (passed + failed + unknown) * 100`.

**Rationale**: AWS documents the summary score as unique passed controls divided by unique enabled
controls whose statuses are Passed, Failed, or Unknown, while excluding No data. Filtering the account
at the API prevents administrator accounts from including member findings. Public APIs are used;
console-private score endpoints are excluded.

**Alternatives considered**: Trust the administrator summary; average per-standard scores; use
console-only APIs; omit `NOT_AVAILABLE` as No data.

**Primary sources**:

- https://docs.aws.amazon.com/securityhub/latest/userguide/standards-security-score.html
- https://docs.aws.amazon.com/securityhub/1.0/APIReference/API_Compliance.html
- https://docs.aws.amazon.com/securityhub/1.0/APIReference/API_AwsSecurityFindingFilters.html

## Grafana Queries

**Decision**: Let each production account supply aggregate uptime and latency PromQL plus the Grafana
URL and datasource UID. Send instant datasource-proxy queries at the reporting-period end and require
exactly one finite scalar value from each response. Validate uptime in 0–100 and latency at or above
zero before writing either row.

**Rationale**: Label sets differ between clients, while the two KPI meanings remain fixed. Supplying
queries keeps the shared module client-neutral. Pair validation prevents a partial application report
caused by an invalid source response.

**Alternatives considered**: Embed one client's labels; dashboard-panel extraction; Grafana alerts.

## CloudBrowser Account and Writes

**Decision**: Resolve exactly one account using account ID, configured client ID, and the AWS provider
ID. Query metric data using metric/client/account/date with a page size of two. Create only when none
exists, skip only exact numeric equality with the submitted deterministically rounded value, and fail
on every changed value or multiple matches. Safe GET requests
use bounded retry. A POST is attempted once. If its outcome is ambiguous because of a network error,
429, or 5xx response, immediately query the natural key again: one equal row reconciles success, one
unequal row or multiple rows is a conflict, and no row fails the invocation for a later replay. Reserve
one concurrent Lambda execution per account so scheduled and manual collector invocations serialize.

**Rationale**: CloudBrowser currently has account records and supports the account relation on metric
data. Existing rows can share client/date/metric across accounts, so account is required in the key.
Failing closed preserves source evidence and avoids silent overwrite. Serialization and post-write
reconciliation close the collector's own GET-then-POST race without assuming a CloudBrowser uniqueness
constraint. External writers remain subject to CloudBrowser's server-side data controls.

**Alternatives considered**: Create account metadata in Lambda; client-level duplicate keys;
automatic overwrite.

## Failure Handling

**Decision**: Retry safe GET throttling, network errors, HTTP 429, and HTTP 5xx with bounded backoff.
Never retry a POST in place; reconcile an ambiguous POST through the natural-key GET. Let permanent
auth, validation, ambiguity, and conflict errors fail. AWS metrics are independent; application values
are collected and validated as a pair. Any failed metric makes the invocation fail after successful
independent rows are written. EventBridge Scheduler retries target delivery failures and sends exhausted
deliveries to the queue. Lambda's asynchronous invocation configuration retries handler failures and
sends exhausted events to the same queue. Both roles receive only `sqs:SendMessage` for that queue.

**Rationale**: This preserves valid cost when Security Hub is intentionally unavailable and makes
partial network failure recoverable without duplicate records while distinguishing delivery failures
from accepted invocations whose handler later fails.

**Alternatives considered**: All-or-nothing AWS jobs; unlimited retry; swallowing failed rows.
