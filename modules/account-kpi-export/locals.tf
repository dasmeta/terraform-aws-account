locals {
  application_query_profile        = trimspace(var.application.query_profile)
  application_metric_filter        = trimspace(var.application.metric_filter)
  application_metric_filter_suffix = local.application_metric_filter == "" ? "" : ", ${local.application_metric_filter}"
  nginx_ingress_uptime_query       = "100 * sum(increase(nginx_ingress_controller_requests{status!~\"5..|499\"${local.application_metric_filter_suffix}}[$__account_kpi_window] @ $__account_kpi_end_seconds)) / sum(increase(nginx_ingress_controller_requests{${local.application_metric_filter}}[$__account_kpi_window] @ $__account_kpi_end_seconds))"
  nginx_ingress_latency_query      = "sum(increase(nginx_ingress_controller_request_duration_seconds_sum{status=~\"2..|3..|429|499\"${local.application_metric_filter_suffix}}[$__account_kpi_window] @ $__account_kpi_end_seconds)) / sum(increase(nginx_ingress_controller_request_duration_seconds_count{status=~\"2..|3..|429|499\"${local.application_metric_filter_suffix}}[$__account_kpi_window] @ $__account_kpi_end_seconds))"

  handler_configuration = {
    timezone = var.schedules.timezone
    cloudbrowser = {
      base_url        = var.cloudbrowser.base_url
      client_id       = var.cloudbrowser.client_id
      aws_provider_id = var.cloudbrowser.aws_provider_id
      token_key       = var.cloudbrowser.cloudbrowser_token_key
    }
    cost = {
      enabled = var.cost.enabled
      scope   = var.cost.scope
    }
    security = {
      enabled = var.security.enabled
      region  = var.security.region
    }
    metrics = {
      cost     = var.metrics.cost
      security = var.metrics.security
      uptime   = var.metrics.uptime
      latency  = var.metrics.latency
    }
  }

  application_configuration = merge({
    enabled        = true
    source_type    = var.application.source_type
    grafana_url    = var.application.grafana_url
    datasource_uid = var.application.datasource_uid
    token_key      = var.cloudbrowser.grafana_token_key
    }, var.application.source_type == "prometheus" ? {
    uptime_query  = local.application_query_profile == "nginx_ingress" ? local.nginx_ingress_uptime_query : var.application.uptime_query
    latency_query = local.application_query_profile == "nginx_ingress" ? local.nginx_ingress_latency_query : var.application.latency_query
    } : {
    region        = var.application.region
    load_balancer = var.application.load_balancer
  })

  config_json = var.application.enabled ? jsonencode(merge(local.handler_configuration, {
    application = local.application_configuration
    })) : jsonencode(merge(local.handler_configuration, {
    application = {
      enabled = false
    }
  }))

  lambda_configuration = {
    handler                                   = "handler.lambda_handler"
    runtime                                   = "python3.13"
    timeout                                   = var.lambda.timeout
    memory_size                               = var.lambda.memory_size
    reserved_concurrent_executions            = 1
    cloudwatch_logs_retention_days            = var.lambda.logs_retention_in_days
    create_package                            = false
    publish                                   = false
    create_async_event_config                 = true
    create_current_version_async_event_config = false
    maximum_event_age_in_seconds              = var.lambda.async_maximum_event_age_in_seconds
    maximum_retry_attempts                    = var.lambda.async_maximum_retry_attempts
    attach_async_event_policy                 = false
    vpc_subnet_ids                            = []
    vpc_security_group_ids                    = []
  }

  failure_queue_configuration = {
    name                    = "${var.lambda.name}-failures"
    sqs_managed_sse_enabled = true
  }

  async_event_configuration = {
    maximum_event_age_in_seconds = var.lambda.async_maximum_event_age_in_seconds
    maximum_retry_attempts       = var.lambda.async_maximum_retry_attempts
    destination_on_failure       = module.failure_queue.queue_arn
  }

  lambda_policy_statements = merge(
    {
      secret = {
        effect    = "Allow"
        actions   = ["secretsmanager:GetSecretValue"]
        resources = [var.cloudbrowser.secret_arn]
      }
      failure_queue = {
        effect    = "Allow"
        actions   = ["sqs:SendMessage"]
        resources = [module.failure_queue.queue_arn]
      }
    },
    var.cost.enabled ? {
      cost = {
        effect    = "Allow"
        actions   = ["ce:GetCostAndUsage"]
        resources = ["*"]
      }
    } : {},
    var.security.enabled ? {
      security = {
        effect    = "Allow"
        actions   = ["securityhub:GetEnabledStandards", "securityhub:GetFindings"]
        resources = ["*"]
      }
    } : {}
  )

  scheduler_policy_statements = {
    invoke = {
      effect    = "Allow"
      actions   = ["lambda:InvokeFunction"]
      resources = [module.lambda_function.lambda_function_arn]
    }
    failure_queue = {
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [module.failure_queue.queue_arn]
    }
  }

  monday_schedule_name    = "${var.lambda.name}-monday"
  wednesday_schedule_name = "${var.lambda.name}-wednesday"
  delivery_retry_policy = {
    maximum_event_age_in_seconds = var.schedules.delivery_maximum_event_age_in_seconds
    maximum_retry_attempts       = var.schedules.delivery_maximum_retry_attempts
  }

  scheduler_schedules = merge(
    var.application.enabled ? {
      (local.monday_schedule_name) = {
        description         = "Collect prior-week application KPIs"
        schedule_expression = var.schedules.monday_expression
        timezone            = var.schedules.timezone
        arn                 = module.lambda_function.lambda_function_arn
        input               = jsonencode({ job = "application" })
        retry_policy        = local.delivery_retry_policy
        dead_letter_arn     = module.failure_queue.queue_arn
      }
    } : {},
    var.cost.enabled || var.security.enabled ? {
      (local.wednesday_schedule_name) = {
        description         = "Collect prior-week AWS KPIs"
        schedule_expression = var.schedules.wednesday_expression
        timezone            = var.schedules.timezone
        arn                 = module.lambda_function.lambda_function_arn
        input               = jsonencode({ job = "aws" })
        retry_policy        = local.delivery_retry_policy
        dead_letter_arn     = module.failure_queue.queue_arn
      }
    } : {}
  )

  alarm_configurations = {
    lambda_errors = {
      alarm_name          = "${var.lambda.name}-lambda-errors"
      metric_name         = "Errors"
      namespace           = "AWS/Lambda"
      statistic           = "Sum"
      period              = "300"
      evaluation_periods  = 1
      comparison_operator = "GreaterThanThreshold"
      threshold           = 0
      treat_missing_data  = "notBreaching"
      dimensions = {
        FunctionName = module.lambda_function.lambda_function_name
      }
      alarm_actions = var.lambda.alarm_action_arns
    }
    failure_queue = {
      alarm_name          = "${var.lambda.name}-failure-queue-visible"
      metric_name         = "ApproximateNumberOfMessagesVisible"
      namespace           = "AWS/SQS"
      statistic           = "Maximum"
      period              = "300"
      evaluation_periods  = 1
      comparison_operator = "GreaterThanThreshold"
      threshold           = 0
      treat_missing_data  = "notBreaching"
      dimensions = {
        QueueName = module.failure_queue.queue_name
      }
      alarm_actions = var.lambda.alarm_action_arns
    }
  }
}
