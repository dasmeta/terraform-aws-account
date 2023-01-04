module "monitoring_billing" {
  source  = "dasmeta/monitoring/aws//modules/billing"
  version = "1.3.8"

  count = var.billing_alarm.enabled ? 1 : 0

  name                = var.billing_alarm.name
  limit_amount        = var.billing_alarm.limit_amount
  limit_unit          = var.billing_alarm.limit_unit
  time_unit           = var.billing_alarm.time_unit
  sns_subscription    = var.billing_alarm.sns_subscription
  metric_name         = var.billing_alarm.metric_name
  alarm_name          = var.billing_alarm.alarm_name
  threshold           = var.billing_alarm.threshold
  threshold_type      = var.billing_alarm.threshold_type
  comparison_operator = var.billing_alarm.comparison_operator
}
