module "account_events_export" {
  source = "./modules/account-events-export"

  count = var.account_events_export.enabled ? 1 : 0

  webhook_endpoint  = var.account_events_export.webhook_endpoint
  name              = var.account_events_export.name
  event_bridge_bus  = var.account_events_export.event_bridge_bus
  delivery          = var.account_events_export.delivery
  dlq_alarm_actions = var.alarm_actions.enabled ? [module.cloudwatch_alarm_actions[0].topic_arn] : []
}

module "account_events_export_virginia" {
  source = "./modules/account-events-export"

  count = var.account_events_export.enabled ? 1 : 0

  webhook_endpoint  = var.account_events_export.webhook_endpoint
  name              = "${var.account_events_export.name}-virginia"
  event_bridge_bus  = var.account_events_export.event_bridge_bus
  delivery          = var.account_events_export.delivery
  dlq_alarm_actions = var.alarm_actions_virginia.enabled ? [module.cloudwatch_alarm_actions_virginia[0].topic_arn] : []

  providers = {
    aws = aws.virginia
  }
}
