# Canonical Account KPI Query Design

## Goal

Allow `account.yaml` consumers to select the standard NGINX ingress uptime and latency definitions with an explicit profile and compact metric scope while preserving the source-agnostic raw-query escape hatch.

## Consumer contract

The existing grouped `account_kpi_export.application` object gains explicit optional profile settings:

```hcl
query_profile = "nginx_ingress"
metric_filter = "namespace=\"production\", ingress=~\"api|web\""
```

For a Prometheus source, consumers choose exactly one mode:

1. NGINX profile mode: set `query_profile = "nginx_ingress"`, omit both raw queries, and provide a non-empty `metric_filter`.
2. Raw mode: leave `query_profile` and `metric_filter` empty and provide both `uptime_query` and `latency_query`, each containing the existing window and end-time placeholders.

Providing only a metric filter, an unknown profile, a profile mixed with raw queries, or only one raw query is invalid. `cloudwatch_alb` behavior is unchanged.

## Generated query contract

Canonical uptime is:

```promql
100 * sum(increase(nginx_ingress_controller_requests{status!~"5..", <filter>}[$__account_kpi_window] @ $__account_kpi_end_seconds))
  / sum(increase(nginx_ingress_controller_requests{<filter>}[$__account_kpi_window] @ $__account_kpi_end_seconds))
```

Canonical average latency seconds is:

```promql
sum(increase(nginx_ingress_controller_request_duration_seconds_sum{status=~"2..|3..", <filter>}[$__account_kpi_window] @ $__account_kpi_end_seconds))
  / sum(increase(nginx_ingress_controller_request_duration_seconds_count{status=~"2..|3..", <filter>}[$__account_kpi_window] @ $__account_kpi_end_seconds))
```

Terraform materializes these strings into the existing runtime configuration. The Lambda remains unaware of canonical mode and continues substituting the exact previous-week duration and end epoch before calling the Grafana Prometheus proxy.

## Compatibility and scope

- Existing `source_type = "prometheus"` and raw queries are unchanged.
- Existing CloudWatch ALB collection is unchanged.
- Metric IDs remain uptime 24 and latency 26 by default.
- Metric 26 remains request-weighted average latency in seconds. A p95 must use a separately named metric and is not introduced here.
- No handler, schedule, IAM, or CloudBrowser API behavior changes.
- The new optional field narrows routine MSP configuration; it does not expose a broad provider surface.

## Validation

Terraform tests will cover generated strings, raw-query compatibility, implicit/unknown/mixed/partial-mode rejection, and root-to-child forwarding. Existing Python tests verify that the runtime still substitutes boundaries and validates returned values.
