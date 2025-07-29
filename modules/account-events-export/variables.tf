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
    create              = optional(bool, false)                                                                                                                                                                                                                                                                                                                                                                                                                                                # whether to create event bridge bus, there is default bus name 'default' what can be used without creating separate one
    name                = optional(string, "default")                                                                                                                                                                                                                                                                                                                                                                                                                                          # the bus name, default bus pre-exist and we can use it
    rule_pattern_source = optional(list(string), ["aws.route53", "aws.cloudfront", "aws.acm", "aws.cloudwatch", "aws.amplify", "aws.health", "aws.securityhub", "aws.budgets", "aws.secretsmanager", "aws.events", "aws.autoscaling", "aws.elasticache", "aws.elb", "aws.amazonmq", "aws.ec2", "aws.s3", "aws.rds", "aws.apigateway", "aws.waf", "aws.waf-regional", "aws.savingsplans", "aws.opensearchservice", "aws.sqs", "aws.lambda", "aws.iam", "aws.vpc", "custom.test", "aws.lambda"]) # The list of aws services to capture and stream/export event, for available event sources check https://docs.aws.amazon.com/eventbridge/latest/ref/events.html
  })
  default     = {}
  description = "Event bridge cronjob/scheduler configs"
}

variable "logs_retention_in_days" {
  type        = number
  default     = 7
  description = "Lambda function logs retention days"
}
