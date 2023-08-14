module "cloudwatch_alarm_actions" {
  source  = "dasmeta/monitoring/aws//modules/cloudwatch-alarm-actions"
  version = "1.5.6"

  count = var.alarm_actions.enabled ? 1 : 0

  topic_name          = var.alarm_actions.topic_name
  email_addresses     = var.alarm_actions.email_addresses
  phone_numbers       = var.alarm_actions.phone_numbers
  web_endpoints       = var.alarm_actions.web_endpoints
  slack_webhooks      = var.alarm_actions.slack_webhooks
  servicenow_webhooks = var.alarm_actions.servicenow_webhooks
  teams_webhooks      = var.alarm_actions.teams_webhooks
}

module "cloudwatch_alarm_actions_virginia" {
  source  = "dasmeta/monitoring/aws//modules/cloudwatch-alarm-actions"
  version = "1.5.6"

  count = var.alarm_actions.enabled ? 1 : 0

  topic_name          = "${var.alarm_actions.topic_name}-virginia"
  email_addresses     = var.alarm_actions.email_addresses
  phone_numbers       = var.alarm_actions.phone_numbers
  web_endpoints       = var.alarm_actions.web_endpoints
  slack_webhooks      = var.alarm_actions.slack_webhooks
  servicenow_webhooks = var.alarm_actions.servicenow_webhooks
  teams_webhooks      = var.alarm_actions.teams_webhooks

  providers = {
    aws = aws.virginia
  }
}
