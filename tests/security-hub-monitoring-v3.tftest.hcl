mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { name = "eu-central-1" }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:root"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

mock_provider "aws" {
  alias = "virginia"
}

# Uses the registry module pinned in security-hub.tf; no override_module.
run "released_monitoring_alert_contract" {
  command = plan

  variables {
    alarm_actions = {
      enabled         = true
      topic_name      = "example-account-alerts"
      email_addresses = ["security@example.com"]
      security_hub_alarms = {
        enabled = true
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
        owner                = "security-operations"
        escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
        runbook_url          = "https://example.com/runbooks/security-hub-delivery"
      }
    }
  }

  assert {
    condition = (
      length(module.monitoring_security_hub) == 1 &&
      output.security_hub_alerting_route.enabled &&
      output.security_hub_alerting_route.failure_response.owner == "security-operations" &&
      output.security_hub_alerting_route.failure_response.escalation_topic_arn == "arn:aws:sns:eu-central-1:111122223333:security-escalation" &&
      length(output.security_hub_alerting_route.failed_delivery_alarm_arns) == 5 &&
      contains(keys(output.security_hub_alerting_route), "manual_eventbridge_rule_arn") &&
      contains(keys(output.security_hub_alerting_route), "failed_delivery_queue_arn") &&
      contains(keys(output.security_hub_alerting_route), "failed_delivery_queue_url")
    )
    error_message = "Account alerting must consume the released monitoring v3 failure response, five alarms, manual rule, and failure queue outputs."
  }
}
