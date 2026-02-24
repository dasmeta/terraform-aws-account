# AWS Security Hub Module
# This module sets up Security Hub with submodules (Config, Inspector, GuardDuty, Macie)
# and integrates with alarm actions for findings notifications
module "monitoring_security_hub" {
  source  = "dasmeta/monitoring/aws//modules/security-hub"
  version = "1.21.0"

  count = var.security_hub.enabled ? 1 : 0

  name = var.security_hub.name

  # Security Hub core configuration
  enable_security_hub                    = var.security_hub.enable_security_hub
  enable_security_hub_finding_aggregator = var.security_hub.enable_security_hub_finding_aggregator
  link_mode                              = var.security_hub.link_mode
  specified_regions                      = var.security_hub.specified_regions
  enabled_standards                      = var.security_hub.enabled_standards
  action_target_name                     = var.security_hub.action_target_name
  securityhub_members                    = var.security_hub.securityhub_members

  # AWS Config submodule
  config = var.security_hub.config

  # AWS Inspector submodule
  inspector = var.security_hub.inspector

  # AWS GuardDuty submodule
  guardduty = var.security_hub.guardduty

  # Amazon Macie submodule
  macie = var.security_hub.macie

  # Alarm actions for security hub findings
  alarm_actions = merge(
    {
      enabled = var.alarm_actions.enabled && var.alarm_actions.security_hub_alarms.enabled
    },
    var.alarm_actions.security_hub_alarms.custom_alarm_actions,
    var.alarm_actions.security_hub_alarms.use_account_topic || var.alarm_actions.topic_name == var.alarm_actions.security_hub_alarms.custom_alarm_actions.topic_name ? {
      create_topic                     = false
      topic_name                       = var.alarm_actions.topic_name
      enable_dead_letter_queue         = false
      topic_assign_security_hub_policy = false
    } : {}
  )

  depends_on = [module.cloudwatch_alarm_actions]
}
