mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "eu-central-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:root"
    }
  }
}

mock_provider "aws" {
  alias = "virginia"
}

run "no_corrective_route_by_default" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_event_rule.security_hub_remediation) == 0
    error_message = "The default account configuration must not create corrective triggers."
  }
}

run "reject_wildcard_remediation_scope" {
  command = plan

  variables {
    security_hub = {
      remediation_workflows = {
        example = {
          enabled              = true
          state_machine_arn    = "arn:aws:states:eu-central-1:111122223333:stateMachine:example-remediation"
          security_control_ids = ["S3.8"]
          resource_ids         = ["*"]
          owner                = "example-ops"
          runbook_url          = "https://example.com/runbook"
        }
      }
    }
  }

  expect_failures = [var.security_hub]
}

run "approved_route_has_exact_finding_scope" {
  command = plan

  variables {
    alarm_actions = {
      enabled         = true
      topic_name      = "example-account-alerts"
      email_addresses = ["security@example.com"]
    }
    security_hub = {
      remediation_workflows = {
        example = {
          enabled              = true
          state_machine_arn    = "arn:aws:states:eu-central-1:111122223333:stateMachine:example-remediation"
          security_control_ids = ["S3.8"]
          resource_ids         = ["arn:aws:s3:::example-bucket"]
          owner                = "example-ops"
          runbook_url          = "https://example.com/runbook"
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_cloudwatch_event_rule.security_hub_remediation) == 1 &&
      jsondecode(aws_cloudwatch_event_rule.security_hub_remediation["example"].event_pattern).detail.findings.Compliance.SecurityControlId == ["S3.8"] &&
      jsondecode(aws_cloudwatch_event_rule.security_hub_remediation["example"].event_pattern).detail.findings.Resources.Id == ["arn:aws:s3:::example-bucket"] &&
      length(aws_cloudwatch_event_target.security_hub_remediation["example"].dead_letter_config) == 1 &&
      jsondecode(aws_iam_role_policy.security_hub_remediation_start["example"].policy).Statement[0].Action == ["states:StartExecution"] &&
      jsondecode(aws_iam_role_policy.security_hub_remediation_start["example"].policy).Statement[0].Resource == "arn:aws:states:eu-central-1:111122223333:stateMachine:example-remediation" &&
      length(aws_cloudwatch_metric_alarm.security_hub_remediation_execution_failed) == 3
    )
    error_message = "An approved workflow must match only its control and resource, with a failed-start destination."
  }
}

run "reject_cross_account_state_machine" {
  command = plan

  variables {
    alarm_actions = {
      enabled         = true
      email_addresses = ["security@example.com"]
    }
    security_hub = {
      remediation_workflows = {
        example = {
          enabled              = true
          state_machine_arn    = "arn:aws:states:eu-central-1:999988887777:stateMachine:example-remediation"
          security_control_ids = ["S3.8"]
          resource_ids         = ["arn:aws:s3:::example-bucket"]
          owner                = "example-ops"
          runbook_url          = "https://example.com/runbook"
        }
      }
    }
  }

  expect_failures = [aws_cloudwatch_event_rule.security_hub_remediation]
}

run "reject_remediation_without_failure_notification_channel" {
  command = plan

  variables {
    alarm_actions = {
      enabled = true
    }
    security_hub = {
      remediation_workflows = {
        example = {
          enabled              = true
          state_machine_arn    = "arn:aws:states:eu-central-1:111122223333:stateMachine:example-remediation"
          security_control_ids = ["S3.8"]
          resource_ids         = ["arn:aws:s3:::example-bucket"]
          owner                = "example-ops"
          runbook_url          = "https://example.com/runbook"
        }
      }
    }
  }

  expect_failures = [aws_cloudwatch_event_rule.security_hub_remediation]
}

run "shared_account_topic_mode_is_explicit" {
  command = plan

  variables {
    alarm_actions = {
      security_hub_alarms = {
        enabled = true
      }
    }
  }

  assert {
    condition     = local.security_hub_reuses_account_topic && local.security_hub_notification_topic_name == "account-alarms-handling"
    error_message = "The default Security Hub notification mode must reuse the account topic."
  }
}

run "dedicated_security_topic_mode_is_explicit" {
  command = plan

  variables {
    alarm_actions = {
      security_hub_alarms = {
        enabled           = true
        use_account_topic = false
        custom_alarm_actions = {
          topic_name = "example-security-alerts"
        }
      }
    }
  }

  assert {
    condition     = !local.security_hub_reuses_account_topic && local.security_hub_notification_topic_name == "example-security-alerts"
    error_message = "Dedicated Security Hub notifications must identify their separate topic."
  }
}
