locals {
  enabled_security_hub_remediation_workflows = {
    for name, workflow in var.security_hub.remediation_workflows : name => workflow
    if workflow.enabled
  }
  security_hub_remediation_failure_metrics = {
    for pair in setproduct(keys(local.enabled_security_hub_remediation_workflows), ["ExecutionsFailed", "ExecutionsTimedOut", "ExecutionsAborted"]) :
    "${pair[0]}-${pair[1]}" => { workflow = pair[0], metric = pair[1] }
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
        split(":", each.value.state_machine_arn)[4] == data.aws_caller_identity.current.account_id
      )
      error_message = "Corrective workflows require an account notification channel and a state machine in the active AWS account and Region."
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
  alarm_actions       = [module.cloudwatch_alarm_actions[0].topic_arn]
}
