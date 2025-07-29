module "account_events_export" {
  source = "./modules/account-events-export"

  count = var.account_events_export.enabled ? 1 : 0

  webhook_endpoint = var.account_events_export.webhook_endpoint
  name             = var.account_events_export.name
  event_bridge_bus = var.account_events_export.event_bridge_bus
}

module "account_events_export_virginia" {
  source = "./modules/account-events-export"

  count = var.account_events_export.enabled ? 1 : 0

  webhook_endpoint = var.account_events_export.webhook_endpoint
  name             = "${var.account_events_export.name}-virginia"
  event_bridge_bus = var.account_events_export.event_bridge_bus

  providers = {
    aws = aws.virginia
  }
}
