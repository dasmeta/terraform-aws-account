module "account-events-export" {
  source = "./modules/account-events-export"

  count = var.account_events_export.enabled ? 1 : 0

  webhook_endpoint = var.account_events_export.webhook_endpoint
  name             = var.account_events_export.name
  eventBridgeBus   = var.account_events_export.eventBridgeBus
}
