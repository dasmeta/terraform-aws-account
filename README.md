# terraform-aws-account
## this module allows to configure aws account level resources which are not part to specific environment/application and are global impact on aws

## basic example
```hcl
module "account" {
  source  = "dasmeta/account/aws"
  version = "x.y.z"

  create_cloudwatch_log_role = true
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_buckets"></a> [buckets](#module\_buckets) | dasmeta/modules/aws//modules/s3 | 1.5.2 |
| <a name="module_cloudtrail"></a> [cloudtrail](#module\_cloudtrail) | dasmeta/modules/aws//modules/cloudtrail/ | 1.8.1 |
| <a name="module_cloudwatch_alarm_actions"></a> [cloudwatch\_alarm\_actions](#module\_cloudwatch\_alarm\_actions) | dasmeta/monitoring/aws//modules/cloudwatch-alarm-actions | 1.3.8 |
| <a name="module_enforce_mfa"></a> [enforce\_mfa](#module\_enforce\_mfa) | terraform-module/enforce-mfa/aws | ~> 1.0 |
| <a name="module_enforce_mfa_group"></a> [enforce\_mfa\_group](#module\_enforce\_mfa\_group) | terraform-aws-modules/iam/aws//modules/iam-group-with-policies | 5.9.2 |
| <a name="module_groups"></a> [groups](#module\_groups) | terraform-aws-modules/iam/aws//modules/iam-group-with-policies | 5.9.2 |
| <a name="module_monitoring_billing"></a> [monitoring\_billing](#module\_monitoring\_billing) | dasmeta/monitoring/aws//modules/billing | 1.3.9 |
| <a name="module_users"></a> [users](#module\_users) | dasmeta/modules/aws//modules/aws-iam-user | 1.5.2 |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_actions"></a> [alarm\_actions](#input\_alarm\_actions) | Whether to enable/create regional(TODO: add also us-east-1 region alarm also for health-check alarms) SNS topic/subscribers | <pre>object({<br>    enabled         = optional(bool, false)<br>    topic_name      = optional(string, "account-alarms-handling")<br>    email_addresses = optional(list(string), [])<br>    phone_numbers   = optional(list(string), [])<br>    web_endpoints   = optional(list(string), [])<br>    slack_webhooks = optional(list(object({<br>      hook_url = string<br>      channel  = string<br>      username = string<br>    })), [])<br>    servicenow_webhooks = optional(list(object({<br>      domain = string<br>      path   = string<br>      user   = string<br>      pass   = string<br>    })), [])<br>    billing_alarm = optional(object({ # Allows to setup billing (cost exceeded) alarm for aws account, NOTE: you have to at first enable 'alarm_actions' and then enable this<br>      enabled             = optional(bool, false)<br>      name                = optional(string, "Account-Monthly-Budget")<br>      limit_amount        = optional(string, "200")<br>      limit_unit          = optional(string, "USD")<br>      time_unit           = optional(string, "MONTHLY")<br>      threshold           = optional(string, "200")<br>      threshold_type      = optional(string, "PERCENTAGE")<br>      comparison_operator = optional(string, "GREATER_THAN")<br><br>      sns_subscription = optional(object({<br>        sns_subscription_email_address_list    = optional(list(string), [])<br>        sns_subscription_phone_number_list     = optional(list(string), [])<br>        sms_message_body                       = optional(string, "")<br>        slack_webhook_url                      = optional(string, "")<br>        slack_channel                          = optional(string, "")<br>        slack_username                         = optional(string, "")<br>        cloudwatch_log_group_retention_in_days = optional(number, 7)<br>        opsgenie_endpoint                      = optional(list(string), [])<br>      }), null)<br>    }), { enabled : false })<br>  })</pre> | <pre>{<br>  "billing_alarm": {<br>    "enabled": false<br>  },<br>  "enabled": false<br>}</pre> | no |
| <a name="input_buckets"></a> [buckets](#input\_buckets) | List of buckets | <pre>list(object({<br>    name                    = string<br>    acl                     = optional(string, null)<br>    ignore_public_acls      = optional(bool, true)<br>    restrict_public_buckets = optional(bool, true)<br>    block_public_acls       = optional(bool, true)<br>    block_public_policy     = optional(bool, true)<br>    versioning              = optional(map(string), { enabled = true })<br>    website                 = optional(map(string), {})<br>    create_index_html       = optional(bool, false)<br>    create_iam_user         = optional(bool, false)<br>    bucket_files            = optional(object({ path = string }), { path = "" })<br>  }))</pre> | `[]` | no |
| <a name="input_cloudtrail"></a> [cloudtrail](#input\_cloudtrail) | Cloudtrail configuration | <pre>object({<br>    enabled                       = optional(bool, false)<br>    enable_cloudwatch_logs        = optional(bool, false)<br>    name                          = optional(string, "audit") # Name of CloudTrail<br>    bucket_name                   = optional(string, "")      # Whether to create new fresh bucket or use existing one, if set non empty it will use existing one with provided name<br>    include_global_service_events = optional(bool, true)      # Specifies whether the trail is publishing events from global services such as IAM to the log files<br>    enable_log_file_validation    = optional(bool, true)      # Specifies whether log file integrity validation is enabled. Creates signed digest for validated contents of logs<br>    is_organization_trail         = optional(bool, true)      # The trail is an AWS Organizations trail<br>    is_multi_region_trail         = optional(bool, true)      # Specifies whether the trail is created in the current region or in all regions<br>    cloud_watch_logs_group_arn    = optional(string, "")      # Specifies a log group name using an Amazon Resource Name (ARN), that represents the log group to which CloudTrail logs will be delivered<br>    cloud_watch_logs_role_arn     = optional(string, "")      # Specifies the role for the CloudWatch Logs endpoint to assume to write to a user’s log group<br>    enable_logging                = optional(bool, true)      # Enable logging for the trail<br>    sns_topic_name                = optional(string, null)    # Specifies the name of the Amazon SNS topic defined for notification of log file delivery<br>    event_selector = optional(list(object({                   # Specifies an event selector for enabling data event logging. See: https://www.terraform.io/docs/providers/aws/r/cloudtrail.html for details on this variable<br>      include_management_events = bool<br>      read_write_type           = string<br><br>      data_resource = list(object({<br>        type   = string<br>        values = list(string)<br>      }))<br>    })), [])<br>    insight_selectors = optional(list(string), [])<br>    alerts_events     = optional(list(string), ["iam-user-creation-or-deletion"]) # Some possible values are: iam-user-creation-or-deletion, iam-role-creation-or-deletion, iam-policy-changes, s3-creation-or-deletion, root-account-usage, elastic-ip-association-and-disassociation and etc.<br>  })</pre> | <pre>{<br>  "enabled": false<br>}</pre> | no |
| <a name="input_create_cloudwatch_log_role"></a> [create\_cloudwatch\_log\_role](#input\_create\_cloudwatch\_log\_role) | This is an account level configuration which creates IAM role with policy allowing cloudwatch sync/push logs into cloudwatch | `bool` | `false` | no |
| <a name="input_enforce_mfa"></a> [enforce\_mfa](#input\_enforce\_mfa) | MFA related configs, set the name for enforce MFA IAM user group value to null if you want this group to not be created | <pre>object({<br>    group_name                        = optional(string, "enforce-mfa")<br>    policy_name                       = optional(string, "mfa-enforce-policy")<br>    manage_own_signing_certificates   = optional(bool, true)<br>    manage_own_ssh_public_keys        = optional(bool, true)<br>    manage_own_git_credentials        = optional(bool, true)<br>    attach_iam_self_management_policy = optional(bool, false)<br>  })</pre> | `{}` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | n/a | <pre>list(object({<br>    name                              = string<br>    custom_group_policies             = optional(list(map(string)), [])<br>    custom_group_policy_arns          = optional(list(string), [])<br>    attach_iam_self_management_policy = optional(bool, false)<br>    users                             = optional(list(string), [])<br>  }))</pre> | `[]` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users | <pre>list(object({<br>    username          = string<br>    policy_attachment = optional(list(string), [])<br>    enforce_mfa       = optional(bool, true)<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_users"></a> [users](#output\_users) | created users data |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
