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
    enabled                  = optional(bool, false)                       # Enable/disable alarm actions module for account-level notifications
    topic_name               = optional(string, "account-alarms-handling") # SNS topic name for account alarms. If empty, defaults to "account-alarms-handling"
    enable_dead_letter_queue = optional(bool, false)                       # Whether to enable dead letter queue (SQS) for failed Lambda invocations
    email_addresses          = optional(list(string), [])                  # List of email addresses to receive alarm notifications
    phone_numbers            = optional(list(string), [])                  # List of international formatted phone numbers (e.g., "+1234567890") to receive SMS notifications
    web_endpoints            = optional(list(string), [])                  # List of webhook endpoints (e.g., Opsgenie, PagerDuty) to receive HTTP POST notifications
    lambda_arns              = optional(list(string), [])                  # List of Lambda function ARNs to invoke when alarms are triggered. Note: Lambda functions must be in the same region as the SNS topic
    teams_webhooks           = optional(list(string), [])                  # List of Microsoft Teams webhook URLs for sending notifications to Teams channels
    log_group_retention_days = optional(number, 7)                         # Number of days to retain CloudWatch Logs for Lambda functions (default: 7 days)
    slack_webhooks = optional(list(object({                                # List of Slack webhook configurations for sending notifications to Slack channels
      hook_url = string                                                    # Slack webhook URL
      channel  = string                                                    # Slack channel name (e.g., "#alerts")
      username = string                                                    # Bot username for Slack messages
    })), [])
    servicenow_webhooks = optional(list(object({ # List of ServiceNow webhook configurations for creating incidents in ServiceNow
      domain = string                            # ServiceNow instance domain (e.g., "yourcompany.service-now.com")
      path   = string                            # API endpoint path
      user   = string                            # ServiceNow username
      pass   = string                            # ServiceNow password or API token
    })), [])
    billing_alarm = optional(object({                                                         # Allows to setup billing (cost exceeded) alarm for aws account, NOTE: you have to at first enable 'alarm_actions' and then enable this
      enabled                = optional(bool, false)                                          # Enable/disable billing alarm for cost monitoring
      name                   = optional(string, "Account-Monthly-Budget")                     # Name of the AWS Budget for cost monitoring
      limit_amount           = optional(string, "200")                                        # Budget limit amount (as string, e.g., "200")
      limit_unit             = optional(string, "USD")                                        # Budget limit unit (e.g., "USD")
      time_unit              = optional(string, "MONTHLY")                                    # Budget time unit: MONTHLY, QUARTERLY, or ANNUALLY
      time_period_start      = optional(string, "2022-01-01_00:00")                           # Budget start date in format YYYY-MM-DD_HH:MM
      time_period_end        = optional(string, "2087-06-15_00:00")                           # Budget end date in format YYYY-MM-DD_HH:MM
      thresholds             = optional(list(string), ["40", "60", "80", "90", "100", "110"]) # List of threshold percentages at which to trigger alerts (e.g., ["40", "60", "80"])
      threshold_type         = optional(string, "PERCENTAGE")                                 # Threshold type: PERCENTAGE or ABSOLUTE_VALUE
      comparison_operator    = optional(string, "GREATER_THAN")                               # Comparison operator: GREATER_THAN, LESS_THAN, EQUAL_TO
      notification_type      = optional(string, "ACTUAL")                                     # Notification type: ACTUAL or FORECASTED
      notify_email_addresses = optional(list(string), [])                                     # List of email addresses to receive billing alarm notifications
    }), { enabled : false })
    security_hub_alarms = optional(object({                           # Allows to enable security hub alarm actions, by default it will use account level sns topic for security hub alarms, if you want to use custom alarm actions, you can set use_account_topic to false and set custom_alarm_actions to a map of alarm actions or a list of alarm actions
      enabled           = optional(bool, false)                       # whether to enable security hub alarm actions, if false, will not create any alarm actions
      use_account_topic = optional(bool, true)                        # whether to use account level sns topic(and notification channels) for security hub alarms, if false, will create separate sns topic for it
      custom_alarm_actions = optional(object({                        # custom alarm actions to be used for security hub alarms, this get enabled when security_hub_alarms.enabled is true and security_hub_alarms.use_account_topic is false
        topic_name                       = optional(string, "")       # Takes affect if use_account_topic is false. SNS topic name. If empty and create_topic=false, will use existing topic from alarm_actions module
        create_topic                     = optional(bool, true)       # Takes affect if use_account_topic is false. Whether to create a new SNS topic. Set to false to reuse existing topic from alarm_actions module
        topic_assign_security_hub_policy = optional(bool, true)       # Whether to assign the default security hub policy to the SNS topic
        email_addresses                  = optional(list(string), []) # List of email addresses to receive Security Hub findings notifications
        fallback_email_addresses         = optional(list(string), []) # List of fallback email addresses to receive notifications when primary channels fail
        phone_numbers                    = optional(list(string), []) # List of international formatted phone numbers (e.g., "+1234567890") to receive SMS notifications
        fallback_phone_numbers           = optional(list(string), []) # List of fallback phone numbers for SMS notifications when primary channels fail
        web_endpoints                    = optional(list(string), []) # List of webhook endpoints (e.g., Opsgenie, PagerDuty) to receive HTTP POST notifications
        fallback_web_endpoints           = optional(list(string), []) # List of fallback webhook endpoints when primary channels fail
        lambda_arns                      = optional(list(string), []) # List of Lambda function ARNs to invoke when Security Hub findings are received. Note: Lambda functions must be in the same region as the SNS topic
        fallback_lambda_arns             = optional(list(string), []) # List of fallback Lambda function ARNs when primary channels fail
        slack_webhooks = optional(list(object({                       # List of Slack webhook configurations for sending notifications to Slack channels
          hook_url = string                                           # Slack webhook URL
          channel  = string                                           # Slack channel name (e.g., "#security-alerts")
          username = string                                           # Bot username for Slack messages
        })), [])
        servicenow_webhooks = optional(list(object({ # List of ServiceNow webhook configurations for creating incidents in ServiceNow
          domain = string                            # ServiceNow instance domain (e.g., "yourcompany.service-now.com")
          path   = string                            # API endpoint path
          user   = string                            # ServiceNow username
          pass   = string                            # ServiceNow password or API token
        })), [])
        teams_webhooks = optional(list(string), []) # List of Microsoft Teams webhook URLs for sending notifications to Teams channels
        jira_config = optional(list(object({        # List of Jira configurations for creating tickets for Security Hub findings
          url            = string                   # Jira instance URL (e.g., "https://yourcompany.atlassian.net")
          key            = string                   # Jira project key
          user_username  = string                   # Jira username
          user_api_token = string                   # Jira API token
        })), [])
        delivery_policy          = optional(any, null)      # SNS topic delivery policy for retry and throttling configuration. Controls how SNS retries message delivery to endpoints
        policy                   = optional(any, null)      # SNS topic policy (IAM policy document) for controlling access to the topic. If null, uses default policy allowing EventBridge to publish
        log_group_retention_days = optional(number, 7)      # Number of days to retain CloudWatch Logs for Lambda functions (default: 7 days)
        enable_dead_letter_queue = optional(bool, true)     # Whether to enable dead letter queue (SQS) for failed Lambda invocations
        recreate_missing_package = optional(bool, true)     # Whether to recreate missing Lambda deployment packages if they are missing locally
        log_level                = optional(string, "INFO") # Log level for Lambda functions ("DEBUG", "INFO", "WARNING", "ERROR")
        lambda_failed_alert = optional(any, {               # CloudWatch alarm configuration for monitoring Lambda function failures. Triggers when Lambda functions fail to process notifications
          period    = 60                                    # Evaluation period in seconds
          threshold = 1                                     # Number of failures to trigger alarm
          equation  = "gte"                                 # Comparison operator (greater than or equal)
          statistic = "sum"                                 # Statistic type (sum, average, etc.)
        })
      }), {})
    }), {})
  })

  default     = { enabled = false, billing_alarm = { enabled : false }, security_hub_alarms = { enabled : false } }
  description = "Whether to enable/create regional(TODO: add also us-east-1 region alarm also for health-check alarms) SNS topic/subscribers"
}

variable "alarm_actions_virginia" { # TODO: it seems we can combine alarm_actions_virginia into alarm_actions so that we will have one source of config, as we usually have same channels for alarm in both primary and virginia regions
  type = object({
    enabled                  = optional(bool, false)
    topic_name               = optional(string, "account-alarms-handling")
    enable_dead_letter_queue = optional(bool, false)
    email_addresses          = optional(list(string), [])
    phone_numbers            = optional(list(string), [])
    web_endpoints            = optional(list(string), [])
    lambda_arns              = optional(list(string), [])
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
    enabled                        = optional(bool, true)
    allow_users_to_change_password = optional(bool, true)
    minimum_password_length        = optional(number, 16)
    require_lowercase_characters   = optional(bool, true)
    require_numbers                = optional(bool, true)
    require_symbols                = optional(bool, true)
    require_uppercase_characters   = optional(bool, true)
    max_password_age               = optional(number, 90)
    hard_expiry                    = optional(bool, false)
    password_reuse_prevention      = optional(number, 5)
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
    event_bridge_bus = optional(object({
      create   = optional(bool, false)                 # whether to create event bridge bus, there is default bus name 'default' what can be used without creating separate one
      name     = optional(string, "default")           # the bus name, default bus pre-exist and we can use it
      schedule = optional(string, "cron(0 5 * * ? *)") # schedule to collect cost data, by default we use once a day at 05:00 AM UTC schedule to collect previous day data 'cron(0 5 * * ? *)'
      timezone = optional(string, "Europe/London")
    }), {})
  })
  default     = {}
  description = "Allows to configure and get cost report of previous day to specified `webhook_endpoint`, NOTE: webhook_endpoint is required when enabling this"
}

variable "account_events_export" {
  type = object({
    enabled          = optional(bool, false)
    webhook_endpoint = optional(string, null)                    # required if enabled, this is endpoint to which the events will be sent via POST request
    name             = optional(string, "account-events-export") # the identifier part used for lambda function and event bridge subscription
    event_bridge_bus = optional(object({
      create              = optional(bool, false)                                                                                                                                                                                                                                                                                                                                                                                                                                             # whether to create event bridge bus, there is default bus name 'default' what can be used without creating separate one
      name                = optional(string, "default")                                                                                                                                                                                                                                                                                                                                                                                                                                       # the bus name, default bus pre-exist and we can use it
      rule_pattern_source = optional(list(string), ["aws.ec2", "aws.s3", "aws.rds", "aws.eks", "aws.sqs", "aws.lambda", "aws.iam", "aws.vpc", "custom.test", "aws.route53", "aws.cloudfront", "aws.acm", "aws.cloudwatch", "aws.amplify", "aws.health", "aws.securityhub", "aws.budgets", "aws.secretsmanager", "aws.events", "aws.autoscaling", "aws.elasticache", "aws.elb", "aws.amazonmq", "aws.apigateway", "aws.waf", "aws.waf-regional", "aws.savingsplans", "aws.opensearchservice"]) # The list of aws services to capture and stream/export event, for available event sources check https://docs.aws.amazon.com/eventbridge/latest/ref/events.html
    }), {})
  })
  default     = {}
  description = "Allows to configure and stream aws account important events to specified `webhook_endpoint`, NOTE: webhook_endpoint is required when enabling this"
}

variable "security_hub" {
  type = object({
    enabled = optional(bool, false) # Enable/disable Security Hub and its submodules
    name    = optional(string, "account-security-hub")
    # Security Hub configuration
    enable_security_hub                    = optional(bool, true)            # Whether to enable Security Hub service. Set to false if Security Hub is already enabled
    enable_security_hub_finding_aggregator = optional(bool, true)            # Whether to enable Security Hub finding aggregator for multi-region/account aggregation
    link_mode                              = optional(string, "ALL_REGIONS") # Linking mode for finding aggregator: ALL_REGIONS, SPECIFIED_REGIONS, or ALL
    specified_regions                      = optional(list(string), [])      # List of regions for SPECIFIED_REGIONS link mode
    enabled_standards = optional(set(string), [                              # Security Hub standards to enable. Available standards:
      "aws-foundational-security-best-practices/v/1.0.0",                    # AWS Foundational Security Best Practices v1.0.0 (default)
      "cis-aws-foundations-benchmark/v/1.2.0"                                # CIS AWS Foundations Benchmark v1.2.0 (default)
      # "cis-aws-foundations-benchmark/v/1.4.0"                             # CIS AWS Foundations Benchmark v1.4.0
      # "cis-aws-foundations-benchmark/v/3.0.0"                             # CIS AWS Foundations Benchmark v3.0.0
      # "cis-aws-foundations-benchmark/v/5.0.0"                             # CIS AWS Foundations Benchmark v5.0.0
      # "aws-resource-tagging-standard/v/1.0.0"                             # AWS Resource Tagging Standard v1.0.0
      # "nist-800-171-rev2/v/1.0.0"                                         # NIST Special Publication 800-171 Revision 2
      # "nist-800-53-rev5/v/1.0.0"                                          # NIST Special Publication 800-53 Revision 5
      # "pci-dss/v/3.2.1"                                                   # PCI DSS v3.2.1
      # "pci-dss/v/4.0.1"                                                   # PCI DSS v4.0.1
    ])
    action_target_name  = optional(string, "SendNotification") # Name of the Security Hub action target for manual triggers
    securityhub_members = optional(map(string), {})            # Map of email -> account_id for Security Hub member accounts
    # AWS Config submodule configuration
    config = optional(object({
      enabled                    = optional(bool, true)                 # Enable/disable AWS Config. REQUIRED for Security Hub standards to work properly
      create_service_linked_role = optional(bool, true)                 # Whether to create the AWS Config service-linked role. Set to false if the role already exists
      record_all_resources       = optional(bool, true)                 # Record all supported resource types in AWS Config
      include_global_resources   = optional(bool, true)                 # Include global resources (IAM, etc.) in AWS Config recording
      s3_bucket_name             = optional(string, "")                 # S3 bucket name for AWS Config. If empty, a bucket will be created automatically
      s3_bucket_force_destroy    = optional(bool, false)                # Force destroy S3 bucket for Config when deleting the module
      delivery_frequency         = optional(string, "TwentyFour_Hours") # Frequency for Config snapshot delivery
      included_resource_types    = optional(list(string), [])           # List of resource types to include when record_all_resources is false
      excluded_resource_types    = optional(list(string), [])           # List of resource types to exclude when record_all_resources is true
      rules = optional(map(object({                                     # Map of Config rules to create
        description = optional(string)
        source = optional(object({
          owner             = string
          source_identifier = string
          source_detail = optional(list(object({
            event_source                = optional(string)
            maximum_execution_frequency = optional(string)
            message_type                = optional(string)
          })))
        }))
        scope = optional(object({
          compliance_resource_types = optional(list(string))
          compliance_resource_id    = optional(string)
          tag_key                   = optional(string)
          tag_value                 = optional(string)
        }))
        input_parameters = optional(string)
        tags             = optional(map(string))
      })), {})
    }), {})
    # AWS Inspector submodule configuration
    inspector = optional(object({
      enabled        = optional(bool, true)                                            # Enable/disable AWS Inspector v2. RECOMMENDED for EC2/EKS vulnerability scanning
      resource_types = optional(list(string), ["EC2", "ECR", "LAMBDA", "LAMBDA_CODE"]) # Resource types to enable Inspector for. Valid values: EC2, ECR, LAMBDA, LAMBDA_CODE, CODE_REPOSITORY. LAMBDA scans Lambda function configuration (runtime, permissions). LAMBDA_CODE scans Lambda function code (dependencies, vulnerabilities). Both are recommended for comprehensive Lambda scanning
      filters = optional(map(object({                                                  # Map of findings filters to create. Key is the filter name. If empty, no filters will be created
        description   = optional(string)                                               # Filter description
        filter_action = string                                                         # Filter action. Valid values: ARCHIVE (suppress findings), NOOP (no action)
        filter_criteria = optional(object({                                            # Filter criteria for matching findings
          aws_account_id = optional(object({                                           # Filter by AWS account ID
            comparison = string                                                        # Comparison operator (EQUALS, PREFIX, NOT_EQUALS)
            value      = string                                                        # Account ID value
          }))
          component_id = optional(object({ # Filter by component ID
            comparison = string
            value      = string
          }))
          component_type = optional(object({ # Filter by component type
            comparison = string
            value      = string
          }))
          ec2_instance_image_id = optional(object({ # Filter by EC2 instance AMI ID
            comparison = string
            value      = string
          }))
          ec2_instance_subnet_id = optional(object({ # Filter by EC2 instance subnet ID
            comparison = string
            value      = string
          }))
          ec2_instance_vpc_id = optional(object({ # Filter by EC2 instance VPC ID
            comparison = string
            value      = string
          }))
          ecr_image_pushed_at = optional(object({ # Filter by ECR image push date/time
            end_inclusive   = optional(string)    # End date (ISO 8601 format)
            start_inclusive = optional(string)    # Start date (ISO 8601 format)
          }))
          ecr_image_tags = optional(object({ # Filter by ECR image tags
            comparison = string
            value      = string
          }))
          ecr_image_hash = optional(object({ # Filter by ECR image hash
            comparison = string
            value      = string
          }))
          finding_arn = optional(object({ # Filter by finding ARN
            comparison = string
            value      = string
          }))
          finding_status = optional(object({ # Filter by finding status (ACTIVE, SUPPRESSED, CLOSED)
            comparison = string
            value      = string
          }))
          finding_type = optional(object({ # Filter by finding type
            comparison = string
            value      = string
          }))
          first_observed_at = optional(object({ # Filter by first observation date/time
            end_inclusive   = optional(string)  # End date (ISO 8601 format)
            start_inclusive = optional(string)  # Start date (ISO 8601 format)
          }))
          inspector_score = optional(object({  # Filter by Inspector score range
            lower_inclusive = optional(number) # Minimum score (0-10)
            upper_inclusive = optional(number) # Maximum score (0-10)
          }))
          last_observed_at = optional(object({ # Filter by last observation date/time
            end_inclusive   = optional(string) # End date (ISO 8601 format)
            start_inclusive = optional(string) # Start date (ISO 8601 format)
          }))
          network_protocol = optional(object({ # Filter by network protocol
            comparison = string
            value      = string
          }))
          port_range = optional(object({       # Filter by port range
            begin_inclusive = optional(number) # Start port number
            end_inclusive   = optional(number) # End port number
          }))
          related_vulnerabilities = optional(object({ # Filter by related vulnerability IDs
            comparison = string
            value      = string
          }))
          resource_id = optional(object({ # Filter by resource ID
            comparison = string
            value      = string
          }))
          resource_tags = optional(object({ # Filter by resource tags
            comparison = string             # Comparison operator
            key        = string             # Tag key
            value      = optional(string)   # Tag value (optional)
          }))
          resource_type = optional(object({ # Filter by resource type (EC2, ECR, LAMBDA)
            comparison = string
            value      = string
          }))
          severity = optional(object({ # Filter by severity (CRITICAL, HIGH, MEDIUM, LOW, INFORMATIONAL, UNTRIAGED)
            comparison = string
            value      = string
          }))
          title = optional(object({ # Filter by finding title
            comparison = string
            value      = string
          }))
          updated_at = optional(object({       # Filter by last update date/time
            end_inclusive   = optional(string) # End date (ISO 8601 format)
            start_inclusive = optional(string) # Start date (ISO 8601 format)
          }))
          vendor_severity = optional(object({ # Filter by vendor severity
            comparison = string
            value      = string
          }))
          vulnerability_id = optional(object({ # Filter by vulnerability ID (CVE ID, etc.)
            comparison = string
            value      = string
          }))
          vulnerability_source = optional(object({ # Filter by vulnerability source
            comparison = string
            value      = string
          }))
        }))
      })), {})
    }), {})
    # AWS GuardDuty submodule configuration
    guardduty = optional(object({
      enabled                      = optional(bool, false)               # Enable/disable AWS GuardDuty for threat detection
      finding_publishing_frequency = optional(string, "FIFTEEN_MINUTES") # Frequency for publishing findings: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS
      enable_s3_protection         = optional(bool, false)               # Enable S3 protection
      enable_kubernetes_protection = optional(bool, false)               # Enable Kubernetes protection
      enable_malware_protection    = optional(bool, false)               # Enable malware protection
      filters = optional(map(object({                                    # Map of GuardDuty filters to create (key is filter name)
        name        = string                                             # Filter name
        description = optional(string)
        action      = string              # Filter action: ARCHIVE or NOOP
        rank        = optional(number, 1) # Filter rank (1 is highest priority)
        finding_criteria = object({
          criterion = map(object({
            eq                    = optional(list(string), [])
            neq                   = optional(list(string), [])
            gt                    = optional(number)
            gte                   = optional(number)
            lt                    = optional(number)
            lte                   = optional(number)
            equals                = optional(list(string), [])
            not_equals            = optional(list(string), [])
            greater_than          = optional(number)
            greater_than_or_equal = optional(number)
            less_than             = optional(number)
            less_than_or_equal    = optional(number)
          }))
        })
      })), {})
    }), {})
    # Amazon Macie submodule configuration
    macie = optional(object({
      enabled                      = optional(bool, false)               # Enable/disable Amazon Macie for data security
      finding_publishing_frequency = optional(string, "FIFTEEN_MINUTES") # Frequency for publishing findings: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS
      status                       = optional(string, "ENABLED")         # Macie status: ENABLED or PAUSED
      findings_filters = optional(map(object({                           # Map of Macie findings filters to create (key is filter name)
        name        = string                                             # Filter name
        description = optional(string)
        action      = string              # Filter action: ARCHIVE or NOOP
        position    = optional(number, 1) # Filter position (1 is highest priority)
        finding_criteria = object({
          criterion = map(object({
            eq                    = optional(list(string), [])
            neq                   = optional(list(string), [])
            gt                    = optional(number)
            gte                   = optional(number)
            lt                    = optional(number)
            lte                   = optional(number)
            equals                = optional(list(string), [])
            not_equals            = optional(list(string), [])
            greater_than          = optional(number)
            greater_than_or_equal = optional(number)
            less_than             = optional(number)
            less_than_or_equal    = optional(number)
          }))
        })
      })), {})
    }), {})
  })
  default     = {}
  description = "AWS Security Hub configuration with submodules (Config, Inspector, GuardDuty, Macie) and alarm actions for findings notifications"
}
