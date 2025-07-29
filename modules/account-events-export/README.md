# The module allows to create aws services event capture and streaming to an external webhook service

## basic example
```terraform
module "this" {
  source  = "dasmeta/account/aws//modules/account-events-export"
  version = "1.3.6"

  webhook_endpoint = "https://example-webhook-endpoint.com"
}
```
## The webhook endpoint receives POST requests in following form(this example os from "aws.rds" service auto scale event)
```json
{
  "event": {
    "received_time": "2025-07-11T13:21:00.793Z",
    "event_source": "aws.rds",
    "event_type": "RDS DB Proxy Event",
    "event_time": "2025-07-11T13:17:53Z",
    "region": "eu-central-1",
    "detail": {
      "EventCategories": [
        "configuration change"
      ],
      "SourceType": "DB_PROXY",
      "SourceArn": "arn:aws:rds:eu-central-1:xxxxxxxxxxxxx:db-proxy:prx-yyyyyyyyyyyyyyyy",
      "Date": "2025-07-11T13:17:53.925Z",
      "Message": "RDS detected deletion of DB instance application-autoscaling-000000-00000-0000-0000-00000000 and automatically removed it from target group default of DB proxy test-account-aurora-cluster.",
      "SourceIdentifier": "test-account-aurora-cluster",
      "EventID": "RDS-EVENT-0214",
      "Tags": {
        "Account": "test-account",
        "ManagedBy": "terraform",
        "TerraformModuleVersion": "1.4.0",
        "AppliedFrom": "terraform-cloud",
        "TerraformCloudWorkspace": "1-environments_-1_rds-proxy",
        "ManageLevel": "account",
        "TerraformModuleSource": "dasmeta/rds/aws//modules/proxy"
      }
    },
    "raw_event": {
      "version": "0",
      "id": "82042e12-6d0a-8930-80f6-2e0096aa2e15",
      "detail-type": "RDS DB Proxy Event",
      "source": "aws.rds",
      "account": "xxxxxxxxxxxxx",
      "time": "2025-07-11T13:17:53Z",
      "region": "eu-central-1",
      "resources": [
        "arn:aws:rds:eu-central-1:xxxxxxxxxxxxx:db-proxy:prx-yyyyyyyyyyyyyyyy"
      ],
      "detail": {
        "EventCategories": [
          "configuration change"
        ],
        "SourceType": "DB_PROXY",
        "SourceArn": "arn:aws:rds:eu-central-1:xxxxxxxxxxxxx:db-proxy:prx-yyyyyyyyyyyyyyyy",
        "Date": "2025-07-11T13:17:53.925Z",
        "Message": "RDS detected deletion of DB instance application-autoscaling-000000-00000-0000-0000-00000000 and automatically removed it from target group default of DB proxy test-account-aurora-cluster.",
        "SourceIdentifier": "test-account-aurora-cluster",
        "EventID": "RDS-EVENT-0214",
        "Tags": {
          "Account": "test-account",
          "ManagedBy": "terraform",
          "TerraformModuleVersion": "1.4.0",
          "AppliedFrom": "terraform-cloud",
          "TerraformCloudWorkspace": "1-environments_-1_rds-proxy",
          "ManageLevel": "account",
          "TerraformModuleSource": "dasmeta/rds/aws//modules/proxy"
        }
      }
    }
  }
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
| <a name="module_lambda_function"></a> [lambda\_function](#module\_lambda\_function) | terraform-aws-modules/lambda/aws | 7.21.1 |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_event_bridge_bus"></a> [event\_bridge\_bus](#input\_event\_bridge\_bus) | Event bridge cronjob/scheduler configs | <pre>object({<br/>    create              = optional(bool, false)                                                                                                                                                                                                                                                                                                                                                                                                                                                # whether to create event bridge bus, there is default bus name 'default' what can be used without creating separate one<br/>    name                = optional(string, "default")                                                                                                                                                                                                                                                                                                                                                                                                                                          # the bus name, default bus pre-exist and we can use it<br/>    rule_pattern_source = optional(list(string), ["aws.route53", "aws.cloudfront", "aws.acm", "aws.cloudwatch", "aws.amplify", "aws.health", "aws.securityhub", "aws.budgets", "aws.secretsmanager", "aws.events", "aws.autoscaling", "aws.elasticache", "aws.elb", "aws.amazonmq", "aws.ec2", "aws.s3", "aws.rds", "aws.apigateway", "aws.waf", "aws.waf-regional", "aws.savingsplans", "aws.opensearchservice", "aws.sqs", "aws.lambda", "aws.iam", "aws.vpc", "custom.test", "aws.lambda"]) # The list of aws services to capture and stream/export event, for available event sources check https://docs.aws.amazon.com/eventbridge/latest/ref/events.html<br/>  })</pre> | `{}` | no |
| <a name="input_logs_retention_in_days"></a> [logs\_retention\_in\_days](#input\_logs\_retention\_in\_days) | Lambda function logs retention days | `number` | `7` | no |
| <a name="input_name"></a> [name](#input\_name) | The naming to use to create resource | `string` | `"account-events-export"` | no |
| <a name="input_webhook_endpoint"></a> [webhook\_endpoint](#input\_webhook\_endpoint) | The endpoint where report will be sent | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_event_bridge_data"></a> [event\_bridge\_data](#output\_event\_bridge\_data) | n/a |
| <a name="output_lambda_function_data"></a> [lambda\_function\_data](#output\_lambda\_function\_data) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
