# Terraform Consumer Interface

The root module adds one optional object. Omission and `{ enabled = false }` create no resources.

```hcl
account_kpi_export = {
  enabled = true

  cloudbrowser = {
    client_id  = 42
    secret_arn = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
  }

  application = {
    enabled        = true
    grafana_url    = "https://grafana.example.com"
    datasource_uid = "example-prometheus"
    uptime_query   = "100 * sum(increase(http_requests_total{code!~\"5..\"}[$__account_kpi_window] @ $__account_kpi_end_seconds)) / sum(increase(http_requests_total[$__account_kpi_window] @ $__account_kpi_end_seconds))"
    latency_query  = "sum(increase(http_request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)) / sum(increase(http_request_duration_seconds_count[$__account_kpi_window] @ $__account_kpi_end_seconds))"
  }
}
```

The application group is enabled only in the production application account. Other client accounts
enable the exporter without the application group and produce their own AWS rows.

Each enabled query must include `$__account_kpi_window` and `$__account_kpi_end_seconds`. The Lambda
replaces the window with the exact previous local week's duration in seconds with an `s` suffix and
the end token with the UTC Unix-second end of the reporting week before URL encoding the query.
This supports 167-, 168-, and 169-hour weeks across daylight-saving changes. The optional
`$__account_kpi_start_seconds` token can be used when a query needs the start instant. Latency
queries return seconds.

## Defaults

| Setting | Default |
|---|---|
| Root enabled | `false` |
| Cost enabled | `true` once exporter is enabled |
| Security enabled | `true` once exporter is enabled |
| Application enabled | `false` |
| CloudBrowser base URL | `https://app.dasmeta.com` |
| AWS provider ID | `1` |
| Metric IDs | Security `4`, Cost `12`, Uptime `24`, Latency `26` |
| Time zone | `Asia/Yerevan` |
| Monday schedule | `cron(0 6 ? * MON *)` |
| Wednesday schedule | `cron(0 6 ? * WED *)` |
| Lambda | 600 seconds, 256 MB, 30-day logs |
| Lambda concurrency | One reserved execution per account |
| Scheduler delivery retry | Three delivery attempts, maximum event age 86,400 seconds |
| Lambda handler retry | Two retries, maximum event age 21,600 seconds |
| Failure destination | One encrypted SQS queue shared by exhausted delivery and handler failures |

## Secret JSON

```json
{
  "cloudbrowser_api_token": "runtime-value",
  "grafana_api_token": "runtime-value"
}
```

Only key names and the secret ARN appear in Terraform configuration. The Grafana key is required only
for application collection.

## Migration

Set `cost_report_export.enabled = false` before the first enabled Wednesday schedule. Apply one
account at a time, manually invoke `{"job":"aws"}` and, for production, `{"job":"application"}` once,
then verify the account relation and reporting date in CloudBrowser.
