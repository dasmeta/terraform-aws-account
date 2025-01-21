module "monitoring_security_hub" {
  source  = "dasmeta/monitoring/aws//modules/security-hub"
  version = "1.19.5"

  name = "account-security-hub-bridge"

  count = var.alarm_actions.security_hub_alarms.enabled ? 1 : 0

  create_sns_target                      = true
  sns_opsgenie_subscription              = var.alarm_actions.security_hub_alarms.opsgenie_webhook
  enable_security_hub                    = var.alarm_actions.security_hub_alarms.enable_security_hub
  enable_security_hub_finding_aggregator = var.alarm_actions.security_hub_alarms.enable_security_hub_finding_aggregator
}
