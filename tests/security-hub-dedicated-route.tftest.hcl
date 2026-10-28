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

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

mock_provider "aws" {
  alias = "virginia"
}

run "dedicated_security_route_keeps_on_call_and_separates_slack" {
  command = plan

  variables {
    alarm_actions = {
      enabled    = true
      topic_name = "account-alarms"
      security_hub_alarms = {
        enabled = true
        dedicated_route = {
          topic_name          = "security-hub-findings"
          owner               = "security-operations"
          slack_channel       = "security-alerts"
          slack_webhook_url   = "https://example.com/security-slack"
          on_call_webhook_url = "https://example.com/security-on-call"
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
        owner                = "security-operations"
        escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-delivery-failures"
        runbook_url          = "https://example.com/runbooks/security-delivery"
      }
    }
  }

  assert {
    condition = (
      !local.security_hub_reuses_account_topic &&
      local.security_hub_notification_topic_name == "security-hub-findings" &&
      local.security_hub_alarm_actions.create_topic &&
      local.security_hub_alarm_actions.topic_assign_security_hub_policy &&
      length(local.security_hub_alarm_actions.slack_webhooks) == 1 &&
      local.security_hub_alarm_actions.slack_webhooks[0].channel == "security-alerts" &&
      local.security_hub_alarm_actions.slack_webhooks[0].hook_url == "https://example.com/security-slack" &&
      length(local.security_hub_alarm_actions.web_endpoints) == 1 &&
      local.security_hub_alarm_actions.web_endpoints[0] == "https://example.com/security-on-call" &&
      output.security_hub_alerting_route.security_channel.owner == "security-operations" &&
      output.security_hub_alerting_route.security_channel.slack_channel == "security-alerts"
    )
    error_message = "Dedicated Security Hub routing must use its own topic, security Slack webhook, and on-call endpoint without copying the account alert destinations."
  }
}

run "reject_dedicated_route_using_account_topic" {
  command = plan

  variables {
    alarm_actions = {
      topic_name = "account-alarms"
      security_hub_alarms = {
        dedicated_route = {
          topic_name          = "account-alarms"
          owner               = "security-operations"
          slack_channel       = "security-alerts"
          slack_webhook_url   = "https://example.com/security-slack"
          on_call_webhook_url = "https://example.com/security-on-call"
        }
      }
    }
  }

  expect_failures = [var.alarm_actions]
}

run "reject_mixed_dedicated_and_custom_destinations" {
  command = plan

  variables {
    alarm_actions = {
      security_hub_alarms = {
        custom_alarm_actions = {
          web_endpoints = ["https://example.com/extra-on-call"]
        }
        dedicated_route = {
          topic_name          = "security-hub-findings"
          owner               = "security-operations"
          slack_channel       = "security-alerts"
          slack_webhook_url   = "https://example.com/security-slack"
          on_call_webhook_url = "https://example.com/security-on-call"
        }
      }
    }
  }

  expect_failures = [var.alarm_actions]
}

run "reject_slack_channel_prefix_that_breaks_lambda_names" {
  command = plan

  variables {
    alarm_actions = {
      security_hub_alarms = {
        dedicated_route = {
          topic_name          = "security-hub-findings"
          owner               = "security-operations"
          slack_channel       = "#security-alerts"
          slack_webhook_url   = "https://example.com/security-slack"
          on_call_webhook_url = "https://example.com/security-on-call"
        }
      }
    }
  }

  expect_failures = [var.alarm_actions]
}

run "accept_sensitive_security_webhook_inputs" {
  command = plan

  variables {
    alarm_actions = {
      enabled = true
      security_hub_alarms = {
        enabled = true
        dedicated_route = {
          topic_name          = "security-hub-findings"
          owner               = "security-operations"
          slack_channel       = "security-alerts"
          slack_webhook_url   = sensitive("https://example.com/security-slack")
          on_call_webhook_url = sensitive("https://example.com/security-on-call")
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
        owner                = "security-operations"
        escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-delivery-failures"
        runbook_url          = "https://example.com/runbooks/security-delivery"
      }
    }
  }

  assert {
    condition     = output.security_hub_alerting_route.security_channel.slack_channel == "security-alerts"
    error_message = "A dedicated security route must accept sensitive webhook values from a secret source."
  }
}
