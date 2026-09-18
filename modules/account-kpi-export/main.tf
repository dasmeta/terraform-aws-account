module "failure_queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "4.3.1"

  name                    = local.failure_queue_configuration.name
  sqs_managed_sse_enabled = local.failure_queue_configuration.sqs_managed_sse_enabled

  tags = var.tags
}

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.21.1"

  function_name = var.lambda.name
  description   = "Collect weekly account KPIs and write them to CloudBrowser"
  handler       = local.lambda_configuration.handler
  runtime       = local.lambda_configuration.runtime
  timeout       = local.lambda_configuration.timeout
  memory_size   = local.lambda_configuration.memory_size
  tracing_mode  = "PassThrough"

  create_package         = local.lambda_configuration.create_package
  local_existing_package = "${path.module}/account-kpi-export-lambda.zip"
  publish                = local.lambda_configuration.publish

  reserved_concurrent_executions = local.lambda_configuration.reserved_concurrent_executions
  environment_variables = {
    CONFIG_JSON = local.config_json
    SECRET_ARN  = var.cloudbrowser.secret_arn
  }

  vpc_subnet_ids                    = local.lambda_configuration.vpc_subnet_ids
  vpc_security_group_ids            = local.lambda_configuration.vpc_security_group_ids
  attach_network_policy             = false
  cloudwatch_logs_retention_in_days = local.lambda_configuration.cloudwatch_logs_retention_days

  create_async_event_config                   = local.lambda_configuration.create_async_event_config
  create_current_version_async_event_config   = local.lambda_configuration.create_current_version_async_event_config
  create_unqualified_alias_async_event_config = true
  maximum_event_age_in_seconds                = local.async_event_configuration.maximum_event_age_in_seconds
  maximum_retry_attempts                      = local.async_event_configuration.maximum_retry_attempts
  destination_on_failure                      = local.async_event_configuration.destination_on_failure
  attach_async_event_policy                   = local.lambda_configuration.attach_async_event_policy

  attach_policy_statements = true
  policy_statements        = local.lambda_policy_statements

  tags = var.tags
}

module "scheduler" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "3.17.1"

  create_bus              = false
  create_rules            = false
  create_targets          = false
  append_schedule_postfix = false
  schedules               = local.scheduler_schedules

  role_name                = "${var.lambda.name}-scheduler"
  attach_lambda_policy     = false
  attach_sqs_policy        = false
  attach_policy_statements = true
  policy_statements        = local.scheduler_policy_statements

  tags = var.tags
}

module "lambda_errors_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.2"

  alarm_name          = local.alarm_configurations.lambda_errors.alarm_name
  alarm_description   = "Weekly KPI collector Lambda reported an error"
  comparison_operator = local.alarm_configurations.lambda_errors.comparison_operator
  evaluation_periods  = local.alarm_configurations.lambda_errors.evaluation_periods
  threshold           = local.alarm_configurations.lambda_errors.threshold
  metric_name         = local.alarm_configurations.lambda_errors.metric_name
  namespace           = local.alarm_configurations.lambda_errors.namespace
  period              = local.alarm_configurations.lambda_errors.period
  statistic           = local.alarm_configurations.lambda_errors.statistic
  dimensions          = local.alarm_configurations.lambda_errors.dimensions
  treat_missing_data  = local.alarm_configurations.lambda_errors.treat_missing_data
  alarm_actions       = local.alarm_configurations.lambda_errors.alarm_actions

  tags = var.tags
}

module "failure_queue_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.2"

  alarm_name          = local.alarm_configurations.failure_queue.alarm_name
  alarm_description   = "Weekly KPI collector failure queue contains messages"
  comparison_operator = local.alarm_configurations.failure_queue.comparison_operator
  evaluation_periods  = local.alarm_configurations.failure_queue.evaluation_periods
  threshold           = local.alarm_configurations.failure_queue.threshold
  metric_name         = local.alarm_configurations.failure_queue.metric_name
  namespace           = local.alarm_configurations.failure_queue.namespace
  period              = local.alarm_configurations.failure_queue.period
  statistic           = local.alarm_configurations.failure_queue.statistic
  dimensions          = local.alarm_configurations.failure_queue.dimensions
  treat_missing_data  = local.alarm_configurations.failure_queue.treat_missing_data
  alarm_actions       = local.alarm_configurations.failure_queue.alarm_actions

  tags = var.tags
}
