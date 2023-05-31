module "monitoring_billing" {
  source  = "dasmeta/monitoring/aws//modules/billing"
  version = "1.5.7"

  count = var.alarm_actions.enabled && var.alarm_actions.billing_alarm.enabled ? 1 : 0

  name              = var.alarm_actions.billing_alarm.name
  limit_amount      = var.alarm_actions.billing_alarm.limit_amount
  limit_unit        = var.alarm_actions.billing_alarm.limit_unit
  time_unit         = var.alarm_actions.billing_alarm.time_unit
  time_period_start = var.alarm_actions.billing_alarm.time_period_start
  time_period_end   = var.alarm_actions.billing_alarm.time_period_end

  threshold           = var.alarm_actions.billing_alarm.threshold
  threshold_type      = var.alarm_actions.billing_alarm.threshold_type
  comparison_operator = var.alarm_actions.billing_alarm.comparison_operator
  notification_type   = var.alarm_actions.billing_alarm.notification_type

  sns_topic_arns         = [module.cloudwatch_alarm_actions[0].topic_arn]
  notify_email_addresses = var.alarm_actions.billing_alarm.notify_email_addresses
}
