module "monitoring_billing" {
  source  = "dasmeta/monitoring/aws//modules/billing"
  version = "0.2.1"

  name                 = var.billing-name
  account_budget_limit = var.account_budget_limit
  limit_unit           = var.limit_unit
  time_unit            = var.time_unit

  sns_subscription_email_address_list = var.sns_subscription_email_address_list
  sns_subscription_phone_number_list  = var.sns_subscription_phone_number_list
  opsgenie_endpoint                   = var.opsgenie_endpoint
  slack_hook_url                      = var.slack_hook_url
  metric_name                         = var.metric_name
  alarm_name                          = var.alarm_name
  threshold                           = var.threshold
  comparison_operator                 = var.comparison_operator
}
