# Weekly account KPI export

This child module deploys one Python 3.13 Lambda in one AWS account. It records weekly KPI rows in
CloudBrowser for that account. Use the root account module for normal adoption; use this child
directly when the surrounding account resources are managed elsewhere.

## Direct usage

```hcl
module "account_kpi_export" {
  source  = "dasmeta/account/aws//modules/account-kpi-export"
  version = "x.y.z"

  cloudbrowser = {
    client_id  = 123
    secret_arn = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:example-account-kpi"
  }

  # Enable this block only in the production application account.
  application = {
    enabled        = true
    grafana_url    = "https://grafana.example.com"
    datasource_uid = "example-prometheus"
    uptime_query   = "100 * avg_over_time(example_service_up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
    latency_query  = "avg_over_time(example_request_latency_seconds[$__account_kpi_window] @ $__account_kpi_end_seconds)"
  }

  tags = {
    ManagedBy = "terraform"
  }
}
```

The complete local example is in [`examples/basic`](examples/basic).

Every enabled query must include `$__account_kpi_window` and `$__account_kpi_end_seconds`. The
Lambda replaces the window token with the exact previous local week's duration in seconds (including
the trailing `s`) and the end token with its UTC Unix-second end before URL encoding. This preserves
167-, 168-, and 169-hour weeks across daylight-saving changes. `$__account_kpi_start_seconds` may
also be used when a query needs the start instant. Latency queries must return seconds, matching the
CloudBrowser Latency metric; do not multiply seconds by 1000.

## Schedule and reporting period

The default time zone is `Asia/Yerevan`, and both schedules run at 06:00 in that time zone.

- Monday runs the `application` job only when application collection is enabled. Enable it only in
  the production application account. It queries Grafana for uptime and latency over the previous
  complete Monday-through-Sunday interval.
- Wednesday runs the `aws` job in every account with cost or security collection enabled. Cost is
  the sum of daily unblended cost for the previous complete Monday-through-Sunday interval. Security
  is the score observed at execution time on Wednesday; it is a point-in-time snapshot, not a
  historical interval value.
- All four metric types use the Wednesday inside the previous reporting week as their CloudBrowser
  record date. The execution-time Security Hub snapshot is therefore recorded on the prior-week
  Wednesday so one weekly report has one date.

Deploy one module instance per AWS account. Each instance creates one Lambda and writes separate
cost and security rows related to its runtime AWS account. Only the production application account
also writes uptime and latency rows.

## Secret and CloudBrowser prerequisites

Before enabling the module, confirm that CloudBrowser already has the client, AWS provider, metric
definitions, and exactly one AWS account record for the runtime account ID and configured client.
The default metric relation IDs are Security `4`, Cost `12`, Uptime `24`, and Latency `26`; override
them only when the CloudBrowser definitions differ.

Create the referenced Secrets Manager value as JSON. Keep the key names aligned with
`cloudbrowser.cloudbrowser_token_key` and `cloudbrowser.grafana_token_key`:

```json
{
  "cloudbrowser_api_token": "<cloudbrowser-api-token>",
  "grafana_api_token": "<grafana-service-account-token>"
}
```

Terraform receives only the secret ARN and JSON key names. The Lambda reads token values at runtime;
do not put tokens in Terraform variables, source files, event payloads, or tags. A Grafana token is
needed only when application collection is enabled.

## Duplicate and conflict behavior

Before every write, the Lambda queries CloudBrowser using the complete natural key: metric, client,
account, and record date.

- No existing row: submit exactly one POST.
- One row with an exactly equal decimal numeric value: return `skipped_duplicate` and do not POST.
  Numeric spellings such as `1.2300` and `1.23` compare equal.
- One row with any different value, including a difference smaller than `0.000001`: fail with a
  conflict and do not overwrite the row.
- More than one matching row: fail with a conflict and do not write.

POST requests are never retried in place. If a POST response is lost after the server may have
created the row, the Lambda repeats the natural-key GET once. One equal row is reconciled as created;
no row re-raises the ambiguous outcome, and an unequal or duplicated row raises a conflict. These
checks prevent this collector's logical replays from adding a second row. CloudBrowser should still
enforce server-side controls for concurrent external writers.

## Access, retries, and monitoring

The Lambda role can read only the configured secret ARN and send failed asynchronous invocations to
the module queue. It receives `ce:GetCostAndUsage` and the two Security Hub read actions only when
those sources are enabled. Cost Explorer and Security Hub do not support resource-scoped access for
these API calls, so those actions use `Resource = "*"`. The Scheduler role can invoke only the module
Lambda and send exhausted delivery attempts to the same queue.

Safe GET requests use bounded retries for transient network, throttling, and server failures. Metric
POSTs use the reconciliation behavior above. EventBridge Scheduler target delivery and Lambda
asynchronous handling have separate configurable retry policies. Exhausted failures go to one
SQS-managed encrypted queue. One CloudWatch alarm watches Lambda errors and another watches visible
queue messages; set `lambda.alarm_action_arns` to route them to operators.

## First-run verification

After the first reviewed apply, invoke the Lambda manually with `{"job":"aws"}`. In the production
application account, also invoke it with `{"job":"application"}`. Verify:

1. Each enabled metric has one row for the correct client, account, and prior-week Wednesday.
2. Cost covers the previous complete Monday-through-Sunday interval.
3. Security is identified operationally as the current Wednesday snapshot even though its record
   date is the previous week's Wednesday.
4. Repeating the same invocation reports `skipped_duplicate` for every existing equal row and adds
   no rows.
5. The Lambda error and visible failure-queue alarms have the intended notification actions.

## Migration and rollback

If the account uses the legacy `cost_report_export`, disable it before the new Wednesday schedule can
run so both exporters do not report cost in parallel. Confirm CloudBrowser prerequisites and complete
the manual first-run checks before relying on the weekly rows. The legacy input remains supported.

To roll back, disable this module to remove its schedules and runtime resources, then re-enable the
legacy exporter if its daily webhook is still required. Do not delete or rewrite CloudBrowser metric
rows during rollback; they are immutable reporting evidence.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.98.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.64.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_failure_queue"></a> [failure\_queue](#module\_failure\_queue) | terraform-aws-modules/sqs/aws | 4.3.1 |
| <a name="module_failure_queue_alarm"></a> [failure\_queue\_alarm](#module\_failure\_queue\_alarm) | terraform-aws-modules/cloudwatch/aws//modules/metric-alarm | 5.7.2 |
| <a name="module_lambda_errors_alarm"></a> [lambda\_errors\_alarm](#module\_lambda\_errors\_alarm) | terraform-aws-modules/cloudwatch/aws//modules/metric-alarm | 5.7.2 |
| <a name="module_lambda_function"></a> [lambda\_function](#module\_lambda\_function) | terraform-aws-modules/lambda/aws | 7.21.1 |
| <a name="module_scheduler"></a> [scheduler](#module\_scheduler) | terraform-aws-modules/eventbridge/aws | 3.17.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_application"></a> [application](#input\_application) | Production application Grafana source. All connection and query fields are required when enabled. | <pre>object({<br/>    enabled        = optional(bool, false)<br/>    grafana_url    = optional(string, "")<br/>    datasource_uid = optional(string, "")<br/>    uptime_query   = optional(string, "")<br/>    latency_query  = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_cloudbrowser"></a> [cloudbrowser](#input\_cloudbrowser) | CloudBrowser endpoint, account relation identifiers, secret reference, and JSON token key names. | <pre>object({<br/>    base_url               = optional(string, "https://app.dasmeta.com")<br/>    client_id              = number<br/>    secret_arn             = string<br/>    aws_provider_id        = optional(number, 1)<br/>    cloudbrowser_token_key = optional(string, "cloudbrowser_api_token")<br/>    grafana_token_key      = optional(string, "grafana_api_token")<br/>  })</pre> | n/a | yes |
| <a name="input_cost"></a> [cost](#input\_cost) | Cost Explorer collection settings. | <pre>object({<br/>    enabled = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_lambda"></a> [lambda](#input\_lambda) | Lambda runtime, asynchronous handler retry, log retention, and alarm notification settings. | <pre>object({<br/>    name                               = optional(string, "account-kpi-export")<br/>    timeout                            = optional(number, 600)<br/>    memory_size                        = optional(number, 256)<br/>    logs_retention_in_days             = optional(number, 30)<br/>    async_maximum_event_age_in_seconds = optional(number, 21600)<br/>    async_maximum_retry_attempts       = optional(number, 2)<br/>    alarm_action_arns                  = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_metrics"></a> [metrics](#input\_metrics) | CloudBrowser metric relation IDs for each collected KPI. | <pre>object({<br/>    security = optional(number, 4)<br/>    cost     = optional(number, 12)<br/>    uptime   = optional(number, 24)<br/>    latency  = optional(number, 26)<br/>  })</pre> | `{}` | no |
| <a name="input_schedules"></a> [schedules](#input\_schedules) | Weekly Scheduler expressions, IANA time zone, and target-delivery retry limits. | <pre>object({<br/>    timezone                              = optional(string, "Asia/Yerevan")<br/>    monday_expression                     = optional(string, "cron(0 6 ? * MON *)")<br/>    wednesday_expression                  = optional(string, "cron(0 6 ? * WED *)")<br/>    delivery_maximum_event_age_in_seconds = optional(number, 86400)<br/>    delivery_maximum_retry_attempts       = optional(number, 2)<br/>  })</pre> | `{}` | no |
| <a name="input_security"></a> [security](#input\_security) | Security Hub collection settings and aggregation Region. | <pre>object({<br/>    enabled = optional(bool, true)<br/>    region  = optional(string, "eu-central-1")<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources created by the exporter. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alarm_arns"></a> [alarm\_arns](#output\_alarm\_arns) | ARNs of the Lambda error and visible failure-queue alarms. |
| <a name="output_failure_queue_arn"></a> [failure\_queue\_arn](#output\_failure\_queue\_arn) | ARN of the shared Scheduler delivery and Lambda handler failure queue. |
| <a name="output_failure_queue_url"></a> [failure\_queue\_url](#output\_failure\_queue\_url) | URL of the shared Scheduler delivery and Lambda handler failure queue. |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | ARN of the weekly KPI collector Lambda function. |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the weekly KPI collector Lambda function. |
| <a name="output_schedule_arns"></a> [schedule\_arns](#output\_schedule\_arns) | ARNs of the enabled weekly EventBridge Scheduler schedules. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
