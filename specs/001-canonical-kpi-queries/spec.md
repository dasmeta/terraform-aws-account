# Feature Specification: Canonical Application KPI Queries

**Feature Branch**: `fix/canonical-kpi-queries`
**Created**: 2026-09-22
**Status**: Approved
**Input**: Let account configuration use the corrected Grafana SLA/SLO uptime and latency definitions for weekly KPI collection without adding metrics.

## User Scenarios & Testing

### User Story 1 - Configure canonical application KPIs (Priority: P1)

As an MSP platform operator, I need to enable weekly uptime and latency collection with an explicit query profile and scoped ingress selector instead of copying long queries into every account configuration.

**Why this priority**: A managed default prevents customer configurations from drifting away from the dashboard definition.

**Independent Test**: Configure an enabled application source with a production ingress scope and no custom queries, then verify that the generated collector configuration contains the canonical uptime and average-latency definitions for the exact reporting window.

**Acceptance Scenarios**:

1. **Given** a valid application source, the `nginx_ingress` query profile, and an ingress metric scope, **When** the account configuration is evaluated, **Then** canonical uptime and latency queries are generated automatically.
2. **Given** a reporting window and end boundary, **When** the collector executes those generated queries, **Then** both calculations cover the same exact period.
3. **Given** existing configurations with two explicit queries, **When** they are evaluated, **Then** they continue to use those queries unchanged.

---

### User Story 2 - Prevent ambiguous query configuration (Priority: P2)

As an MSP platform operator, I need invalid or partial query settings rejected before deployment so weekly customer reporting does not silently use mixed definitions.

**Why this priority**: A half-customized KPI pair can make uptime and latency incomparable across accounts.

**Independent Test**: Evaluate configurations with no scope, one custom query, or incomplete reporting-boundary placeholders and verify each is rejected.

**Acceptance Scenarios**:

1. **Given** application collection with neither an explicit supported profile nor a complete query pair, **When** configuration is validated, **Then** it is rejected.
2. **Given** only one explicit query, **When** configuration is validated, **Then** it is rejected even if a metric scope is also present.
3. **Given** a complete legacy query pair with both reporting-boundary placeholders, **When** configuration is validated, **Then** it remains accepted.

### Edge Cases

- Metric scope is trimmed before insertion and may contain multiple label matchers.
- A metric scope without the `nginx_ingress` query profile is rejected and never implies an NGINX metric schema.
- Unknown query profiles and configurations that combine a profile with raw queries are rejected.
- A generated uptime query counts only 5xx as failed while retaining all statuses in total traffic.
- A generated latency query includes 2xx and 3xx only and weights by request count.
- Query placeholders remain literal in infrastructure configuration until the collector substitutes the exact previous-week window.

## Requirements

### Functional Requirements

- **FR-001**: Application configuration MUST accept an optional `query_profile` and ingress metric scope for canonical query generation.
- **FR-002**: When no explicit query pair is supplied, an enabled Prometheus application source MUST require `query_profile = "nginx_ingress"` and a non-empty metric scope.
- **FR-003**: Generated uptime MUST equal non-5xx requests divided by all scoped requests, multiplied by 100.
- **FR-004**: Generated latency MUST equal total duration divided by request count for scoped 2xx and 3xx responses.
- **FR-005**: Both generated queries MUST retain the collector reporting-window and end-boundary placeholders.
- **FR-006**: Existing complete explicit query pairs MUST remain backward compatible.
- **FR-007**: Partial explicit query pairs MUST be rejected.
- **FR-008**: The generated runtime configuration MUST keep the existing Prometheus handler contract and existing uptime/latency metric identifiers.
- **FR-009**: Examples, module documentation, and automated tests MUST cover canonical generation and legacy override behavior.
- **FR-010**: No new KPI type may be introduced.
- **FR-011**: A Prometheus metric filter by itself MUST NOT select an NGINX-specific schema.
- **FR-012**: Raw-query mode MUST require an empty query profile and a complete placeholder-bearing query pair.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A canonical application KPI configuration requires no copied query strings.
- **SC-002**: Automated tests prove exact generated uptime and latency definitions for 100% of canonical-profile cases.
- **SC-003**: Existing explicit-query test cases continue to pass without consumer changes.
- **SC-004**: Invalid empty, implicit-profile, unknown-profile, mixed-profile, and partial configurations are rejected during planning rather than at collection time.

## Assumptions

- The Grafana data source exposes NGINX ingress controller request and request-duration series.
- The metric scope is operator-authored and identifies one production service boundary.
- HTTP 499 is not a provider-side failure by default; only HTTP 5xx reduces canonical uptime.
- CloudBrowser metric relation IDs 24 (uptime percent) and 26 (average latency seconds) remain the defaults.
- A p95 calculation is intentionally out of scope because it must not be stored under the existing average-latency metric.
