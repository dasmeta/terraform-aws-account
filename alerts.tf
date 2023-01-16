module "alerts" {
  source  = "dasmeta/monitoring/aws//modules/alerts"
  version = "1.3.8"

  count = var.alarm_actions.enabled ? 1 : 0

  sns_topic = var.alarm_actions.topic_name
  alerts    = var.alerts
}
