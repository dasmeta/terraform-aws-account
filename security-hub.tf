module "monitoring_security_hub" {
  # source  = "dasmeta/monitoring/aws//modules/security-hub/"
  # version = "1.19.5"
  source = "git::https://github.com/dasmeta/terraform-aws-monitoring.git//modules/security-hub?ref=DMVP-4582"

  count = var.alarm_actions.security_hub_alarms.enabled ? 1 : 0

  name                         = var.alarm_actions.security_hub_alarms.sns_topic_name
  create_slack_target          = var.alarm_actions.security_hub_alarms.create_slack_target
  create_teams_target          = var.alarm_actions.security_hub_alarms.create_teams_target
  sns_email_subscription       = var.alarm_actions.security_hub_alarms.sns_email_subscription
  sns_opsgenie_subscription    = var.alarm_actions.security_hub_alarms.opsgenie_webhook
  create_sns_target            = var.alarm_actions.security_hub_alarms.create_sns_target
  lambda_environment_variables = var.alarm_actions.security_hub_alarms.lambda_environment_variables

  link_mode                              = var.alarm_actions.security_hub_alarms.link_mode
  enable_security_hub                    = var.alarm_actions.security_hub_alarms.enable_security_hub
  enable_security_hub_finding_aggregator = var.alarm_actions.security_hub_alarms.enable_security_hub_finding_aggregator
}
