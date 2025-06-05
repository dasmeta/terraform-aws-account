variable "users" {
  type = list(object({
    username          = string
    policy_attachment = optional(list(string), [])
    enforce_mfa       = optional(bool, true) # whether user should be placed into enforce mfa group, note that the enforce_mfa.enabled should be set to true to have this applied
    create            = optional(bool, true) # whether the user should be created or not, so that existing iam user can be linked/placed into a group
  }))
  default     = []
  description = "List of users"
}

variable "groups" {
  type = list(object({
    name                              = string
    custom_group_policies             = optional(list(map(string)), [])
    custom_group_policy_arns          = optional(list(string), [])
    attach_iam_self_management_policy = optional(bool, false)
    users                             = optional(list(string), [])
  }))
  default = []
}

variable "enforce_mfa" {
  type = object({
    enabled                           = optional(bool, true) # whether to create enforce mfa iam group
    group_name                        = optional(string, "enforce-mfa")
    policy_name                       = optional(string, "mfa-enforce-policy")
    manage_own_signing_certificates   = optional(bool, true)
    manage_own_ssh_public_keys        = optional(bool, true)
    manage_own_git_credentials        = optional(bool, true)
    attach_iam_self_management_policy = optional(bool, false)
  })
  default     = {}
  description = "MFA related configs, set the name for enforce MFA IAM user group value to null if you want this group to not be created"
}

variable "buckets" {
  type = list(object({
    name                    = string
    acl                     = optional(string, "private") # the bucket acl which cant be null in new s3 module
    ignore_public_acls      = optional(bool, true)
    restrict_public_buckets = optional(bool, true)
    block_public_acls       = optional(bool, true)
    block_public_policy     = optional(bool, true)
    versioning              = optional(map(string), { enabled = true })
    website                 = optional(map(string), {})
    create_index_html       = optional(bool, false)
    create_iam_user         = optional(bool, false)
    bucket_files            = optional(object({ path = string }), { path = "" })
  }))
  default     = []
  description = "List of buckets"
}

variable "cloudtrail" {
  type = object({
    enabled                          = optional(bool, false)
    enable_cloudwatch_logs           = optional(bool, false)
    name                             = optional(string, "audit") # Name of CloudTrail
    bucket_name                      = optional(string, "")      # Whether to create new fresh bucket or use existing one, if set non empty it will use existing one with provided name
    create_s3_bucket                 = optional(bool, true)
    include_global_service_events    = optional(bool, true)   # Specifies whether the trail is publishing events from global services such as IAM to the log files
    enable_log_file_validation       = optional(bool, true)   # Specifies whether log file integrity validation is enabled. Creates signed digest for validated contents of logs
    is_organization_trail            = optional(bool, true)   # The trail is an AWS Organizations trail
    is_multi_region_trail            = optional(bool, true)   # Specifies whether the trail is created in the current region or in all regions
    cloud_watch_logs_group_arn       = optional(string, "")   # Specifies a log group name using an Amazon Resource Name (ARN), that represents the log group to which CloudTrail logs will be delivered
    cloud_watch_logs_role_arn        = optional(string, "")   # Specifies the role for the CloudWatch Logs endpoint to assume to write to a user’s log group
    cloud_watch_logs_group_retention = optional(number, 90)   # Specifies the number of days you want to retain log events in the specified log group.
    enable_logging                   = optional(bool, true)   # Enable logging for the trail
    sns_topic_name                   = optional(string, null) # Specifies the name of the Amazon SNS topic defined for notification of log file delivery
    event_selector = optional(list(object({                   # Specifies an event selector for enabling data event logging. See: https://www.terraform.io/docs/providers/aws/r/cloudtrail.html for details on this variable
      include_management_events = bool
      read_write_type           = string

      data_resource = list(object({
        type   = string
        values = list(string)
      }))
    })), [])
    insight_selectors = optional(list(string), [])
    alerts_events     = optional(list(string), ["iam-user-creation-or-deletion"]) # Some possible values are: iam-user-creation-or-deletion, iam-role-creation-or-deletion, iam-policy-changes, s3-creation-or-deletion, root-account-usage, elastic-ip-association-and-disassociation and etc.
  })
  default     = { enabled : false }
  description = "Cloudtrail configuration"
}

variable "alarm_actions" {
  type = object({
    enabled                  = optional(bool, false)
    topic_name               = optional(string, "account-alarms-handling")
    enable_dead_letter_queue = optional(bool, false)
    email_addresses          = optional(list(string), [])
    phone_numbers            = optional(list(string), [])
    web_endpoints            = optional(list(string), [])
    teams_webhooks           = optional(list(string), [])
    log_group_retention_days = optional(number, 7)
    slack_webhooks = optional(list(object({
      hook_url = string
      channel  = string
      username = string
    })), [])
    servicenow_webhooks = optional(list(object({
      domain = string
      path   = string
      user   = string
      pass   = string
    })), [])
    billing_alarm = optional(object({ # Allows to setup billing (cost exceeded) alarm for aws account, NOTE: you have to at first enable 'alarm_actions' and then enable this
      enabled                = optional(bool, false)
      name                   = optional(string, "Account-Monthly-Budget")
      limit_amount           = optional(string, "200")
      limit_unit             = optional(string, "USD")
      time_unit              = optional(string, "MONTHLY")
      time_period_start      = optional(string, "2022-01-01_00:00")
      time_period_end        = optional(string, "2087-06-15_00:00")
      thresholds             = optional(list(string), ["40", "60", "80", "90", "100", "110"])
      threshold_type         = optional(string, "PERCENTAGE")
      comparison_operator    = optional(string, "GREATER_THAN")
      notification_type      = optional(string, "ACTUAL")
      notify_email_addresses = optional(list(string), [])
    }), { enabled : false })
    security_hub_alarms = optional(object({ # Allows to enable security hub for aws account, create separate sns topic for it and setup opsgenie subscriber.
      name                                   = optional(string, "account-security-hub-bridge")
      enabled                                = optional(bool, false)
      opsgenie_webhook                       = optional(string, null)
      enable_security_hub                    = optional(bool, true) # not confuse with enabled option, this one is for setting "false" in case when aws security hub service already enabled
      enable_security_hub_finding_aggregator = optional(bool, true)
    }), { enabled : false })
  })

  default     = { enabled = false, billing_alarm = { enabled : false }, security_hub_alarms = { enabled : false } }
  description = "Whether to enable/create regional(TODO: add also us-east-1 region alarm also for health-check alarms) SNS topic/subscribers"
}

variable "alarm_actions_virginia" {
  type = object({
    enabled                  = optional(bool, false)
    topic_name               = optional(string, "account-alarms-handling")
    enable_dead_letter_queue = optional(bool, false)
    email_addresses          = optional(list(string), [])
    phone_numbers            = optional(list(string), [])
    web_endpoints            = optional(list(string), [])
    teams_webhooks           = optional(list(string), [])
    log_group_retention_days = optional(number, 7)
    slack_webhooks = optional(list(object({
      hook_url = string
      channel  = string
      username = string
    })), [])
    servicenow_webhooks = optional(list(object({
      domain = string
      path   = string
      user   = string
      pass   = string
    })), [])
    billing_alarm = optional(object({ # Allows to setup billing (cost exceeded) alarm for aws account, NOTE: you have to at first enable 'alarm_actions' and then enable this
      enabled                = optional(bool, false)
      name                   = optional(string, "Account-Monthly-Budget")
      limit_amount           = optional(string, "200")
      limit_unit             = optional(string, "USD")
      time_unit              = optional(string, "MONTHLY")
      time_period_start      = optional(string, "2022-01-01_00:00")
      time_period_end        = optional(string, "2087-06-15_00:00")
      threshold              = optional(string, "200")
      threshold_type         = optional(string, "PERCENTAGE")
      comparison_operator    = optional(string, "GREATER_THAN")
      notification_type      = optional(string, "ACTUAL")
      notify_email_addresses = optional(list(string), [])
    }), { enabled : false })
    security_hub_alarms = optional(object({ # Allows to enable security hub for aws account, create separate sns topic for it and setup opsgenie subscriber.
      enabled                                = optional(bool, false)
      opsgenie_webhook                       = optional(string, null)
      securityhub_action_target_name         = optional(string, "Send-to-SNS")
      sns_topic_name                         = optional(string, "Send-to-Opsgenie")
      protocol                               = optional(string, "https")
      link_mode                              = optional(string, "ALL_REGIONS")
      enable_security_hub                    = optional(bool, true) # not confuse with enabled option, this one is for setting "false" in case when aws security hub service already enabled
      enable_security_hub_finding_aggregator = optional(bool, true)
    }), { enabled : false })
  })

  default     = { enabled = false, billing_alarm = { enabled : false }, security_hub_alarms = { enabled : false } }
  description = "Whether to enable/create regional(TODO: add also us-east-1 region alarm also for health-check alarms) SNS topic/subscribers"
}

variable "create_cloudwatch_log_role" {
  type        = bool
  default     = false
  description = "This is an account level configuration which creates IAM role with policy allowing cloudwatch sync/push logs into cloudwatch"
}

variable "secrets" {
  type = object({
    enabled                 = optional(bool, false)
    name                    = optional(string, "account")
    value                   = optional(any, null)
    recovery_window_in_days = optional(number, 30)
  })
  default     = {}
  description = "Allows to create account level aws secret manager secret for storing global/shared secrets, which supposed can be used by all services/apps/environments"
}


variable "password_policy" {
  type = object({
    enabled                        = optional(bool, false)
    allow_users_to_change_password = optional(bool, true)
    minimum_password_length        = optional(number, 10)
    require_lowercase_characters   = optional(bool, true)
    require_numbers                = optional(bool, true)
    require_symbols                = optional(bool, true)
    require_uppercase_characters   = optional(bool, true)
    max_password_age               = optional(number, 90)
    hard_expiry                    = optional(bool, false)
    password_reuse_prevention      = optional(number, 3)
  })
  default     = {}
  description = "Allows to create/set aws iam users password policy for better security"
}

variable "cost_report_export" {
  type = object({
    enabled                = optional(bool, false)
    webhook_endpoint       = optional(string, null)                  # required if enabled, this is endpoint to which the report will be sent via POST request
    name                   = optional(string, "account-cost-report") # the identifier part used for lambda function and event bridge cronjob schedule namings
    logs_retention_in_days = optional(number, 7)                     # the retention days of logs in cloudwatch for lambda function which sent cost data to webhook endpoint
    eventBridgeBus = optional(object({
      create   = optional(bool, false)                 # whether to create event bridge bus, there is default bus name 'default' what can be used without creating separate one
      name     = optional(string, "default")           # the bus name, default bus pre-exist and we can use it
      schedule = optional(string, "cron(0 5 * * ? *)") # schedule to collect cost data, by default we use once a day at 05:00 AM UTC schedule to collect previous day data 'cron(0 5 * * ? *)'
      timezone = optional(string, "Europe/London")
    }), {})
  })
  default     = {}
  description = "Allows to configure and get cost report of previous day to specified `webhook_endpoint`, NOTE: webhook_endpoint is required when enabling this"
}
