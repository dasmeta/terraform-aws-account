variable "users" {
  type        = list(any)
  default     = []
  description = "List of users"
}

variable "buckets" {
  type        = list(any)
  default     = []
  description = "List of buckets"
}

variable "ecrs" {
  type        = list(string)
  default     = []
  description = "List of ECR repositories"
}

variable "create_cloudwatch_log_role" {
  type        = bool
  default     = false
  description = "This is an account level configuration which creates IAM role with policy allowing cloudwatch sync/push logs into cloudwatch"
}

variable "name" {
  type        = string
  description = "Name CloudTrail"
}

variable "enable_log_file_validation" {
  type        = bool
  default     = true
  description = "Specifies whether log file integrity validation is enabled. Creates signed digest for validated contents of logs"
}

variable "is_multi_region_trail" {
  type        = bool
  default     = true
  description = "Specifies whether the trail is created in the current region or in all regions"
}

variable "include_global_service_events" {
  type        = bool
  default     = true
  description = "Specifies whether the trail is publishing events from global services such as IAM to the log files"
}

variable "enable_logging" {
  type        = bool
  default     = true
  description = "Enable logging for the trail"
}

variable "cloud_watch_logs_role_arn" {
  type        = string
  description = "Specifies the role for the CloudWatch Logs endpoint to assume to write to a user’s log group"
  default     = ""
}

variable "cloud_watch_logs_group_arn" {
  type        = string
  description = "Specifies a log group name using an Amazon Resource Name (ARN), that represents the log group to which CloudTrail logs will be delivered"
  default     = ""
}

variable "event_selector" {
  type = list(object({
    include_management_events = bool
    read_write_type           = string

    data_resource = list(object({
      type   = string
      values = list(string)
    }))
  }))

  description = "Specifies an event selector for enabling data event logging. See: https://www.terraform.io/docs/providers/aws/r/cloudtrail.html for details on this variable"
  default     = []
}

variable "is_organization_trail" {
  type        = bool
  default     = false
  description = "The trail is an AWS Organizations trail"
}

variable "sns_topic_name" {
  type        = string
  description = "Specifies the name of the Amazon SNS topic defined for notification of log file delivery"
  default     = null
}

variable "create_s3_bucket" {
  type    = bool
  default = true
}

variable "bucket_name" {
  type    = string
  default = null
}

variable "groups" {
  type    = list(any)
  default = []
}

variable "billing-name" {
  type    = string
  default = "Account-Monthly-Budget"
}

variable "account_budget_limit" {
  type    = string
  default = "200"
}

variable "limit_unit" {
  type    = string
  default = "USD"
}

variable "time_unit" {
  type    = string
  default = "MONTHLY"
}

variable "sns_subscription_email_address_list" {
  type    = list(any)
  default = []
}

variable "sns_subscription_phone_number_list" {
  type    = list(any)
  default = []
}

variable "opsgenie_endpoint" {
  type    = list(any)
  default = []
}

variable "slack_hook_url" {
  type    = string
  default = ""
}

variable "metric_name" {
  type    = string
  default = "EstimatedCharges"
}

variable "alarm_name" {
  type    = string
  default = "Billing-Limit-Alert"
}

variable "threshold" {
  type    = string
  default = "200"
}

variable "comparison_operator" {
  type    = string
  default = "GREATER_THAN"
}
