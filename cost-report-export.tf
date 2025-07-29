module "cost_report_export" {
  source = "./modules/cost-report-export"

  count = var.cost_report_export.enabled ? 1 : 0

  webhook_endpoint       = var.cost_report_export.webhook_endpoint
  name                   = var.cost_report_export.name
  event_bridge_bus       = var.cost_report_export.event_bridge_bus
  logs_retention_in_days = var.cost_report_export.logs_retention_in_days
}
