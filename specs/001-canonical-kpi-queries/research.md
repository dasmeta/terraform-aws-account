# Research: Canonical Application KPI Queries

## Decision: Optional metric-filter canonical mode

Add one optional field to the existing grouped application object. If both raw queries are omitted, a non-empty filter activates canonical query generation.

**Rationale**: This makes the common MSP case concise without a new source type or runtime branch, while leaving advanced query pairs backward compatible.

**Alternatives considered**: A new `prometheus_nginx` source type would widen runtime concepts unnecessarily. Hard-coded global selectors would be unsafe for multi-service MSP environments. Continuing to copy raw queries would preserve drift.

## Decision: Generate at Terraform configuration time

Build the two strings in child-module locals and serialize them through the existing handler configuration.

**Rationale**: The Lambda already validates and executes raw Prometheus queries. Keeping query construction outside runtime avoids new package behavior, IAM, and deployment risks.

## Decision: Exact-window aggregations

Use `increase(...[$__account_kpi_window] @ $__account_kpi_end_seconds)` in every counter/histogram component.

**Rationale**: The collector substitutes the prior-week duration and end epoch, making retries and delayed runs repeat the same reporting boundary.

## Primary references

- Prometheus query functions and `@` modifier: https://prometheus.io/docs/prometheus/latest/querying/functions/ and https://prometheus.io/docs/prometheus/latest/querying/basics/
- ingress-nginx monitoring metrics: https://kubernetes.github.io/ingress-nginx/user-guide/monitoring/
- Google SRE SLO implementation guidance: https://sre.google/workbook/implementing-slos/
