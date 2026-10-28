# Route findings from an existing Security Hub installation without creating
# another hub, aggregator, Config recorder, or detector.
module "account" {
  source = "../.."

  alarm_actions = {
    enabled       = true
    topic_name    = "example-account-alarms"
    web_endpoints = [var.on_call_webhook_url]
    security_hub_alarms = {
      enabled = true
      dedicated_route = {
        topic_name          = "example-security-hub-findings"
        owner               = var.security_owner
        slack_channel       = "security-alerts"
        slack_webhook_url   = var.security_slack_webhook_url
        on_call_webhook_url = var.on_call_webhook_url
      }
    }
  }

  security_hub = {
    enabled                                = true
    enable_security_hub                    = false
    enable_security_hub_finding_aggregator = false
    enabled_standards                      = []
    config                                 = { enabled = false }
    inspector                              = { enabled = false }
    guardduty                              = { enabled = false }
    macie                                  = { enabled = false }
    delivery_failure = {
      owner                = var.security_owner
      escalation_topic_arn = var.delivery_failure_topic_arn
      runbook_url          = var.delivery_failure_runbook_url
    }
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}

output "security_hub_alerting_route" {
  description = "Security topic, route identifiers, channel owner, and failed-delivery resources"
  value       = module.account.security_hub_alerting_route
}
