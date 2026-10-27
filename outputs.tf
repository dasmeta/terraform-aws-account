output "users" {
  description = "created users data"
  value = {
    for user in values(module.users) : user.iam_user_name => {
      arn                         = user.iam_user_arn
      password_encrypted          = user.iam_user_login_profile_encrypted_password
      access_key_id               = user.iam_access_key_id
      secret_access_key_encrypted = user.iam_access_key_secret
    }
  }
  sensitive = true
}

output "account_kpi_export" {
  description = "Operational Lambda, schedule, failure queue, and alarm identifiers; null when the weekly KPI exporter is disabled."
  value = var.account_kpi_export.enabled ? {
    lambda_function_arn  = module.account_kpi_export[0].lambda_function_arn
    lambda_function_name = module.account_kpi_export[0].lambda_function_name
    schedule_arns        = module.account_kpi_export[0].schedule_arns
    failure_queue_arn    = module.account_kpi_export[0].failure_queue_arn
    failure_queue_url    = module.account_kpi_export[0].failure_queue_url
    alarm_arns           = module.account_kpi_export[0].alarm_arns
  } : null
}

output "account_events_export" {
  description = "Regional account event export queue and terminal-failure queue identifiers"
  value = var.account_events_export.enabled ? {
    primary = {
      event_queue        = module.account_events_export[0].event_queue_data
      failed_event_queue = module.account_events_export[0].failed_event_queue_data
      alarm_arns         = module.account_events_export[0].alarm_arns
    }
    virginia = {
      event_queue        = module.account_events_export_virginia[0].event_queue_data
      failed_event_queue = module.account_events_export_virginia[0].failed_event_queue_data
      alarm_arns         = module.account_events_export_virginia[0].alarm_arns
    }
  } : null
}

output "security_hub_remediation_routes" {
  description = "Configured corrective route and failed-delivery identifiers; does not prove successful correction"
  value = {
    for name, workflow in local.enabled_security_hub_remediation_workflows : name => {
      finding_rule_arn          = aws_cloudwatch_event_rule.security_hub_remediation[name].arn
      failed_execution_rule_arn = aws_cloudwatch_event_rule.security_hub_remediation_failed[name].arn
      state_machine_arn         = workflow.state_machine_arn
      failed_delivery_queue_arn = aws_sqs_queue.security_hub_remediation_failed_delivery[name].arn
      failed_delivery_queue_url = aws_sqs_queue.security_hub_remediation_failed_delivery[name].url
      execution_failure_alarm_arns = {
        for metric in ["ExecutionsFailed", "ExecutionsTimedOut", "ExecutionsAborted"] :
        metric => aws_cloudwatch_metric_alarm.security_hub_remediation_execution_failed["${name}-${metric}"].arn
      }
      delivery_failure_alarm_arns = merge(
        { queue_nonempty = aws_cloudwatch_metric_alarm.security_hub_remediation_queue_nonempty[name].arn },
        {
          for pair in setproduct(["finding", "failure"], ["InvocationsSentToDlq", "InvocationsFailedToBeSentToDlq"]) :
          "${pair[0]}-${pair[1]}" => aws_cloudwatch_metric_alarm.security_hub_remediation_delivery_metric["${name}-${pair[0]}-${pair[1]}"].arn
        }
      )
      escalation_topic_arn = workflow.escalation_topic_arn
      owner                = workflow.owner
      runbook_url          = workflow.runbook_url
      safety               = workflow.safety
    }
  }
}

output "security_hub_alerting_route" {
  description = "Configured automatic finding route and topic name; live delivery and acknowledgement require separate evidence"
  value = var.security_hub.enabled ? {
    enabled                     = var.alarm_actions.enabled && var.alarm_actions.security_hub_alarms.enabled
    notification_topic_name     = local.security_hub_notification_topic_name
    reuses_account_topic        = local.security_hub_reuses_account_topic
    automatic_eventbridge_rule  = module.monitoring_security_hub[0].eventbridge_rule_arn
    manual_action_target_arn    = module.monitoring_security_hub[0].security_hub_action_target_arn
    manual_eventbridge_rule_arn = module.monitoring_security_hub[0].manual_eventbridge_rule_arn
    failed_delivery_queue_arn   = module.monitoring_security_hub[0].eventbridge_failed_delivery_queue_arn
    failed_delivery_queue_url   = module.monitoring_security_hub[0].eventbridge_failed_delivery_queue_url
    failed_delivery_alarm_arns  = module.monitoring_security_hub[0].eventbridge_failed_delivery_alarm_arns
    failure_response            = module.monitoring_security_hub[0].delivery_failure_response
  } : null
}
