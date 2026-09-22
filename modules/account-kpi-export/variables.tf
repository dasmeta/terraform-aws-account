variable "cloudbrowser" {
  type = object({
    base_url               = optional(string, "https://app.dasmeta.com")
    client_id              = number
    secret_arn             = string
    aws_provider_id        = optional(number, 1)
    cloudbrowser_token_key = optional(string, "cloudbrowser_api_token")
    grafana_token_key      = optional(string, "grafana_api_token")
  })
  description = "CloudBrowser endpoint, account relation identifiers, secret reference, and JSON token key names."

  validation {
    condition = (
      can(regex("^https://[^/:?#@]+(:[0-9]+)?(/[^?#]*)?$", lower(trimspace(var.cloudbrowser.base_url)))) &&
      var.cloudbrowser.client_id > 0 && floor(var.cloudbrowser.client_id) == var.cloudbrowser.client_id &&
      can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+$", var.cloudbrowser.secret_arn)) &&
      var.cloudbrowser.aws_provider_id > 0 && floor(var.cloudbrowser.aws_provider_id) == var.cloudbrowser.aws_provider_id &&
      trimspace(var.cloudbrowser.cloudbrowser_token_key) != "" &&
      trimspace(var.cloudbrowser.grafana_token_key) != ""
    )
    error_message = "CloudBrowser must use an HTTPS base URL with a hostname, optional numeric port, path only, and no userinfo, query, or fragment; client and provider IDs must be positive integers."
  }
}

variable "application" {
  type = object({
    enabled        = optional(bool, false)
    source_type    = optional(string, "prometheus")
    grafana_url    = optional(string, "")
    datasource_uid = optional(string, "")
    metric_filter  = optional(string, "")
    uptime_query   = optional(string, "")
    latency_query  = optional(string, "")
    region         = optional(string, "")
    load_balancer  = optional(string, "")
  })
  default     = {}
  description = "Production application Grafana source. Prometheus queries or CloudWatch ALB settings are required according to source_type."

  validation {
    condition = !var.application.enabled || (
      can(regex("^https://[^/:?#@]+(:[0-9]+)?(/[^?#]*)?$", lower(trimspace(var.application.grafana_url)))) &&
      alltrue([
        for value in [var.application.grafana_url, var.application.datasource_uid] :
        trimspace(value) != ""
        ]) && contains(["prometheus", "cloudwatch_alb"], var.application.source_type) && (
        var.application.source_type == "prometheus" ? (
          (
            trimspace(var.application.uptime_query) == "" &&
            trimspace(var.application.latency_query) == "" &&
            trimspace(var.application.metric_filter) != ""
            ) || alltrue([
              for query in [var.application.uptime_query, var.application.latency_query] :
              trimspace(query) != "" &&
              replace(query, "$__account_kpi_window", "") != query &&
              replace(query, "$__account_kpi_end_seconds", "") != query
          ])
          ) : (
          trimspace(var.application.region) != "" &&
          trimspace(var.application.load_balancer) != ""
        )
      )
    )
    error_message = "Enabled application collection requires an HTTPS Grafana base URL, datasource, a supported source_type, and either a non-empty Prometheus metric_filter with no raw queries, two Prometheus queries with both KPI placeholders, or complete CloudWatch ALB settings."
  }
}

variable "cost" {
  type = object({
    enabled = optional(bool, true)
  })
  default     = {}
  description = "Cost Explorer collection settings."
}

variable "security" {
  type = object({
    enabled = optional(bool, true)
    region  = optional(string, "eu-central-1")
  })
  default     = {}
  description = "Security Hub collection settings and aggregation Region."

  validation {
    condition     = trimspace(var.security.region) != ""
    error_message = "The Security Hub aggregation Region must be non-empty."
  }
}

variable "metrics" {
  type = object({
    security = optional(number, 4)
    cost     = optional(number, 12)
    uptime   = optional(number, 24)
    latency  = optional(number, 26)
  })
  default     = {}
  description = "CloudBrowser metric relation IDs for each collected KPI."

  validation {
    condition = alltrue([
      for id in [var.metrics.security, var.metrics.cost, var.metrics.uptime, var.metrics.latency] :
      id > 0 && floor(id) == id
    ])
    error_message = "Every metric ID must be a positive integer."
  }
}

variable "schedules" {
  type = object({
    timezone                              = optional(string, "Asia/Yerevan")
    monday_expression                     = optional(string, "cron(0 6 ? * MON *)")
    wednesday_expression                  = optional(string, "cron(0 6 ? * WED *)")
    delivery_maximum_event_age_in_seconds = optional(number, 86400)
    delivery_maximum_retry_attempts       = optional(number, 2)
  })
  default     = {}
  description = "Weekly Scheduler expressions, IANA time zone, and target-delivery retry limits."

  validation {
    condition = (
      can(regex("^[A-Za-z][A-Za-z0-9._+-]*/[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$", var.schedules.timezone)) &&
      trimspace(var.schedules.monday_expression) != "" &&
      trimspace(var.schedules.wednesday_expression) != "" &&
      var.schedules.delivery_maximum_event_age_in_seconds >= 60 &&
      var.schedules.delivery_maximum_event_age_in_seconds <= 86400 &&
      floor(var.schedules.delivery_maximum_event_age_in_seconds) == var.schedules.delivery_maximum_event_age_in_seconds &&
      var.schedules.delivery_maximum_retry_attempts >= 0 &&
      var.schedules.delivery_maximum_retry_attempts <= 185 &&
      floor(var.schedules.delivery_maximum_retry_attempts) == var.schedules.delivery_maximum_retry_attempts
    )
    error_message = "Schedules require an IANA-style timezone, non-empty expressions, event age from 60 to 86400 seconds, and 0 to 185 retry attempts."
  }
}

variable "lambda" {
  type = object({
    name                               = optional(string, "account-kpi-export")
    timeout                            = optional(number, 600)
    memory_size                        = optional(number, 256)
    logs_retention_in_days             = optional(number, 30)
    async_maximum_event_age_in_seconds = optional(number, 21600)
    async_maximum_retry_attempts       = optional(number, 2)
    alarm_action_arns                  = optional(list(string), [])
  })
  default     = {}
  description = "Lambda runtime, asynchronous handler retry, log retention, and alarm notification settings."

  validation {
    condition = (
      can(regex("^[A-Za-z0-9-_]{1,54}$", var.lambda.name)) &&
      var.lambda.timeout >= 1 && var.lambda.timeout <= 900 && floor(var.lambda.timeout) == var.lambda.timeout &&
      var.lambda.memory_size >= 128 && var.lambda.memory_size <= 10240 && floor(var.lambda.memory_size) == var.lambda.memory_size &&
      contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.lambda.logs_retention_in_days) &&
      var.lambda.async_maximum_event_age_in_seconds >= 60 && var.lambda.async_maximum_event_age_in_seconds <= 21600 &&
      floor(var.lambda.async_maximum_event_age_in_seconds) == var.lambda.async_maximum_event_age_in_seconds &&
      var.lambda.async_maximum_retry_attempts >= 0 && var.lambda.async_maximum_retry_attempts <= 2 &&
      floor(var.lambda.async_maximum_retry_attempts) == var.lambda.async_maximum_retry_attempts &&
      alltrue([for arn in var.lambda.alarm_action_arns : trimspace(arn) != ""])
    )
    error_message = "Lambda settings must use a name of 1 to 54 characters (leaving room for derived resource names), AWS runtime bounds, positive log retention, async age from 60 to 21600 seconds, and 0 to 2 async retries."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to resources created by the exporter."
}
