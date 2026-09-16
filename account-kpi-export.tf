module "account_kpi_export" {
  source = "./modules/account-kpi-export"

  count = var.account_kpi_export.enabled ? 1 : 0

  cloudbrowser = var.account_kpi_export.cloudbrowser
  application  = var.account_kpi_export.application
  cost         = var.account_kpi_export.cost
  security     = var.account_kpi_export.security
  metrics      = var.account_kpi_export.metrics
  schedules    = var.account_kpi_export.schedules
  lambda = merge(var.account_kpi_export.lambda, {
    alarm_action_arns = distinct(concat(
      var.account_kpi_export.lambda.alarm_action_arns,
      var.alarm_actions.enabled ? [module.cloudwatch_alarm_actions[0].topic_arn] : []
    ))
  })
}
