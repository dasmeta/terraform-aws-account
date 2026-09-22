# Data Model

## Application Configuration

- `enabled`: whether weekly application collection runs
- `source_type`: existing Prometheus or CloudWatch ALB source
- `grafana_url`: HTTPS Grafana endpoint
- `datasource_uid`: Grafana data source identifier
- `query_profile`: optional explicit built-in query schema; currently only `nginx_ingress`
- `metric_filter`: optional NGINX label matcher fragment used by canonical mode
- `uptime_query`: optional advanced override
- `latency_query`: optional advanced override
- `region` and `load_balancer`: existing CloudWatch ALB settings

## Mode Rules

- Profile Prometheus: `query_profile = "nginx_ingress"`, both queries empty, and `metric_filter` non-empty.
- Raw Prometheus: `query_profile` and `metric_filter` empty; both queries non-empty and each has both time-boundary placeholders.
- Invalid Prometheus: filter without a profile, unknown profile, profile mixed with raw queries, exactly one query, or all profile/raw inputs empty.
- CloudWatch ALB: existing region/load-balancer rules; Prometheus query fields do not participate.

## Runtime Configuration

The existing runtime application object always receives explicit `uptime_query` and `latency_query` in Prometheus mode. Profile/raw selection is not exposed to the Lambda.
