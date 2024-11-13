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
| <a name="module_buckets"></a> [buckets](#module\_buckets) | dasmeta/modules/aws//modules/s3 | 2.1.2 |
| <a name="module_cloudtrail"></a> [cloudtrail](#module\_cloudtrail) | dasmeta/modules/aws//modules/cloudtrail/ | 2.18.0 |
| <a name="module_cloudwatch_alarm_actions"></a> [cloudwatch\_alarm\_actions](#module\_cloudwatch\_alarm\_actions) | git::https://github.com/dasmeta/terraform-aws-monitoring.git//modules/cloudwatch-alarm-actions | DMVP-5761 |
| <a name="module_cloudwatch_alarm_actions_virginia"></a> [cloudwatch\_alarm\_actions\_virginia](#module\_cloudwatch\_alarm\_actions\_virginia) | git::https://github.com/dasmeta/terraform-aws-monitoring.git//modules/cloudwatch-alarm-actions | DMVP-5761 |
| <a name="module_enforce_mfa"></a> [enforce\_mfa](#module\_enforce\_mfa) | terraform-module/enforce-mfa/aws | ~> 1.0 |
| <a name="module_enforce_mfa_group"></a> [enforce\_mfa\_group](#module\_enforce\_mfa\_group) | terraform-aws-modules/iam/aws//modules/iam-group-with-policies | 5.47.1 |
| <a name="module_groups"></a> [groups](#module\_groups) | terraform-aws-modules/iam/aws//modules/iam-group-with-policies | 5.47.1 |
| <a name="module_monitoring_billing"></a> [monitoring\_billing](#module\_monitoring\_billing) | dasmeta/monitoring/aws//modules/billing | 1.19.3 |
| <a name="module_monitoring_security_hub"></a> [monitoring\_security\_hub](#module\_monitoring\_security\_hub) | dasmeta/monitoring/aws//modules/aws-security-hub-opsgenie | 1.5.2 |
| <a name="module_password_policy"></a> [password\_policy](#module\_password\_policy) | dasmeta/modules/aws//modules/iam-account-password-policy | 2.18.0 |
| <a name="module_secrets"></a> [secrets](#module\_secrets) | dasmeta/modules/aws//modules/secret | 2.18.0 |
| <a name="module_users"></a> [users](#module\_users) | dasmeta/modules/aws//modules/aws-iam-user | 2.1.2 |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_actions"></a> [alarm\_actions](#input\_alarm\_actions) | Whether to enable/create regional(TODO: add also us-east-1 region alarm also for health-check alarms) SNS topic/subscribers | <pre>object({<br>    enabled                  = optional(bool, false)<br>    topic_name               = optional(string, "account-alarms-handling")<br>    enable_dead_letter_queue = optional(bool, false)<br>    email_addresses          = optional(list(string), [])<br>    phone_numbers            = optional(list(string), [])<br>    web_endpoints            = optional(list(string), [])<br>    teams_webhooks           = optional(list(string), [])<br>    slack_webhooks = optional(list(object({<br>      hook_url = string<br>      channel  = string<br>      username = string<br>    })), [])<br>    servicenow_webhooks = optional(list(object({<br>      domain = string<br>      path   = string<br>      user   = string<br>      pass   = string<br>    })), [])<br>    billing_alarm = optional(object({ # Allows to setup billing (cost exceeded) alarm for aws account, NOTE: you have to at first enable 'alarm_actions' and then enable this<br>      enabled                = optional(bool, false)<br>      name                   = optional(string, "Account-Monthly-Budget")<br>      limit_amount           = optional(string, "200")<br>      limit_unit             = optional(string, "USD")<br>      time_unit              = optional(string, "MONTHLY")<br>      time_period_start      = optional(string, "2022-01-01_00:00")<br>      time_period_end        = optional(string, "2087-06-15_00:00")<br>      thresholds             = optional(list(string), ["40", "60", "80", "90", "100", "110"])<br>      threshold_type         = optional(string, "PERCENTAGE")<br>      comparison_operator    = optional(string, "GREATER_THAN")<br>      notification_type      = optional(string, "ACTUAL")<br>      notify_email_addresses = optional(list(string), [])<br>    }), { enabled : false })<br>    security_hub_alarms = optional(object({ # Allows to enable security hub for aws account, create separate sns topic for it and setup opsgenie subscriber.<br>      enabled                                = optional(bool, false)<br>      opsgenie_webhook                       = optional(string, null)<br>      securityhub_action_target_name         = optional(string, "Send-to-SNS")<br>      sns_topic_name                         = optional(string, "Send-to-Opsgenie")<br>      protocol                               = optional(string, "https")<br>      link_mode                              = optional(string, "ALL_REGIONS")<br>      enable_security_hub                    = optional(bool, true) # not confuse with enabled option, this one is for setting "false" in case when aws security hub service already enabled<br>      enable_security_hub_finding_aggregator = optional(bool, true)<br>    }), { enabled : false })<br>  })</pre> | <pre>{<br>  "billing_alarm": {<br>    "enabled": false<br>  },<br>  "enabled": false,<br>  "security_hub_alarms": {<br>    "enabled": false<br>  }<br>}</pre> | no |
| <a name="input_alarm_actions_virginia"></a> [alarm\_actions\_virginia](#input\_alarm\_actions\_virginia) | Whether to enable/create regional(TODO: add also us-east-1 region alarm also for health-check alarms) SNS topic/subscribers | <pre>object({<br>    enabled                  = optional(bool, false)<br>    topic_name               = optional(string, "account-alarms-handling")<br>    enable_dead_letter_queue = optional(bool, false)<br>    email_addresses          = optional(list(string), [])<br>    phone_numbers            = optional(list(string), [])<br>    web_endpoints            = optional(list(string), [])<br>    teams_webhooks           = optional(list(string), [])<br>    slack_webhooks = optional(list(object({<br>      hook_url = string<br>      channel  = string<br>      username = string<br>    })), [])<br>    servicenow_webhooks = optional(list(object({<br>      domain = string<br>      path   = string<br>      user   = string<br>      pass   = string<br>    })), [])<br>    billing_alarm = optional(object({ # Allows to setup billing (cost exceeded) alarm for aws account, NOTE: you have to at first enable 'alarm_actions' and then enable this<br>      enabled                = optional(bool, false)<br>      name                   = optional(string, "Account-Monthly-Budget")<br>      limit_amount           = optional(string, "200")<br>      limit_unit             = optional(string, "USD")<br>      time_unit              = optional(string, "MONTHLY")<br>      time_period_start      = optional(string, "2022-01-01_00:00")<br>      time_period_end        = optional(string, "2087-06-15_00:00")<br>      threshold              = optional(string, "200")<br>      threshold_type         = optional(string, "PERCENTAGE")<br>      comparison_operator    = optional(string, "GREATER_THAN")<br>      notification_type      = optional(string, "ACTUAL")<br>      notify_email_addresses = optional(list(string), [])<br>    }), { enabled : false })<br>    security_hub_alarms = optional(object({ # Allows to enable security hub for aws account, create separate sns topic for it and setup opsgenie subscriber.<br>      enabled                                = optional(bool, false)<br>      opsgenie_webhook                       = optional(string, null)<br>      securityhub_action_target_name         = optional(string, "Send-to-SNS")<br>      sns_topic_name                         = optional(string, "Send-to-Opsgenie")<br>      protocol                               = optional(string, "https")<br>      link_mode                              = optional(string, "ALL_REGIONS")<br>      enable_security_hub                    = optional(bool, true) # not confuse with enabled option, this one is for setting "false" in case when aws security hub service already enabled<br>      enable_security_hub_finding_aggregator = optional(bool, true)<br>    }), { enabled : false })<br>  })</pre> | <pre>{<br>  "billing_alarm": {<br>    "enabled": false<br>  },<br>  "enabled": false,<br>  "security_hub_alarms": {<br>    "enabled": false<br>  }<br>}</pre> | no |
| <a name="input_buckets"></a> [buckets](#input\_buckets) | List of buckets | <pre>list(object({<br>    name                    = string<br>    acl                     = optional(string, null)<br>    ignore_public_acls      = optional(bool, true)<br>    restrict_public_buckets = optional(bool, true)<br>    block_public_acls       = optional(bool, true)<br>    block_public_policy     = optional(bool, true)<br>    versioning              = optional(map(string), { enabled = true })<br>    website                 = optional(map(string), {})<br>    create_index_html       = optional(bool, false)<br>    create_iam_user         = optional(bool, false)<br>    bucket_files            = optional(object({ path = string }), { path = "" })<br>  }))</pre> | `[]` | no |
| <a name="input_cloudtrail"></a> [cloudtrail](#input\_cloudtrail) | Cloudtrail configuration | <pre>object({<br>    enabled                          = optional(bool, false)<br>    enable_cloudwatch_logs           = optional(bool, false)<br>    name                             = optional(string, "audit") # Name of CloudTrail<br>    bucket_name                      = optional(string, "")      # Whether to create new fresh bucket or use existing one, if set non empty it will use existing one with provided name<br>    include_global_service_events    = optional(bool, true)      # Specifies whether the trail is publishing events from global services such as IAM to the log files<br>    enable_log_file_validation       = optional(bool, true)      # Specifies whether log file integrity validation is enabled. Creates signed digest for validated contents of logs<br>    is_organization_trail            = optional(bool, true)      # The trail is an AWS Organizations trail<br>    is_multi_region_trail            = optional(bool, true)      # Specifies whether the trail is created in the current region or in all regions<br>    cloud_watch_logs_group_arn       = optional(string, "")      # Specifies a log group name using an Amazon Resource Name (ARN), that represents the log group to which CloudTrail logs will be delivered<br>    cloud_watch_logs_role_arn        = optional(string, "")      # Specifies the role for the CloudWatch Logs endpoint to assume to write to a user’s log group<br>    cloud_watch_logs_group_retention = optional(number, 90)      # Specifies the number of days you want to retain log events in the specified log group.<br>    enable_logging                   = optional(bool, true)      # Enable logging for the trail<br>    sns_topic_name                   = optional(string, null)    # Specifies the name of the Amazon SNS topic defined for notification of log file delivery<br>    event_selector = optional(list(object({                      # Specifies an event selector for enabling data event logging. See: https://www.terraform.io/docs/providers/aws/r/cloudtrail.html for details on this variable<br>      include_management_events = bool<br>      read_write_type           = string<br><br>      data_resource = list(object({<br>        type   = string<br>        values = list(string)<br>      }))<br>    })), [])<br>    insight_selectors = optional(list(string), [])<br>    alerts_events     = optional(list(string), ["iam-user-creation-or-deletion"]) # Some possible values are: iam-user-creation-or-deletion, iam-role-creation-or-deletion, iam-policy-changes, s3-creation-or-deletion, root-account-usage, elastic-ip-association-and-disassociation and etc.<br>  })</pre> | <pre>{<br>  "enabled": false<br>}</pre> | no |
| <a name="input_create_cloudwatch_log_role"></a> [create\_cloudwatch\_log\_role](#input\_create\_cloudwatch\_log\_role) | This is an account level configuration which creates IAM role with policy allowing cloudwatch sync/push logs into cloudwatch | `bool` | `false` | no |
| <a name="input_enforce_mfa"></a> [enforce\_mfa](#input\_enforce\_mfa) | MFA related configs, set the name for enforce MFA IAM user group value to null if you want this group to not be created | <pre>object({<br>    enabled                           = optional(bool, false) # whether to create enforce mfa iam group<br>    group_name                        = optional(string, "enforce-mfa")<br>    policy_name                       = optional(string, "mfa-enforce-policy")<br>    manage_own_signing_certificates   = optional(bool, true)<br>    manage_own_ssh_public_keys        = optional(bool, true)<br>    manage_own_git_credentials        = optional(bool, true)<br>    attach_iam_self_management_policy = optional(bool, false)<br>  })</pre> | `{}` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | n/a | <pre>list(object({<br>    name                              = string<br>    custom_group_policies             = optional(list(map(string)), [])<br>    custom_group_policy_arns          = optional(list(string), [])<br>    attach_iam_self_management_policy = optional(bool, false)<br>    users                             = optional(list(string), [])<br>  }))</pre> | `[]` | no |
| <a name="input_password_policy"></a> [password\_policy](#input\_password\_policy) | Allows to create/set aws iam users password policy for better security | <pre>object({<br>    enabled                        = optional(bool, false)<br>    allow_users_to_change_password = optional(bool, true)<br>    minimum_password_length        = optional(number, 10)<br>    require_lowercase_characters   = optional(bool, true)<br>    require_numbers                = optional(bool, true)<br>    require_symbols                = optional(bool, true)<br>    require_uppercase_characters   = optional(bool, true)<br>    max_password_age               = optional(number, 90)<br>    hard_expiry                    = optional(bool, false)<br>    password_reuse_prevention      = optional(number, 3)<br>  })</pre> | `{}` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Allows to create account level aws secret manager secret for storing global/shared secrets, which supposed can be used by all services/apps/environments | <pre>object({<br>    enabled                 = optional(bool, false)<br>    name                    = optional(string, "account")<br>    value                   = optional(any, null)<br>    recovery_window_in_days = optional(number, 30)<br>  })</pre> | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users | <pre>list(object({<br>    username          = string<br>    policy_attachment = optional(list(string), [])<br>    enforce_mfa       = optional(bool, true) # whether user should be placed into enforce mfa group, note that the enforce_mfa.enabled should be set to true to have this applied<br>    create            = optional(bool, true) # whether the user should be created or not, so that existing iam user can be linked/placed into a group<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_users"></a> [users](#output\_users) | created users data |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
