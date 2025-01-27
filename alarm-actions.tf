module "cloudwatch_alarm_actions" {
  source  = "dasmeta/monitoring/aws//modules/cloudwatch-alarm-actions"
  version = "1.19.5"

  count = var.alarm_actions.enabled ? 1 : 0

  topic_name               = var.alarm_actions.topic_name
  email_addresses          = var.alarm_actions.email_addresses
  phone_numbers            = var.alarm_actions.phone_numbers
  web_endpoints            = var.alarm_actions.web_endpoints
  slack_webhooks           = var.alarm_actions.slack_webhooks
  servicenow_webhooks      = var.alarm_actions.servicenow_webhooks
  teams_webhooks           = var.alarm_actions.teams_webhooks
  enable_dead_letter_queue = var.alarm_actions.enable_dead_letter_queue
  policy                   = local.sns_access_policy
  log_group_retention_days = var.alarm_actions.log_group_retention_days
}

module "cloudwatch_alarm_actions_virginia" {
  source  = "dasmeta/monitoring/aws//modules/cloudwatch-alarm-actions"
  version = "1.19.5"

  count = var.alarm_actions_virginia.enabled ? 1 : 0

  topic_name               = "${var.alarm_actions_virginia.topic_name}-virginia"
  email_addresses          = var.alarm_actions_virginia.email_addresses
  phone_numbers            = var.alarm_actions_virginia.phone_numbers
  web_endpoints            = var.alarm_actions_virginia.web_endpoints
  slack_webhooks           = var.alarm_actions_virginia.slack_webhooks
  servicenow_webhooks      = var.alarm_actions_virginia.servicenow_webhooks
  teams_webhooks           = var.alarm_actions_virginia.teams_webhooks
  enable_dead_letter_queue = var.alarm_actions_virginia.enable_dead_letter_queue
  policy                   = local.sns_access_policy_virginia
  log_group_retention_days = var.alarm_actions_virginia.log_group_retention_days

  providers = {
    aws = aws.virginia
  }
}
