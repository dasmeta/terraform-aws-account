variable "webhook_endpoint" {
  type        = string
  description = "The endpoint where report will be sent"
  nullable    = false
}

variable "name" {
  type        = string
  default     = "account-events-export"
  description = "The naming to use to create resource"
}

variable "event_bridge_bus" {
  type = object({
    create              = optional(bool, false)                                                                                                                                                                                                                                                                                                                                                                                                                                             # whether to create event bridge bus, there is default bus name 'default' what can be used without creating separate one
    name                = optional(string, "default")                                                                                                                                                                                                                                                                                                                                                                                                                                       # the bus name, default bus pre-exist and we can use it
    rule_pattern_source = optional(list(string), ["aws.ec2", "aws.s3", "aws.rds", "aws.eks", "aws.sqs", "aws.lambda", "aws.iam", "aws.vpc", "custom.test", "aws.route53", "aws.cloudfront", "aws.acm", "aws.cloudwatch", "aws.amplify", "aws.health", "aws.securityhub", "aws.budgets", "aws.secretsmanager", "aws.events", "aws.autoscaling", "aws.elasticache", "aws.elb", "aws.amazonmq", "aws.apigateway", "aws.waf", "aws.waf-regional", "aws.savingsplans", "aws.opensearchservice"]) # The list of aws services to capture and stream/export event, for available event sources check https://docs.aws.amazon.com/eventbridge/latest/ref/events.html
  })
  default     = {}
  description = "Event bridge cronjob/scheduler configs"
}

variable "logs_retention_in_days" {
  type        = number
  default     = 7
  description = "Lambda function logs retention days"
}

variable "dlq_alarm_actions" {
  type        = list(string)
  default     = []
  description = "Notification action ARNs for the failed-event queue depth alarm"
}

variable "delivery" {
  type = object({
    maximum_concurrency       = optional(number, 2)
    webhook_timeout_seconds   = optional(number, 10)
    lambda_timeout_seconds    = optional(number, 15)
    message_retention_seconds = optional(number, 1209600)
    dlq_retention_seconds     = optional(number, 1209600)
    max_receive_count         = optional(number, 100) # about 2.5 hours with the default 90-second visibility timeout
  })
  default     = {}
  description = "Buffered webhook delivery limits and failure retention"

  validation {
    condition     = var.delivery.maximum_concurrency >= 2 && var.delivery.maximum_concurrency <= 1000
    error_message = "delivery.maximum_concurrency must be between 2 and 1000."
  }

  validation {
    condition     = var.delivery.webhook_timeout_seconds > 0 && var.delivery.webhook_timeout_seconds < var.delivery.lambda_timeout_seconds
    error_message = "delivery.webhook_timeout_seconds must be positive and lower than delivery.lambda_timeout_seconds."
  }

  validation {
    condition     = var.delivery.lambda_timeout_seconds <= 900
    error_message = "delivery.lambda_timeout_seconds must not exceed 900 seconds."
  }

  validation {
    condition     = var.delivery.message_retention_seconds >= 60 && var.delivery.message_retention_seconds <= 1209600 && var.delivery.dlq_retention_seconds >= 60 && var.delivery.dlq_retention_seconds <= 1209600
    error_message = "Queue retention values must be between 60 seconds and 14 days."
  }

  validation {
    condition     = var.delivery.max_receive_count >= 5 && var.delivery.max_receive_count <= 1000
    error_message = "delivery.max_receive_count must be between 5 and 1000."
  }
}
