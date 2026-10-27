# Feature Specification: Security Hub CSPM routing and corrective remediation

**Feature Branch**: `001-security-hub-alerting`
**Created**: 2026-10-27
**Status**: Ready for planning
**Input**: Fix `terraform-aws-account` Security Hub alerting against the AWS CSPM assessment criteria in `dasmeta/infra-governance` PR #94; include corrective remediation support and changes to `terraform-aws-monitoring`.

## User Scenarios & Testing

### User Story 1 - Reliable critical and high finding alerts (Priority: P1)

An account operator configures one alert destination and can trace active, unresolved CRITICAL/HIGH findings through a single notification route, including failed delivery.

**Independent Test**: A controlled finding event matches the intended route once; a failed target invocation leaves inspectable evidence.

**Acceptance Scenarios**:

1. **Given** a configured account topic, **when** a current high finding arrives, **then** exactly one account-owned notification path is selected.
2. **Given** a resolved or suppressed finding, **when** it is updated, **then** it does not trigger a new automated critical/high alert.
3. **Given** failed delivery, **when** retries expire, **then** operators can identify the failed event and destination.

### User Story 2 - Bounded corrective remediation (Priority: P2)

An operator connects a reviewed corrective workflow to explicitly approved findings and resources. Disabled configuration creates no corrective trigger. An enabled workflow can be observed for start and execution failures.

**Independent Test**: Matching and non-matching synthetic findings exercise the route, and a failed workflow is visible to the operator.

**Acceptance Scenarios**:

1. **Given** no approved workflow, **when** the module is deployed, **then** no automatic resource-changing target is created.
2. **Given** an approved control, account, and resource allowlist, **when** a matching failed finding arrives, **then** only the named workflow may start.
3. **Given** a different account, resource, resolved finding, or control, **when** an event arrives, **then** the corrective target is not invoked.

### User Story 3 - Reviewer-ready configuration evidence (Priority: P3)

An assessor can identify configured routes and their limits without exposing secrets or claiming that a Terraform plan proves a live alert was acknowledged or a resource was corrected.

**Independent Test**: Non-sensitive outputs and documentation identify configured resources and the separate operating evidence required by PR #94.

**Acceptance Scenarios**:

1. **Given** the module outputs and usage guide, **when** an assessor reads them, **then** they can identify route, failure queue, and corrective workflow identifiers.
2. **Given** only configuration evidence, **when** an assessment is produced, **then** live coverage, receipt, acknowledgement, escalation, execution, and validation remain unproven.

### Edge Cases

- A Security Hub hub may already exist and be unmanaged by this module.
- Cross-Region aggregation may repeat finding events; consumers must choose the approved home Region for a route.
- One event may contain more than one resource. The corrective workflow must validate the chosen resource against its allowlist before mutation.
- An EventBridge target may accept a workflow start while the workflow later fails; both failure layers need visibility.
- The notification topic may be shared with account alerts or dedicated to Security Hub.

## Requirements

### Functional Requirements

- **FR-001**: Preserve existing disabled defaults and current input names for alerting and service enablement.
- **FR-002**: Route active, unresolved CRITICAL/HIGH findings with an inspectable failed-delivery path.
- **FR-003**: Distinguish automatic finding alerts, manual action alerts, and corrective remediation in naming and outputs.
- **FR-004**: Require an explicit control, same-account boundary, resource allowlist, approved Standard workflow, and failure destination before corrective routing can be enabled.
- **FR-005**: Restrict permission to start only the approved workflow and require workflow-side validation of selected resources and post-action outcomes.
- **FR-006**: Make corrective and notification failures independently observable.
- **FR-007**: Provide meaningful test cases for default, shared-topic, dedicated-topic, accepted finding, rejected finding, and failure paths.
- **FR-008**: State precisely which PR #94 assessment rows configuration can support and which require live customer evidence.

### Key Entities

- **Finding**: Security Hub record with account, status, severity, control, and affected resources.
- **Alert route**: An automatic or manual route with an owned destination and delivery-failure record.
- **Corrective workflow**: An approved, bounded workflow with owner, control IDs, exact resource IDs, and execution evidence.

## Success Criteria

### Measurable Outcomes

- **SC-001**: All six synthetic positive and negative finding scenarios have the expected alert or corrective routing result.
- **SC-002**: Every enabled corrective workflow declares at least one exact control and resource ID, an owner, and a failure destination.
- **SC-003**: An event outside the approved account, control, or resource scope starts zero corrective workflows.
- **SC-004**: The assessment guide identifies all PR #94 direct CSPM rows and does not rate a row Met from configuration evidence alone.

## Assumptions

- Existing Standard Step Functions workflows are reviewed and owned by the consuming account team. The module creates the guarded route and least-privilege start permission; the workflow itself implements and validates the resource correction.
- Deployment happens in an approved account and Region. No AWS deployment is part of this work.
- `terraform-aws-monitoring` will publish a new immutable release before the account module can consume its alerting changes in a published release.
