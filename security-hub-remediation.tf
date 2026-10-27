locals {
  enabled_security_hub_remediation_workflows = {
    for name, workflow in var.security_hub.remediation_workflows : name => workflow
    if workflow.enabled
  }
  security_hub_remediation_failure_metrics = {
    for pair in setproduct(keys(local.enabled_security_hub_remediation_workflows), ["ExecutionsFailed", "ExecutionsTimedOut", "ExecutionsAborted"]) :
    "${pair[0]}-${pair[1]}" => { workflow = pair[0], metric = pair[1] }
  }
  security_hub_remediation_delivery_metrics = {
    for pair in setproduct(keys(local.enabled_security_hub_remediation_workflows), ["finding", "failure"], ["InvocationsSentToDlq", "InvocationsFailedToBeSentToDlq"]) :
    "${pair[0]}-${pair[1]}-${pair[2]}" => {
      workflow  = pair[0]
      rule_name = pair[1] == "finding" ? aws_cloudwatch_event_rule.security_hub_remediation[pair[0]].name : aws_cloudwatch_event_rule.security_hub_remediation_failed[pair[0]].name
      metric    = pair[2]
    }
  }
}

# Security Hub sends each new and updated finding to EventBridge. The receiving
# state machine must revalidate its selected resource against this allowlist.
resource "aws_cloudwatch_event_rule" "security_hub_remediation" {
  for_each = local.enabled_security_hub_remediation_workflows

  name        = "${var.security_hub.name}-${each.key}-remediate"
  description = "Start approved ${each.key} corrective workflow for scoped Security Hub findings"
  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        RecordState  = ["ACTIVE"]
        Workflow     = { Status = ["NEW", "NOTIFIED"] }
        AwsAccountId = [data.aws_caller_identity.current.account_id]
        Compliance = {
          Status            = ["FAILED"]
          SecurityControlId = sort(tolist(each.value.security_control_ids))
        }
        Resources = { Id = sort(tolist(each.value.resource_ids)) }
      }
    }
  })

  lifecycle {
    precondition {
      condition = (
        var.alarm_actions.enabled &&
        (
          length(var.alarm_actions.email_addresses) +
          length(var.alarm_actions.phone_numbers) +
          length(var.alarm_actions.web_endpoints) +
          length(var.alarm_actions.lambda_arns) +
          length(var.alarm_actions.slack_webhooks) +
          length(var.alarm_actions.servicenow_webhooks) +
          length(var.alarm_actions.teams_webhooks)
        ) > 0 &&
        split(":", each.value.state_machine_arn)[3] == data.aws_region.current.name &&
        split(":", each.value.state_machine_arn)[4] == data.aws_caller_identity.current.account_id &&
        try(split(":", each.value.escalation_topic_arn)[3], "") == data.aws_region.current.name &&
        try(split(":", each.value.escalation_topic_arn)[4], "") == data.aws_caller_identity.current.account_id &&
        try(split(":", each.value.escalation_topic_arn)[5], "") != var.alarm_actions.topic_name &&
        try(each.value.escalation_topic_arn, "") != module.cloudwatch_alarm_actions[0].topic_arn
      )
      error_message = "Corrective workflows require an account notification channel, same-account/Region state machine, and a separate same-account/Region failure escalation topic."
    }
  }
}

resource "aws_iam_role" "security_hub_remediation_start" {
  for_each = local.enabled_security_hub_remediation_workflows

  name = "${var.security_hub.name}-${each.key}-eventbridge-start"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        ArnEquals    = { "aws:SourceArn" = aws_cloudwatch_event_rule.security_hub_remediation[each.key].arn }
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "security_hub_remediation_start" {
  for_each = local.enabled_security_hub_remediation_workflows

  name = "start-approved-workflow"
  role = aws_iam_role.security_hub_remediation_start[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = each.value.state_machine_arn
    }]
  })
}

# This queue catches failure to invoke the workflow and failure to notify about
# a later unsuccessful execution. Execution history remains in Step Functions.
resource "aws_sqs_queue" "security_hub_remediation_failed_delivery" {
  for_each = local.enabled_security_hub_remediation_workflows

  name                      = "${var.security_hub.name}-${each.key}-failed-delivery"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_cloudwatch_event_rule" "security_hub_remediation_failed" {
  for_each = local.enabled_security_hub_remediation_workflows

  name        = "${var.security_hub.name}-${each.key}-execution-failed"
  description = "Notify operators when approved ${each.key} corrective workflow fails"
  event_pattern = jsonencode({
    source        = ["aws.states"]
    "detail-type" = ["Step Functions Execution Status Change"]
    detail = {
      status          = ["FAILED", "TIMED_OUT", "ABORTED"]
      stateMachineArn = [each.value.state_machine_arn]
    }
  })
}

resource "aws_sqs_queue_policy" "security_hub_remediation_failed_delivery" {
  for_each = local.enabled_security_hub_remediation_workflows

  queue_url = aws_sqs_queue.security_hub_remediation_failed_delivery[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowScopedEventBridgeFailures"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.security_hub_remediation_failed_delivery[each.key].arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = [
            aws_cloudwatch_event_rule.security_hub_remediation[each.key].arn,
            aws_cloudwatch_event_rule.security_hub_remediation_failed[each.key].arn
          ]
        }
      }
    }]
  })
}

resource "aws_cloudwatch_event_target" "security_hub_remediation" {
  for_each = local.enabled_security_hub_remediation_workflows

  rule     = aws_cloudwatch_event_rule.security_hub_remediation[each.key].name
  arn      = each.value.state_machine_arn
  role_arn = aws_iam_role.security_hub_remediation_start[each.key].arn

  retry_policy {
    maximum_event_age_in_seconds = 86400
    maximum_retry_attempts       = 185
  }

  dead_letter_config {
    arn = aws_sqs_queue.security_hub_remediation_failed_delivery[each.key].arn
  }

  depends_on = [
    aws_iam_role_policy.security_hub_remediation_start,
    aws_sqs_queue_policy.security_hub_remediation_failed_delivery
  ]
}

resource "aws_cloudwatch_event_target" "security_hub_remediation_failed" {
  for_each = local.enabled_security_hub_remediation_workflows

  rule = aws_cloudwatch_event_rule.security_hub_remediation_failed[each.key].name
  arn  = module.cloudwatch_alarm_actions[0].topic_arn

  retry_policy {
    maximum_event_age_in_seconds = 86400
    maximum_retry_attempts       = 185
  }

  dead_letter_config {
    arn = aws_sqs_queue.security_hub_remediation_failed_delivery[each.key].arn
  }

  depends_on = [
    aws_sqs_queue_policy.security_hub_remediation_failed_delivery,
    module.cloudwatch_alarm_actions
  ]
}

resource "aws_cloudwatch_metric_alarm" "security_hub_remediation_execution_failed" {
  for_each = local.security_hub_remediation_failure_metrics

  alarm_name          = "${var.security_hub.name}-${each.value.workflow}-${each.value.metric}"
  alarm_description   = "Corrective workflow ${each.value.metric}; inspect Step Functions history"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 1
  metric_name         = each.value.metric
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  dimensions          = { StateMachineArn = local.enabled_security_hub_remediation_workflows[each.value.workflow].state_machine_arn }
  alarm_actions       = [local.enabled_security_hub_remediation_workflows[each.value.workflow].escalation_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "security_hub_remediation_queue_nonempty" {
  for_each = local.enabled_security_hub_remediation_workflows

  alarm_name          = "${var.security_hub.name}-${each.key}-failed-delivery-queued"
  alarm_description   = "${each.value.owner} investigates and replays corrective delivery failures; ${each.value.runbook_url}."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.security_hub_remediation_failed_delivery[each.key].name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [each.value.escalation_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "security_hub_remediation_delivery_metric" {
  for_each = local.security_hub_remediation_delivery_metrics

  alarm_name          = "${var.security_hub.name}-${each.key}"
  alarm_description   = "${local.enabled_security_hub_remediation_workflows[each.value.workflow].owner} investigates ${each.value.metric}; ${local.enabled_security_hub_remediation_workflows[each.value.workflow].runbook_url}."
  namespace           = "AWS/Events"
  metric_name         = each.value.metric
  dimensions          = { RuleName = each.value.rule_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.enabled_security_hub_remediation_workflows[each.value.workflow].escalation_topic_arn]
}
