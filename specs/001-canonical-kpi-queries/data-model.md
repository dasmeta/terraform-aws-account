# Data Model

## Application Configuration

- `enabled`: whether weekly application collection runs
- `source_type`: existing Prometheus or CloudWatch ALB source
- `grafana_url`: HTTPS Grafana endpoint
- `datasource_uid`: Grafana data source identifier
- `metric_filter`: optional NGINX label matcher fragment used by canonical mode
- `uptime_query`: optional advanced override
- `latency_query`: optional advanced override
- `region` and `load_balancer`: existing CloudWatch ALB settings

## Mode Rules

- Canonical Prometheus: both queries empty; `metric_filter` non-empty.
- Override Prometheus: both queries non-empty and each has both time-boundary placeholders; `metric_filter` may be present but is ignored.
- Invalid Prometheus: exactly one query is non-empty, or all three canonical/override inputs are empty.
- CloudWatch ALB: existing region/load-balancer rules; Prometheus query fields do not participate.

## Runtime Configuration

The existing runtime application object always receives explicit `uptime_query` and `latency_query` in Prometheus mode. Canonical/override selection is not exposed to the Lambda.
