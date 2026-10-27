# Implementation Plan: Security Hub CSPM routing and corrective remediation

**Branch**: `001-security-hub-alerting` | **Date**: 2026-10-27 | **Spec**: [spec.md](spec.md)

## Summary

Keep the account module's established `dasmeta/monitoring/aws//modules/security-hub` wrapper. Add an opt-in, same-account route to an already approved Standard Step Functions state machine for exact failed Security Hub controls and resources. The separate monitoring repository owns notification lifecycle filtering and failed SNS target delivery. Expose non-sensitive identifiers and a PR #94 evidence mapping.

## Technical Context

- **Language/Version**: Terraform `~> 1.3`; AWS provider `>= 5.0, < 7.0`.
- **Primary Dependencies**: `dasmeta/monitoring/aws` pinned at `1.21.0` until a new immutable release; AWS EventBridge, IAM, SQS, SNS, Step Functions.
- **Storage**: SQS delivery failure queue; no state or finding payload is stored in the repository.
- **Testing**: `terraform fmt`, `terraform init -backend=false`, `terraform validate`, native `terraform test` on Terraform >= 1.6, and EventBridge fixture checks.
- **Target Platform**: Approved AWS account and Region; no live AWS apply here.
- **Project Type**: Reusable AWS account Terraform wrapper.
- **Constraints**: Backward compatible disabled default; no wildcard remediation resource scope; no implicit access to other accounts; do not claim live audit readiness from configuration.
- **Scale/Scope**: Bounded named workflows per account; no attempt to deploy an organization-wide CSPM estate from one root module.

## Constitution Check

- Source: `infra-governance` PR #94 AWS CSPM assessment and `/Users/Adeline/.agents/skills/constitution/terraform-module-developer/references/internal-module-standards.md`.
- This package exists in the downstream repository before code changes and satisfies the expected Speckit module gate shape. Existing `versions.tf` keeps required providers in place.
- The wrapper remains narrow: a grouped optional `security_hub.remediation_workflows` map. Existing required and optional fields retain their contract; all new object fields receive inline comments.
- This is extend mode. The new EventBridge → Standard Step Functions path, explicit retry, SQS DLQ, and exact `states:StartExecution` IAM policy are **supported** by [AWS EventBridge targets](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-events-iam-roles.html), [AWS Security Hub finding events](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-cwe-all-findings.html), and [Terraform target documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) with the provider range already used here. No established interface is refactored for deprecation.
- No breaking change, wrapper pass-through, contract drift, or governance-source conflict is planned. The opt-in route adds resources only when configured.
- Baseline gaps: legacy `tests/<case>/` files are not discovered by root `terraform test`; native tests and an `examples/` case will be added for this feature. Existing CI has `continue-on-error: true`; this is a separate repository baseline gap and will be reported rather than mixed into alert logic.
- CloudBrowser read: no matching Documentation by title/link; Module catalog search finds generic AWS Account & IAM but no verified link to this repository. No catalog write before implementation evidence and record confirmation.

## Phase 0 Research

See [research.md](research.md). A target DLQ proves failed invocation only; workflow execution results and post-action validation need separate evidence. EventBridge may match one item in a `Resources` array without selecting that item for the workflow, so a workflow must revalidate its chosen resource and limit its own mutation IAM permissions.

## Phase 1 Design

See [data-model.md](data-model.md), [contracts/remediation-workflow.md](contracts/remediation-workflow.md), and [quickstart.md](quickstart.md). `security-hub-remediation.tf` will own only EventBridge and the exact start role; the state machine and its resource mutation permissions remain caller-owned. Build one start-failure queue and one route per workflow; report asynchronous failures through a separate execution-status route and metrics. Changes to monitoring are in its own `specs/002-security-hub-cspm-alerting` package.

## Project Structure

```text
security-hub.tf
security-hub-remediation.tf
variables.tf
outputs.tf
README.md
examples/security-hub-remediation/{0-setup.tf,1-example.tf}
tests/security-hub-cspm.tftest.hcl
specs/001-security-hub-cspm-routing/
```

## Deployment and rollback

Review the Terraform plan in an approved account/Region. Enable one non-production workflow against an exact resource, prove repeated success, failure visibility, and post-action verification, then expand scope deliberately. Roll back by setting the new workflow map to `{}`; confirm there are no running executions before changing the route or the external state machine. Do not apply to customer accounts in this task.

## Verification and residual evidence

Run format, init, validate, native tests, and `git diff --check`. The account module can be validated against its current release independently. The monitoring change needs a tagged release before the account module can pin and consume it. SEC-002 proof still needs full-estate account/Region reconciliation, service and ISV finding ingestion, AI applicability, alert receipt/acknowledgement/escalation, repeated remediation executions, failure handling, and post-action validation.
