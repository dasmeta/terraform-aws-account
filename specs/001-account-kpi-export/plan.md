# Implementation Plan: Weekly Account KPI Export

**Branch**: `001-account-kpi-export` | **Date**: 2026-09-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from [spec.md](spec.md)

## Summary

Add an opt-in `account_kpi_export` wrapper to the shared AWS account module. Each enabled account
gets one Python Lambda and two conditional EventBridge Scheduler entries: Monday collects the prior
week's production Grafana uptime and latency, while Wednesday collects that account's prior-week
UnblendedCost and an execution-time Security Hub score. The collector resolves the existing
CloudBrowser account, checks the full metric/client/account/date key before every write, reads API
tokens from one Secrets Manager secret at runtime, and exposes delivery retries, Lambda asynchronous
handler retries, one shared failure queue, and alarms.

## Technical Context

**Language/Version**: Terraform `~> 1.3`; Python 3.13 Lambda runtime with Python 3.9-compatible source for local tests
**Primary Dependencies**: AWS provider `>= 5.0, < 7.0`; `terraform-aws-modules/lambda/aws` 7.21.1; `terraform-aws-modules/eventbridge/aws` 3.17.1; `terraform-aws-modules/sqs/aws` 4.3.1; `terraform-aws-modules/cloudwatch/aws//modules/metric-alarm` 5.7.2; Lambda runtime `boto3`; Python standard library
**Storage**: Existing CloudBrowser account and metric-data records; one AWS Secrets Manager secret reference; encrypted SQS dead-letter queue
**Testing**: Python `unittest`, Terraform native tests with mocked AWS provider, `terraform fmt`, `terraform init -backend=false`, `terraform validate`, `terraform test`, `tflint`, `terraform-docs`, pre-commit, and available security scanners
**Target Platform**: AWS Lambda on Amazon Linux 2023, deployed once in each enabled AWS account
**Project Type**: Shared Terraform wrapper module with a reusable child module and packaged Lambda
**Performance Goals**: Finish either weekly invocation inside the default 600-second timeout; bound individual HTTP calls to 15 seconds and retry only safe GET transient failures. The larger timeout is a ceiling for bounded retry paths; Lambda cost remains based on actual execution duration.
**Constraints**: No tokens in Terraform state or logs; no VPC/NAT requirement; exact current-account filtering; complete Monday-through-Sunday periods; duplicate-safe writes; one reserved Lambda execution per account; checked-in deterministic ZIP for Terraform Cloud
**Scale/Scope**: One Lambda per enabled account, up to two schedules and four metric rows per week per account

## Constitution Check

- **Backward compatibility — PASS**: `account_kpi_export.enabled` defaults to false. The existing
  `cost_report_export` interface and resources remain unchanged.
- **Secret and account isolation — PASS**: Terraform receives only a secret ARN and JSON key names.
  Cost Explorer and Security Hub requests filter the Lambda's runtime account ID. The secret policy
  is scoped to one ARN; AWS metric policies contain only the enabled read actions.
- **Test first — PASS**: Python unit tests and Terraform configurations are created and observed
  failing before their implementations. The final validation matrix is listed in `quickstart.md`.
- **CloudBrowser first — PASS**: Existing clients, providers, account records, and metric definitions
  were queried before design. Runtime writes resolve one existing AWS account and query the complete
  duplicate key before POST, never retries POST in place, and reconciles ambiguous outcomes; account
  creation remains an onboarding task.
- **Operations — PASS**: Structured logs, bounded safe-read retries, conflict handling, partial retry
  behavior, separate Scheduler delivery and Lambda handler retry policies, one SQS failure queue, and
  Lambda/DLQ alarms are in scope.
- **Client neutrality — PASS**: Shared code, examples, fixtures, and tests use generic identifiers.

## Current Repository and Wrapper Assessment

The root account module already exposes grouped optional objects and delegates focused capabilities
to child modules. `cost_report_export` uses the Lambda and EventBridge upstream modules, a checked-in
ZIP, and an opt-in root wrapper. It currently posts daily cost to an unauthenticated webhook and has
no CloudBrowser account relation, Security Hub score, Grafana source, or duplicate protection.

The new child preserves this opinionated wrapper pattern. Consumers configure business-level source,
schedule, metric, and secret-reference settings; they do not receive the broad upstream module
surfaces. Non-critical settings remain optional. No existing requiredness or behavior changes.

Repository gaps addressed in scope are source tests for the packaged Lambda, explicit output
descriptions, conditional least-privilege policies, and failure monitoring. Unrelated existing module
documentation and resources are outside scope.

## Upstream and Modern Capability Assessment

The approved AWS provider-maintained collection was checked before selecting resources:

| Ability | Candidate | Decision and classification |
|---|---|---|
| Lambda deployment | `terraform-aws-modules/lambda/aws` 7.21.1 | **supported**; reuse the repository pattern and checked-in package path. |
| Time-zone schedules | `terraform-aws-modules/eventbridge/aws` 3.17.1 | **supported**; Scheduler is the upstream module's recommended schedule path and supports time zone, retries, and DLQ. |
| Failure queue | `terraform-aws-modules/sqs/aws` 4.3.1 | **supported**; one encrypted queue receives exhausted Scheduler delivery failures and Lambda asynchronous handler failures. |
| Failure alarms | `terraform-aws-modules/cloudwatch/aws//modules/metric-alarm` 5.7.2 | **supported**; create focused Lambda Errors and visible-DLQ alarms. |
| Runtime | AWS Lambda Python 3.13 | **supported**; maintained on Amazon Linux 2023 through June 2029 and accepted by AWS provider 5.98. |
| Metrics APIs | Cost Explorer, Security Hub, Grafana, CloudBrowser | **supported** public APIs; no deprecated or console-private operations. |

The root provider declaration stays `>= 5.0, < 7.0`; the pinned EventBridge child already imposes an
effective minimum AWS provider version of 5.98. Python 3.13 preserves that boundary; Python 3.14
runtime validation was added in provider 6.21. See [runtime source evidence](research.md#runtime-and-packaging).
No fallback scratch template is needed. Shared module rules come from the Terraform module developer
skill. CloudBrowser-first evidence and the repository-specific gates are recorded in this durable
feature package. The package contains `spec.md`, this plan, and `tasks.md`, satisfying the downstream
module-change gate without retaining the generic planning-tool bootstrap.

## Interface Decision

The root adds one grouped `account_kpi_export` object because all settings share one lifecycle and the
top-level `enabled` switch gives a deterministic compatibility boundary. Its nested groups are:

- `cloudbrowser`: base URL, client ID, AWS provider ID, secret ARN, and CloudBrowser/Grafana token key names.
- `application`: production-only enablement, Grafana URL, datasource UID, and two aggregate PromQL queries.
- `cost` and `security`: independent enablement and Security Hub aggregation Region.
- `metrics`: overridable CloudBrowser IDs with defaults 4, 12, 24, and 26.
- `schedules`: Monday/Wednesday expressions, IANA time zone, delivery retry age, and delivery attempts.
- `lambda`: name, timeout, memory, log retention, asynchronous handler retry age and attempts, and alarm action ARNs. Reserved concurrency is fixed at one.

All nested fields other than identities and enabled-source requirements are optional with safe
defaults. Validation requires the secret ARN, positive client/provider/metric IDs, at least one
enabled source, and complete Grafana settings when application collection is enabled. This is a
narrow interface addition and does not widen any existing wrapper.

## Project Structure

### Documentation (this feature)

```text
specs/001-account-kpi-export/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── cloudbrowser-api.md
│   ├── scheduler-event.schema.json
│   └── terraform-interface.md
└── tasks.md
```

### Source Code (repository root)

```text
account-kpi-export.tf                       # Root opt-in wrapper
variables.tf                                # Root grouped input and validation
outputs.tf                                  # Safe root exporter output
README.md                                   # Root usage and migration notes
modules/account-kpi-export/
├── data.tf                                 # Runtime account/partition data
├── locals.tf                               # Environment and conditional policies/schedules
├── main.tf                                 # Lambda, SQS, Scheduler, and alarms
├── variables.tf                            # Narrow child interface and validation
├── outputs.tf                              # Lambda, schedules, DLQ, and alarm identifiers
├── versions.tf                             # Existing Terraform/provider convention
├── README.md                               # Direct child usage and generated reference
├── account-kpi-export-lambda.zip           # Deterministic Terraform Cloud artifact
├── examples/basic/
│   ├── main.tf
│   ├── versions.tf
│   └── README.md
├── scripts/build_package.py                # Reproducible ZIP builder
├── src/
│   ├── aws_metrics.py                      # Cost and Security Hub collection
│   ├── cloudbrowser.py                     # Account lookup and idempotent metric writes
│   ├── grafana.py                          # Grafana request and scalar validation
│   ├── handler.py                          # Configuration, routing, orchestration, outcomes
│   ├── http_client.py                      # Authenticated JSON requests and transient retry
│   └── reporting_period.py                 # Prior-week and record-date calculation
└── tests/
    ├── test_aws_metrics.py
    ├── test_cloudbrowser.py
    ├── test_grafana.py
    ├── test_handler.py
    └── test_reporting_period.py
tests/account-kpi-export-enabled/
├── 0-setup.tf
├── 1-example.tf
└── README.md
tests/account-kpi-export-compatibility/
├── 0-setup.tf                             # Root-module test harness
├── 1-example.tf                           # Omitted and explicitly disabled cases
└── account_kpi_export.tftest.hcl          # Mocked zero-resource plan assertions
```

**Structure Decision**: Keep orchestration, integrations, and calendar logic in focused Python files
inside one reusable child. The root remains a small compatibility wrapper. Existing repository test
directories validate root-module consumption; child unit and native Terraform tests validate behavior.

## Post-Design Constitution Check

All pre-design gates remain satisfied. The API contracts define the account relation and duplicate
key, the data model separates interval measurements from the point-in-time security snapshot, and the
quickstart includes plan-based omission and explicit-disable compatibility checks, security, packaging,
and operational verification. No exception, breaking change, interface-widening approval, or
provider-bound exemption is required.

## Complexity Tracking

No constitution violations require justification.
