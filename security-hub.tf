# AWS Security Hub Module
# This module sets up Security Hub with submodules (Config, Inspector, GuardDuty, Macie)
# and integrates with alarm actions for findings notifications
locals {
  security_hub_dedicated_route = var.alarm_actions.security_hub_alarms.dedicated_route
  security_hub_reuses_account_topic = (
    local.security_hub_dedicated_route == null && (
      var.alarm_actions.security_hub_alarms.use_account_topic ||
      var.alarm_actions.topic_name == var.alarm_actions.security_hub_alarms.custom_alarm_actions.topic_name
    )
  )
  security_hub_notification_topic_name = local.security_hub_dedicated_route != null ? (
    local.security_hub_dedicated_route.topic_name
    ) : local.security_hub_reuses_account_topic ? (
    var.alarm_actions.topic_name
    ) : (
    var.alarm_actions.security_hub_alarms.custom_alarm_actions.topic_name != "" ?
    var.alarm_actions.security_hub_alarms.custom_alarm_actions.topic_name :
    "${var.security_hub.name}-security-hub-findings"
  )
  security_hub_alarm_actions = merge(
    {
      enabled = var.alarm_actions.enabled && var.alarm_actions.security_hub_alarms.enabled
    },
    var.alarm_actions.security_hub_alarms.custom_alarm_actions,
    {
      create_topic                     = local.security_hub_dedicated_route != null ? true : local.security_hub_reuses_account_topic ? false : var.alarm_actions.security_hub_alarms.custom_alarm_actions.create_topic
      topic_name                       = local.security_hub_notification_topic_name
      topic_assign_security_hub_policy = local.security_hub_dedicated_route != null ? true : local.security_hub_reuses_account_topic ? false : var.alarm_actions.security_hub_alarms.custom_alarm_actions.topic_assign_security_hub_policy
      enable_dead_letter_queue         = local.security_hub_reuses_account_topic ? false : var.alarm_actions.security_hub_alarms.custom_alarm_actions.enable_dead_letter_queue
      slack_webhooks = local.security_hub_dedicated_route != null ? [{
        hook_url = try(local.security_hub_dedicated_route.slack_webhook_url, "")
        channel  = try(local.security_hub_dedicated_route.slack_channel, "")
        username = "security-hub"
      }] : var.alarm_actions.security_hub_alarms.custom_alarm_actions.slack_webhooks
      web_endpoints = local.security_hub_dedicated_route != null ? [try(local.security_hub_dedicated_route.on_call_webhook_url, "")] : var.alarm_actions.security_hub_alarms.custom_alarm_actions.web_endpoints
    }
  )
}

module "monitoring_security_hub" {
  # Temporary immutable dependency until monitoring PR #106 is released.
  source = "git::https://github.com/dasmeta/terraform-aws-monitoring.git//modules/security-hub?ref=c49d6f78c56a608dfed28e249f0519d817164030"

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
  alarm_actions = local.security_hub_alarm_actions

  delivery_failure = var.security_hub.delivery_failure

  depends_on = [module.cloudwatch_alarm_actions]
}
