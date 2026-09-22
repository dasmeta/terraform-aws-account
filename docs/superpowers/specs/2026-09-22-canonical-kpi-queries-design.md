# Canonical Account KPI Query Design

## Goal

Allow `account.yaml` consumers to select the standard NGINX ingress uptime and latency definitions with a compact metric scope while preserving the existing advanced raw-query escape hatch.

## Consumer contract

The existing grouped `account_kpi_export.application` object gains one optional field:

```hcl
metric_filter = "namespace=\"production\", ingress=~\"api|web\""
```

For a Prometheus source, consumers choose exactly one mode:

1. Canonical mode: omit both raw queries and provide a non-empty `metric_filter`.
2. Override mode: provide both `uptime_query` and `latency_query`, each containing the existing window and end-time placeholders.

Providing only one raw query is invalid. If a complete raw pair is present it wins, preserving all existing consumers. `cloudwatch_alb` behavior is unchanged.

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
- No handler, schedule, IAM, or CloudBrowser API behavior changes.
- The new optional field narrows routine MSP configuration; it does not expose a broad provider surface.

## Validation

Terraform tests will start red by expecting canonical generation. They will cover generated strings, raw-query precedence, partial-query rejection, and root-to-child forwarding. Existing Python tests verify that the runtime still substitutes boundaries and validates returned values.
