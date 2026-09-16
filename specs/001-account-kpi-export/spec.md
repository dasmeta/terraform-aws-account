# Feature Specification: Weekly Account KPI Export

**Feature Branch**: `001-account-kpi-export`
**Created**: 2026-09-15
**Status**: Ready for review
**Input**: Add an account-module automation that records weekly application and AWS KPIs in CloudBrowser for every managed client account.

## User Scenarios & Testing

### User Story 1 - Record weekly AWS account KPIs (Priority: P1)

An account manager receives a separate weekly cloud cost and security score for each managed AWS account without manually signing in to that account or copying values into CloudBrowser.

**Why this priority**: Account-level cost and security evidence is required for accurate client reporting and is currently collected through manual or fragmented automation.

**Independent Test**: Enable AWS KPI collection for one account, run the Wednesday job for a known reporting week, and verify that one cost row and one security row are related to the correct CloudBrowser client and account.

**Acceptance Scenarios**:

1. **Given** an enabled account with cost access, **when** the Wednesday collection runs, **then** it records only that account's unblended cost for the previous complete Monday-through-Sunday week.
2. **Given** an enabled account with Security Hub data, **when** the Wednesday collection runs, **then** it records only that account's execution-time security score in the configured aggregation Region and associates the snapshot with the prior reporting week.
3. **Given** a management account that can view member-account data, **when** its collection runs, **then** its cost and security values exclude member accounts.

---

### User Story 2 - Record production application KPIs (Priority: P1)

An account manager receives the previous week's uptime and average latency for each client's production application without creating a recurring alert solely for reporting.

**Why this priority**: Weekly application reliability evidence is part of the same client reporting workflow and must use a complete, consistent reporting period.

**Independent Test**: Enable application collection for a production account, run the Monday job for a Grafana dataset with known values, and verify that uptime and latency rows contain the expected values and account relation.

**Acceptance Scenarios**:

1. **Given** a production account with an enabled application source, **when** the Monday collection runs, **then** it records uptime and average latency for the previous complete Monday-through-Sunday week.
2. **Given** a development, root, or billing-only account, **when** the Monday schedule is evaluated, **then** it does not write application KPI rows.
3. **Given** a production application source that cannot return both measurements, **when** collection runs, **then** neither application measurement is written for that run.

---

### User Story 3 - Retry safely without duplicate records (Priority: P2)

An operator can retry a failed collection without producing duplicate or silently changed CloudBrowser data.

**Why this priority**: Scheduled jobs can be delivered more than once, and partial network failures must not corrupt weekly reporting.

**Independent Test**: Run the same job twice for one account and reporting week, then verify that only one row per metric exists and that a different existing value is reported as a conflict.

**Acceptance Scenarios**:

1. **Given** an identical metric row already exists, **when** the job is retried, **then** the existing row remains unchanged and the retry is reported as a duplicate.
2. **Given** a row with a different value already exists for the same metric, client, account, and date, **when** the job runs, **then** the existing value is not overwritten and the conflict is reported.
3. **Given** a CloudBrowser account cannot be resolved uniquely, **when** the job runs, **then** no metric row is created.

---

### User Story 4 - Adopt the exporter without disrupting existing users (Priority: P3)

A module consumer can opt into the weekly exporter while existing consumers continue using the current account module behavior until they deliberately migrate.

**Why this priority**: The account module is shared by multiple client repositories and must not create new scheduled workloads during a routine version upgrade.

**Independent Test**: Evaluate an existing account-module configuration without the new feature and verify that its planned resources remain unchanged.

**Acceptance Scenarios**:

1. **Given** an existing consumer with no weekly exporter configuration, **when** it upgrades the module, **then** no weekly collector resources are created.
2. **Given** a consumer enabling the weekly exporter, **when** it migrates, **then** the old cost webhook exporter can be disabled independently before the first Wednesday run.

### Edge Cases

- Cost data is unavailable because account-level Cost Explorer access is disabled.
- Security Hub is disabled, has no enabled standards, or has no scoreable control data.
- A production Grafana source returns no series, multiple unexpected series, a non-numeric value, or a timeout.
- CloudBrowser contains zero or multiple AWS account records matching the current account and client.
- A scheduled invocation happens more than once or resumes after some rows were created.
- A reporting week crosses a month, year, or daylight-saving boundary.
- A management account can see organization-wide cost or administrator-level Security Hub findings.
- The old cost webhook exporter remains active during migration.

## Requirements

### Functional Requirements

- **FR-001**: The account module MUST provide an opt-in weekly KPI exporter that is disabled by default.
- **FR-002**: Each enabled AWS account MUST have exactly one collector Lambda, and both of that account's schedules MUST target that Lambda.
- **FR-003**: Cost, uptime, and latency MUST use the previous complete Monday-through-Sunday reporting period in a configured reporting time zone.
- **FR-004**: The Monday job MUST collect uptime and average latency only for accounts explicitly configured as production application accounts.
- **FR-005**: The Monday job MUST validate both application measurements before writing either value.
- **FR-006**: The Wednesday job MUST collect account-scoped unblended cost and an execution-time Security Hub score independently when each source is enabled.
- **FR-007**: Cost collection MUST exclude costs attributed to other AWS accounts, including when running in a management account.
- **FR-008**: Security collection MUST exclude findings belonging to other AWS accounts, including when running in an administrator or aggregation account.
- **FR-009**: The security score MUST be the percentage of unique scoreable controls that pass, counting failed and unknown controls in the denominator and excluding archived, suppressed, disabled, and no-data controls.
- **FR-010**: Every metric row MUST relate the metric, CloudBrowser client, CloudBrowser AWS account, value, and deterministic reporting date. Cost, uptime, latency, and the Wednesday security snapshot MUST use Wednesday within the prior reporting week so the four rows remain associated with one weekly report.
- **FR-011**: Before writing metrics, the collector MUST verify that exactly one CloudBrowser AWS account matches the runtime AWS account and configured client.
- **FR-012**: Duplicate detection MUST use metric, client, account, and reporting date.
- **FR-013**: An identical existing row MUST be left unchanged; a different existing value MUST be reported as a conflict and MUST NOT be overwritten automatically.
- **FR-014**: API credentials MUST be read at runtime from an approved secret store and MUST NOT appear in module configuration, state, logs, or scheduled-event payloads.
- **FR-015**: The collector MUST expose clear success, skipped, conflict, and failure results without logging secret values.
- **FR-016**: Schedule expressions, reporting time zone, source enablement, metric identifiers, client identifier, Grafana source settings, and secret references MUST be configurable per account.
- **FR-017**: Existing account module consumers MUST experience no new resources or behavior unless they enable the exporter.
- **FR-018**: The existing cost webhook exporter MUST remain available for backward compatibility and be independently disabled during migration.

### Key Entities

- **Reporting week**: The previous complete Monday-through-Sunday date interval whose Wednesday is the deterministic CloudBrowser record date for all four weekly rows.
- **Account KPI configuration**: Per-account client identity, enabled jobs, schedules, source settings, metric identifiers, and secret references.
- **CloudBrowser account**: The existing AWS account record that must match the runtime AWS account and configured client.
- **Metric row**: A value related to one metric, one client, one AWS account, and one reporting date.
- **Application measurement**: Production uptime percentage or average latency in seconds obtained from the configured application source.
- **AWS measurement**: Account-specific unblended cost for the reporting week or a Wednesday execution-time Security Hub control score associated with that week.

## Success Criteria

### Measurable Outcomes

- **SC-001**: For every fully configured account, the expected Wednesday cost and security rows are available in CloudBrowser by the end of the scheduled run.
- **SC-002**: For every fully configured production account, the expected Monday uptime and latency rows are available in CloudBrowser by the end of the scheduled run.
- **SC-003**: Replaying any scheduled job three times produces no more than one row per metric, client, account, and reporting date.
- **SC-004**: A management or administrator account test produces values attributable only to its own AWS account.
- **SC-005**: Enabling the exporter never stores a CloudBrowser or Grafana token in plain-text configuration, state, logs, or event payloads.
- **SC-006**: Upgrading without enabling the exporter creates zero new collector resources.
- **SC-007**: All date-boundary, account-isolation, score-calculation, duplicate, conflict, and partial-failure scenarios pass automated verification.

## Assumptions

- CloudBrowser already contains the client, metric definitions, and an AWS account record for each account before the exporter is enabled.
- The established metric identifiers are Security Level `4`, Cloud Cost `12`, Uptime `24`, and Latency (avg) `26`, with per-account overrides available.
- CloudBrowser aggregates account-level cost using sum and the other three KPIs using average.
- Application collection is enabled only in each client's production application account.
- Grafana is reachable over HTTPS from a Lambda that is not attached to a customer VPC.
- Cost Explorer access is enabled for each participating account.
- Security Hub cannot reconstruct a historical Sunday score from current findings. Its value is a point-in-time Wednesday snapshot that is explicitly associated with the prior reporting week rather than presented as a Sunday score.
- The reporting date follows the existing convention of Wednesday at local midnight within the prior reported week for all four metrics.
