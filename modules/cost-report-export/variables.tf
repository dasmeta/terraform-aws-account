variable "webhook_endpoint" {
  type        = string
  description = "The endpoint where report will be sent"
  nullable    = false
}

variable "name" {
  type        = string
  default     = "account-cost-report"
  description = "The naming to use to create resource"
}

variable "eventBridgeBus" {
  type = object({
    create   = optional(bool, false)                 # whether to create event bridge bus, there is default bus name 'default' what can be used without creating separate one
    name     = optional(string, "default")           # the bus name, default bus pre-exist and we can use it
    schedule = optional(string, "cron(0 5 * * ? *)") # schedule to collect cost data, by default we use once a day at 05:00 AM UTC schedule to collect previous day data 'cron(0 5 * * ? *)'
    timezone = optional(string, "Europe/London")
  })
  default     = {}
  description = "Event bridge cronjob/scheduler configs"
}

variable "logs_retention_in_days" {
  type        = number
  default     = 7
  description = "Lambda function logs retention days"
}
