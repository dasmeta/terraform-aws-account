# The module allows to create aws account cost report scheduled export to an external webhook service

## basic example
```terraform
module "this" {
  source  = "dasmeta/account/aws//modules/cost-report-export"
  version = "1.3.3"

  webhook_endpoint = "https://example-webhook-endpoint.com"
}
```
## The webhook endpoint receives POST request daily with following kind formed json data for success and failure cases
### on success to prepare cost data:
```json
{
  "success": true,
  "message": "Successfully retrieved cost data for 2025-06-03",
  "cost": 47.9213566179,
  "currency": "USD",
  "date": "2025-06-03",
  "accountId": "<aws-account-id>",
  "timestamp": "2025-06-04T09:29:42.115Z"
}
```

### on failure to prepare cost report:
```json
{
  "success": false,
  "message": "Failed to retrieve cost data: {error-description}",
  "accountId": "<aws-account-id>",
  "timestamp": "2025-06-04T09:07:45.455Z"
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_event_bridge"></a> [event\_bridge](#module\_event\_bridge) | terraform-aws-modules/eventbridge/aws | 3.17.1 |
| <a name="module_lambda_function"></a> [lambda\_function](#module\_lambda\_function) | terraform-aws-modules/lambda/aws | 7.21.0 |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eventBridgeBus"></a> [eventBridgeBus](#input\_eventBridgeBus) | Event bridge cronjob/scheduler configs | <pre>object({<br/>    create   = optional(bool, false)                 # whether to create event bridge bus, there is default bus name 'default' what can be used without creating separate one<br/>    name     = optional(string, "default")           # the bus name, default bus pre-exist and we can use it<br/>    schedule = optional(string, "cron(0 5 * * ? *)") # schedule to collect cost data, by default we use once a day at 05:00 AM UTC schedule to collect previous day data 'cron(0 5 * * ? *)'<br/>    timezone = optional(string, "Europe/London")<br/>  })</pre> | `{}` | no |
| <a name="input_logs_retention_in_days"></a> [logs\_retention\_in\_days](#input\_logs\_retention\_in\_days) | Lambda function logs retention days | `number` | `7` | no |
| <a name="input_name"></a> [name](#input\_name) | The naming to use to create resource | `string` | `"account-cost-report"` | no |
| <a name="input_webhook_endpoint"></a> [webhook\_endpoint](#input\_webhook\_endpoint) | The endpoint where report will be sent | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_event_bridge_data"></a> [event\_bridge\_data](#output\_event\_bridge\_data) | n/a |
| <a name="output_lambda_function_data"></a> [lambda\_function\_data](#output\_lambda\_function\_data) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
