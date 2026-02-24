module "cloudwatch_alarm_actions" {
  source  = "dasmeta/monitoring/aws//modules/cloudwatch-alarm-actions"
  version = "1.21.0"

  count = var.alarm_actions.enabled ? 1 : 0

  topic_name               = var.alarm_actions.topic_name
  email_addresses          = var.alarm_actions.email_addresses
  phone_numbers            = var.alarm_actions.phone_numbers
  web_endpoints            = var.alarm_actions.web_endpoints
  lambda_arns              = var.alarm_actions.lambda_arns
  slack_webhooks           = var.alarm_actions.slack_webhooks
  servicenow_webhooks      = var.alarm_actions.servicenow_webhooks
  teams_webhooks           = var.alarm_actions.teams_webhooks
  enable_dead_letter_queue = var.alarm_actions.enable_dead_letter_queue
  policy                   = local.sns_access_policy
  log_group_retention_days = var.alarm_actions.log_group_retention_days
}

# TODO: it seems we can combine alarm_actions_virginia into alarm_actions so that we will have one source of config, as we usually have same channels for alarm in both primary and virginia regions
module "cloudwatch_alarm_actions_virginia" {
  source  = "dasmeta/monitoring/aws//modules/cloudwatch-alarm-actions"
  version = "1.21.0"

  count = var.alarm_actions_virginia.enabled ? 1 : 0

  topic_name               = "${var.alarm_actions_virginia.topic_name}-virginia"
  email_addresses          = var.alarm_actions_virginia.email_addresses
  phone_numbers            = var.alarm_actions_virginia.phone_numbers
  web_endpoints            = var.alarm_actions_virginia.web_endpoints
  lambda_arns              = var.alarm_actions_virginia.lambda_arns
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
