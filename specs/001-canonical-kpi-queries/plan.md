# Implementation Plan: Canonical Application KPI Queries

**Branch**: `fix/canonical-kpi-queries` | **Date**: 2026-09-22 | **Spec**: [spec.md](spec.md)

## Summary

Extend the existing grouped application settings with an optional NGINX ingress metric filter. When both raw Prometheus queries are omitted, derive the corrected Grafana uptime and average-latency queries with the collector's exact-window placeholders. Preserve complete raw-query pairs and all CloudWatch ALB behavior.

## Technical Context

**Language/Version**: Terraform HCL `~> 1.3`; Python 3 collector unchanged
**Primary Dependencies**: Existing `modules/account-kpi-export` wrapper and Grafana Prometheus proxy contract
**Storage**: AWS Lambda environment configuration only; no new persistence
**Testing**: Native `terraform test`, Python `unittest`, formatting and plan checks
**Target Platform**: AWS account module; Prometheus-compatible Grafana data source
**Project Type**: Terraform wrapper module repository
**Performance Goals**: No additional source calls; still two application queries per weekly collection
**Constraints**: Backward compatibility; exact time boundaries; no new metric IDs; no handler/IAM/schedule changes
**Scale/Scope**: Root wrapper object, child exporter object/locals, examples, READMEs, Terraform tests

## Constitution Check

- Downstream repository confirmed: `terraform-aws-account`.
- Speckit was bootstrapped for this repository with user approval.
- Speckit evidence: `specs/001-canonical-kpi-queries/{spec,plan,tasks}.md`.
- Module-change gate: expected to pass after package and implementation are committed.
- Current state: the opinionated exporter accepts a grouped application object but requires consumers to copy both queries.
- Standards gap: routine MSP consumers lack a safe derived default; examples use placeholder queries unrelated to the dashboard.
- Wrapper preservation: one optional field is added inside the existing grouped object; existing raw-query and CloudWatch modes remain unchanged.
- Grouped/optional mapping: `metric_filter` is optional because legacy raw-query and CloudWatch consumers do not need it.
- Repository convention: provider declarations remain in `versions.tf`; no version constraints change.
- Governance source: `terraform-module-developer` constitution references.
- Modern Capabilities Rule: extend mode; canonical PromQL generation is **supported** by the existing Prometheus/Grafana platform and Terraform optional object attributes already allowed by `~> 1.3`.
- Provider collection/upstream candidate review: not applicable; no new resource or module is created.
- Potential breaking changes: none. A complete raw query pair keeps precedence and serialization.
- Interface widening: bounded one-field extension for the common MSP use case, explicitly requested and approved.
- Conflicts requiring approval: none.

## Project Structure

### Documentation

```text
specs/001-canonical-kpi-queries/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/application-query-contract.md
└── tasks.md
```

### Source Code

```text
variables.tf
account-kpi-export.tf
README.md
modules/account-kpi-export/
├── variables.tf
├── locals.tf
├── README.md
└── tests/account_kpi_export.tftest.hcl
tests/
├── account-kpi-export-enabled/1-example.tf
├── account-kpi-export-enabled/account_kpi_export.tftest.hcl
└── account-kpi-export-url-validation.tftest.hcl
```

**Structure Decision**: Preserve the root-to-child grouped object and materialize canonical raw queries only in the child locals, leaving the Lambda runtime contract unchanged.

## Design Decisions

1. Add `metric_filter` rather than a new source type. It is the smallest backward-compatible input and keeps Prometheus behavior in one mode.
2. Canonical mode is selected only when both raw queries are empty. Override mode requires both queries and existing boundary placeholders.
3. Reject one-query configurations even when a metric filter exists; never mix canonical and custom halves.
4. Trim the metric filter before insertion and require it to be non-empty in canonical mode, preventing cross-tenant/global aggregation by default.
5. Serialize generated queries as `source_type = "prometheus"`; no Python handler change is needed.

## Proposed File Changes

- Add and validate `metric_filter` in root and child `application` object variables.
- Forward `metric_filter` through the root module call.
- Derive canonical query strings in child locals and keep explicit-pair precedence.
- Add red/green Terraform tests for generated strings, override compatibility, and partial-query rejection.
- Update neutral examples and generated module documentation to show canonical mode.
- Do not change metric IDs, Lambda code/package, IAM, schedules, or CloudBrowser writes.
