# Research: Canonical Application KPI Queries

## Decision: Explicit NGINX ingress query profile

Add optional `query_profile` and `metric_filter` fields to the existing grouped application object. Only `query_profile = "nginx_ingress"` with both raw queries omitted and a non-empty filter activates built-in NGINX query generation.

**Rationale**: This makes the common MSP case concise without making generic Prometheus synonymous with NGINX. Advanced query pairs remain source-agnostic and backward compatible.

**Alternatives considered**: A new `prometheus_nginx` source type would widen runtime concepts unnecessarily. Inferring NGINX from `metric_filter` would be wrong for customers with other Prometheus schemas. Hard-coded global selectors would be unsafe for multi-service MSP environments. Continuing to copy raw queries would preserve drift.

## Decision: Preserve average-latency semantics

Keep request-weighted average latency for the existing CloudBrowser latency relation rather than replacing it with `histogram_quantile(0.95, ...)`.

**Rationale**: The destination contract is `Latency(avg)` in seconds. A p95 is useful as a tail-latency SLI, but storing it as an average would mislabel the measurement and make cross-client reporting inconsistent. A future p95 must use a separately named metric contract.

## Decision: Generate at Terraform configuration time

Build the two strings in child-module locals and serialize them through the existing handler configuration.

**Rationale**: The Lambda already validates and executes raw Prometheus queries. Keeping query construction outside runtime avoids new package behavior, IAM, and deployment risks.

## Decision: Exact-window aggregations

Use `increase(...[$__account_kpi_window] @ $__account_kpi_end_seconds)` in every counter/histogram component.

**Rationale**: The collector substitutes the prior-week duration and end epoch, making retries and delayed runs repeat the same reporting boundary.

## Primary references

- Prometheus query functions and `@` modifier: https://prometheus.io/docs/prometheus/latest/querying/functions/ and https://prometheus.io/docs/prometheus/latest/querying/basics/
- ingress-nginx monitoring metrics: https://kubernetes.github.io/ingress-nginx/user-guide/monitoring/
- Prometheus histogram quantiles: https://prometheus.io/docs/practices/histograms/
- Google SRE SLO implementation guidance: https://sre.google/workbook/implementing-slos/
