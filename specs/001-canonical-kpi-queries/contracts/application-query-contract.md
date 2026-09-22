# Application Query Contract

## Canonical configuration

```hcl
application = {
  enabled        = true
  grafana_url    = "https://grafana.example.com"
  datasource_uid = "example-prometheus"
  query_profile  = "nginx_ingress"
  metric_filter  = "namespace=\"production\", ingress=~\"api|web\""
}
```

## Generated uptime

```promql
100 * sum(increase(nginx_ingress_controller_requests{status!~"5..", <filter>}[$__account_kpi_window] @ $__account_kpi_end_seconds)) / sum(increase(nginx_ingress_controller_requests{<filter>}[$__account_kpi_window] @ $__account_kpi_end_seconds))
```

## Generated latency

```promql
sum(increase(nginx_ingress_controller_request_duration_seconds_sum{status=~"2..|3..", <filter>}[$__account_kpi_window] @ $__account_kpi_end_seconds)) / sum(increase(nginx_ingress_controller_request_duration_seconds_count{status=~"2..|3..", <filter>}[$__account_kpi_window] @ $__account_kpi_end_seconds))
```

## Compatibility

A complete `uptime_query` plus `latency_query` pair with an empty `query_profile` and `metric_filter` is serialized byte-for-byte as before. A metric filter alone does not imply NGINX. Existing `source_type = "cloudwatch_alb"` is unchanged.
