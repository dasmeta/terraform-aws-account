module "monitoring_security_hub" {
  source  = "dasmeta/monitoring/aws//modules/aws-security-hub-opsgenie"
  version = "1.5.2"


  count = var.alarm_actions.security_hub_alarms.enabled ? 1 : 0

  opsgenie_webhook                       = var.alarm_actions.security_hub_alarms.opsgenie_webhook
  securityhub_action_target_name         = var.alarm_actions.security_hub_alarms.securityhub_action_target_name
  sns_topic_name                         = var.alarm_actions.security_hub_alarms.sns_topic_name
  protocol                               = var.alarm_actions.security_hub_alarms.protocol
  link_mode                              = var.alarm_actions.security_hub_alarms.link_mode
  enable_security_hub                    = var.alarm_actions.security_hub_alarms.enable_security_hub
  enable_security_hub_finding_aggregator = var.alarm_actions.security_hub_alarms.enable_security_hub_finding_aggregator
}
