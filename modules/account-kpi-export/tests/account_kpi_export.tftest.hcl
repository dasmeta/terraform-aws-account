# Mock computed identifiers while keeping every upstream module resource in the graph.
mock_provider "aws" {
  override_during = plan

  mock_resource "aws_lambda_function" {
    defaults = {
      arn           = "arn:aws:lambda:eu-central-1:111122223333:function:account-kpi-export"
      qualified_arn = "arn:aws:lambda:eu-central-1:111122223333:function:account-kpi-export:1"
      version       = "1"
    }
  }

  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:eu-central-1:111122223333:account-kpi-export-failures"
      url = "https://sqs.eu-central-1.amazonaws.com/111122223333/account-kpi-export-failures"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/example-kpi-role"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::111122223333:policy/example-kpi-policy"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:root"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name   = "eu-central-1"
      region = "eu-central-1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

}

mock_provider "external" {}
mock_provider "local" {}
mock_provider "null" {}

mock_provider "aws" {
  alias = "state"

  # Apply-time mocks retain configured IAM document statements in verbose test state.

  mock_resource "aws_lambda_function" {
    defaults = {
      arn           = "arn:aws:lambda:eu-central-1:111122223333:function:account-kpi-export"
      qualified_arn = "arn:aws:lambda:eu-central-1:111122223333:function:account-kpi-export:1"
      version       = "1"
    }
  }

  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:eu-central-1:111122223333:account-kpi-export-failures"
      url = "https://sqs.eu-central-1.amazonaws.com/111122223333/account-kpi-export-failures"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/example-kpi-role"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::111122223333:policy/example-kpi-policy"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:root"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name   = "eu-central-1"
      region = "eu-central-1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

}

variables {
  cloudbrowser = {
    client_id  = 42
    secret_arn = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
  }
}

# Mark only computed policy JSON so the checker can prove that each configured
# document is attached to its role; statement inputs remain visible in test state.
override_data {
  target = module.lambda_function.data.aws_iam_policy_document.additional_inline[0]
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Id\":\"mock-lambda-kpi-additional\",\"Statement\":[]}"
  }
}

override_data {
  target = module.scheduler.data.aws_iam_policy_document.additional_inline[0]
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Id\":\"mock-scheduler-kpi-additional\",\"Statement\":[]}"
  }
}

run "aws_only_contract" {
  command = plan

  assert {
    condition = local.lambda_configuration == {
      handler                                   = "handler.lambda_handler"
      runtime                                   = "python3.13"
      timeout                                   = 600
      memory_size                               = 256
      reserved_concurrent_executions            = 1
      cloudwatch_logs_retention_days            = 30
      create_package                            = false
      publish                                   = false
      create_async_event_config                 = true
      create_current_version_async_event_config = false
      maximum_event_age_in_seconds              = 21600
      maximum_retry_attempts                    = 2
      attach_async_event_policy                 = false
      vpc_subnet_ids                            = []
      vpc_security_group_ids                    = []
    }
    error_message = "The collector Lambda must use the fixed runtime, package, unqualified async retry, and one reserved execution."
  }

  assert {
    condition     = length(local.scheduler_schedules) == 1 && contains(keys(local.scheduler_schedules), local.wednesday_schedule_name)
    error_message = "AWS-only collection must create exactly the Wednesday schedule."
  }

  assert {
    condition = (
      module.scheduler.eventbridge_schedules[local.wednesday_schedule_name].name == local.wednesday_schedule_name &&
      module.scheduler.eventbridge_schedules[local.wednesday_schedule_name].target[0].input == jsonencode({ job = "aws" }) &&
      module.scheduler.eventbridge_schedules[local.wednesday_schedule_name].schedule_expression_timezone == "Asia/Yerevan" &&
      module.scheduler.eventbridge_schedules[local.wednesday_schedule_name].target[0].retry_policy[0].maximum_retry_attempts == 2 &&
      module.scheduler.eventbridge_schedules[local.wednesday_schedule_name].target[0].dead_letter_config[0].arn == module.failure_queue.queue_arn
    )
    error_message = "The upstream Scheduler resource must preserve the configured name, payload, timezone, retry, and DLQ."
  }

  assert {
    condition = (
      local.scheduler_schedules[local.wednesday_schedule_name].arn == module.lambda_function.lambda_function_arn &&
      local.scheduler_schedules[local.wednesday_schedule_name].input == jsonencode({ job = "aws" }) &&
      local.scheduler_schedules[local.wednesday_schedule_name].timezone == "Asia/Yerevan" &&
      local.scheduler_schedules[local.wednesday_schedule_name].schedule_expression == "cron(0 6 ? * WED *)" &&
      local.scheduler_schedules[local.wednesday_schedule_name].retry_policy.maximum_event_age_in_seconds == 86400 &&
      local.scheduler_schedules[local.wednesday_schedule_name].retry_policy.maximum_retry_attempts == 2 &&
      local.scheduler_schedules[local.wednesday_schedule_name].dead_letter_arn == module.failure_queue.queue_arn
    )
    error_message = "The Wednesday target must use the shared Lambda, literal payload, timezone, delivery retry policy, and DLQ."
  }

  assert {
    condition = local.lambda_policy_statements.secret == {
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [var.cloudbrowser.secret_arn]
    }
    error_message = "The Lambda secret permission must be limited to GetSecretValue on the configured ARN."
  }

  assert {
    condition = (
      local.lambda_policy_statements.cost.actions == ["ce:GetCostAndUsage"] &&
      local.lambda_policy_statements.cost.resources == ["*"] &&
      local.lambda_policy_statements.security.actions == ["securityhub:GetEnabledStandards", "securityhub:GetFindings"] &&
      local.lambda_policy_statements.security.resources == ["*"] &&
      local.lambda_policy_statements.failure_queue.actions == ["sqs:SendMessage"] &&
      local.lambda_policy_statements.failure_queue.resources == [module.failure_queue.queue_arn]
    )
    error_message = "AWS reads and Lambda failure delivery must use only their exact actions and resources."
  }

  assert {
    condition = (
      length(local.scheduler_policy_statements) == 2 &&
      local.scheduler_policy_statements.invoke.actions == ["lambda:InvokeFunction"] &&
      local.scheduler_policy_statements.invoke.resources == [module.lambda_function.lambda_function_arn] &&
      local.scheduler_policy_statements.failure_queue.actions == ["sqs:SendMessage"] &&
      local.scheduler_policy_statements.failure_queue.resources == [module.failure_queue.queue_arn]
    )
    error_message = "The Scheduler role must have exact Lambda invoke and failure-queue send permissions."
  }

  assert {
    condition = (
      local.failure_queue_configuration.sqs_managed_sse_enabled &&
      local.async_event_configuration.destination_on_failure == module.failure_queue.queue_arn &&
      local.async_event_configuration.maximum_event_age_in_seconds == 21600 &&
      local.async_event_configuration.maximum_retry_attempts == 2
    )
    error_message = "The shared queue must be encrypted and receive exhausted unqualified Lambda events."
  }

  assert {
    condition = (
      local.alarm_configurations.lambda_errors.metric_name == "Errors" &&
      local.alarm_configurations.failure_queue.metric_name == "ApproximateNumberOfMessagesVisible" &&
      length(local.alarm_configurations.lambda_errors.alarm_actions) == 0 &&
      length(local.alarm_configurations.failure_queue.alarm_actions) == 0
    )
    error_message = "The module must configure focused Lambda error and visible failure-queue alarms."
  }

  assert {
    condition = (
      output.lambda_function_arn == module.lambda_function.lambda_function_arn &&
      output.failure_queue_arn == module.failure_queue.queue_arn &&
      length(output.schedule_arns) == 1 &&
      length(output.alarm_arns) == 2
    )
    error_message = "Operational outputs must expose one Lambda, one queue, enabled schedules, and both alarms."
  }

  assert {
    condition = (
      jsondecode(local.config_json).timezone == "Asia/Yerevan" &&
      jsondecode(local.config_json).cloudbrowser == {
        base_url        = "https://app.dasmeta.com"
        client_id       = 42
        aws_provider_id = 1
        token_key       = "cloudbrowser_api_token"
      } &&
      jsondecode(local.config_json).metrics == {
        cost     = 12
        security = 4
        uptime   = 24
        latency  = 26
      } &&
      replace(local.config_json, "runtime-value", "") == local.config_json
    )
    error_message = "CONFIG_JSON must match the handler contract and contain key names without token values."
  }
}

run "application_only_contract" {
  command = plan

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      latency_query  = "avg_over_time(request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)"
    }
    cost = {
      enabled = false
    }
    security = {
      enabled = false
      region  = "eu-central-1"
    }
  }

  assert {
    condition     = length(local.scheduler_schedules) == 1 && contains(keys(local.scheduler_schedules), local.monday_schedule_name)
    error_message = "Application-only collection must create exactly the Monday schedule."
  }

  assert {
    condition = (
      local.scheduler_schedules[local.monday_schedule_name].arn == module.lambda_function.lambda_function_arn &&
      local.scheduler_schedules[local.monday_schedule_name].input == jsonencode({ job = "application" }) &&
      local.scheduler_schedules[local.monday_schedule_name].timezone == "Asia/Yerevan" &&
      local.scheduler_schedules[local.monday_schedule_name].schedule_expression == "cron(0 6 ? * MON *)" &&
      local.scheduler_schedules[local.monday_schedule_name].retry_policy.maximum_event_age_in_seconds == 86400 &&
      local.scheduler_schedules[local.monday_schedule_name].retry_policy.maximum_retry_attempts == 2 &&
      local.scheduler_schedules[local.monday_schedule_name].dead_letter_arn == module.failure_queue.queue_arn
    )
    error_message = "The Monday target must use the shared Lambda, literal payload, timezone, delivery retry policy, and DLQ."
  }

  assert {
    condition = (
      !contains(keys(local.lambda_policy_statements), "cost") &&
      !contains(keys(local.lambda_policy_statements), "security") &&
      local.lambda_policy_statements.secret.resources == [var.cloudbrowser.secret_arn] &&
      local.lambda_policy_statements.failure_queue.actions == ["sqs:SendMessage"]
    )
    error_message = "Application-only collection must omit Cost Explorer and Security Hub IAM reads."
  }

  assert {
    condition = jsondecode(local.config_json).application == {
      enabled        = true
      source_type    = "prometheus"
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      latency_query  = "avg_over_time(request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      token_key      = "grafana_api_token"
    }
    error_message = "Enabled application settings must be serialized exactly for the handler."
  }
}

run "canonical_nginx_application_contract" {
  command = plan

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      query_profile  = "nginx_ingress"
      metric_filter  = " namespace=\"production\", ingress=~\"api|web\" "
    }
    cost = {
      enabled = false
    }
    security = {
      enabled = false
    }
  }

  assert {
    condition = jsondecode(local.config_json).application == {
      enabled        = true
      source_type    = "prometheus"
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      uptime_query   = "100 * sum(increase(nginx_ingress_controller_requests{status!~\"5..\", namespace=\"production\", ingress=~\"api|web\"}[$__account_kpi_window] @ $__account_kpi_end_seconds)) / sum(increase(nginx_ingress_controller_requests{namespace=\"production\", ingress=~\"api|web\"}[$__account_kpi_window] @ $__account_kpi_end_seconds))"
      latency_query  = "sum(increase(nginx_ingress_controller_request_duration_seconds_sum{status=~\"2..|3..\", namespace=\"production\", ingress=~\"api|web\"}[$__account_kpi_window] @ $__account_kpi_end_seconds)) / sum(increase(nginx_ingress_controller_request_duration_seconds_count{status=~\"2..|3..\", namespace=\"production\", ingress=~\"api|web\"}[$__account_kpi_window] @ $__account_kpi_end_seconds))"
      token_key      = "grafana_api_token"
    }
    error_message = "Canonical NGINX settings must serialize the exact uptime and weighted average-latency queries for the handler."
  }
}

run "application_rejects_metric_filter_without_query_profile" {
  command = plan

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      metric_filter  = "namespace=\"production\""
    }
  }

  expect_failures = [var.application]
}

run "application_rejects_unknown_query_profile" {
  command = plan

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      query_profile  = "unknown"
      metric_filter  = "namespace=\"production\""
    }
  }

  expect_failures = [var.application]
}

run "application_rejects_query_profile_with_raw_queries" {
  command = plan

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      query_profile  = "nginx_ingress"
      metric_filter  = "namespace=\"production\""
      uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      latency_query  = "avg_over_time(request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)"
    }
  }

  expect_failures = [var.application]
}

run "cloudwatch_alb_application_contract" {
  command = plan

  variables {
    application = {
      enabled        = true
      source_type    = "cloudwatch_alb"
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "cloudwatch"
      region         = "eu-central-1"
      load_balancer  = "app/example/123"
    }
    cost = {
      enabled = false
    }
    security = {
      enabled = false
    }
  }

  assert {
    condition = jsondecode(local.config_json).application == {
      enabled        = true
      source_type    = "cloudwatch_alb"
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "cloudwatch"
      region         = "eu-central-1"
      load_balancer  = "app/example/123"
      token_key      = "grafana_api_token"
    }
    error_message = "CloudWatch ALB settings must be serialized exactly for the handler."
  }
}

run "cloudwatch_alb_application_requires_complete_settings" {
  command = plan

  variables {
    application = {
      enabled        = true
      source_type    = "cloudwatch_alb"
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "cloudwatch"
    }
  }

  expect_failures = [var.application]
}

run "application_rejects_unknown_source_type" {
  command = plan

  variables {
    application = {
      enabled        = true
      source_type    = "unknown"
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example"
    }
  }

  expect_failures = [var.application]
}

run "application_and_aws_contract" {
  command = plan

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      latency_query  = "avg_over_time(request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)"
    }
    lambda = {
      alarm_action_arns = ["arn:aws:sns:eu-central-1:111122223333:example-kpi-alarms"]
    }
  }

  assert {
    condition = (
      length(module.scheduler.eventbridge_schedules) == 2 &&
      module.scheduler.eventbridge_schedules[local.monday_schedule_name].target[0].arn == module.lambda_function.lambda_function_arn &&
      module.scheduler.eventbridge_schedules[local.wednesday_schedule_name].target[0].arn == module.lambda_function.lambda_function_arn &&
      module.scheduler.eventbridge_schedules[local.monday_schedule_name].target[0].input == jsonencode({ job = "application" }) &&
      module.scheduler.eventbridge_schedules[local.wednesday_schedule_name].target[0].input == jsonencode({ job = "aws" })
    )
    error_message = "Application plus AWS collection must plan exactly Monday and Wednesday, sharing one Lambda with literal job-only payloads."
  }
}

run "application_requires_complete_settings" {
  command = plan

  variables {
    application = {
      enabled = true
    }
  }

  expect_failures = [var.application]
}

run "application_rejects_partial_query_boundaries" {
  command = plan

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      uptime_query   = "sum(up[$__account_kpi_start_seconds])"
      latency_query  = "sum(rate(request_duration_seconds_sum[7d]))"
    }
  }

  expect_failures = [var.application]
}

run "application_rejects_one_query_even_with_metric_filter" {
  command = plan

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      metric_filter  = "namespace=\"production\""
      uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
    }
  }

  expect_failures = [var.application]
}

run "rejects_insecure_cloudbrowser_base_url" {
  command = plan

  variables {
    cloudbrowser = {
      base_url   = "http://cloudbrowser.example"
      client_id  = 42
      secret_arn = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
    }
  }

  expect_failures = [var.cloudbrowser]
}

run "application_rejects_insecure_grafana_base_url" {
  command = plan

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://token@grafana.example"
      datasource_uid = "example-prometheus"
      uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      latency_query  = "avg_over_time(request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)"
    }
  }

  expect_failures = [var.application]
}

run "requires_an_enabled_source" {
  command = plan

  variables {
    cost = {
      enabled = false
    }
    security = {
      enabled = false
    }
  }

  expect_failures = [data.aws_partition.current]
}

run "rejects_invalid_bounds" {
  command = plan

  variables {
    metrics = {
      cost = 0
    }
    schedules = {
      timezone                              = ""
      delivery_maximum_event_age_in_seconds = 59
      delivery_maximum_retry_attempts       = 186
    }
    lambda = {
      timeout                            = 0
      memory_size                        = 127
      logs_retention_in_days             = 0
      async_maximum_event_age_in_seconds = 59
      async_maximum_retry_attempts       = 3
    }
  }

  expect_failures = [var.metrics, var.schedules, var.lambda]
}

run "rejects_name_that_exceeds_derived_resource_bounds" {
  command = plan

  variables {
    lambda = {
      name = "example-account-kpi-export-name-with-fifty-five-characters"
    }
  }

  expect_failures = [var.lambda]
}

# Mocked applies expose nested policy-document inputs in Terraform's test JSON.
# Only computed ARN/JSON values are stubbed; module resource arguments remain real.
run "infrastructure_contract_state" {
  command = apply

  providers = {
    aws = aws.state
  }

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      latency_query  = "avg_over_time(request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)"
    }
    lambda = {
      alarm_action_arns = ["arn:aws:sns:eu-central-1:111122223333:example-kpi-alarms"]
    }
  }

  assert {
    condition     = length(module.scheduler.eventbridge_schedules) == 2
    error_message = "The mocked full infrastructure state must retain both schedules."
  }
}

run "application_only_infrastructure_state" {
  command = apply

  providers = {
    aws = aws.state
  }

  variables {
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      latency_query  = "avg_over_time(request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)"
    }
    cost = {
      enabled = false
    }
    security = {
      enabled = false
    }
  }

  assert {
    condition     = length(module.scheduler.eventbridge_schedules) == 1
    error_message = "The mocked application-only infrastructure state must retain only Monday."
  }
}
