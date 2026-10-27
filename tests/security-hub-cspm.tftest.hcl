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

run "disabled_workflow_does_not_require_safety_review" {
  command = plan

  variables {
    security_hub = {
      remediation_workflows = {
        example = {
          enabled              = false
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
    condition     = length(aws_cloudwatch_event_rule.security_hub_remediation) == 0
    error_message = "Disabled corrective workflows must remain inert before safety review."
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
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
          safety = {
            idempotency_mode     = "IDEMPOTENT"
            revalidates_scope    = true
            verifies_result      = true
            failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
            rollback_runbook_url = "https://example.com/rollback"
          }
        }
      }
    }
  }

  expect_failures = [var.security_hub]
}

run "approved_route_has_exact_finding_scope" {
  command = plan

  override_resource {
    target          = aws_cloudwatch_event_rule.security_hub_remediation["example"]
    override_during = plan
    values          = { arn = "arn:aws:events:eu-central-1:111122223333:rule/example-remediate" }
  }

  override_resource {
    target          = aws_cloudwatch_event_rule.security_hub_remediation_failed["example"]
    override_during = plan
    values          = { arn = "arn:aws:events:eu-central-1:111122223333:rule/example-execution-failed" }
  }

  override_resource {
    target          = aws_sqs_queue.security_hub_remediation_failed_delivery["example"]
    override_during = plan
    values          = { arn = "arn:aws:sqs:eu-central-1:111122223333:example-failed-delivery" }
  }

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
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
          safety = {
            idempotency_mode     = "IDEMPOTENT"
            revalidates_scope    = true
            verifies_result      = true
            failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
            rollback_runbook_url = "https://example.com/rollback"
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_cloudwatch_event_rule.security_hub_remediation) == 1 &&
      jsondecode(aws_cloudwatch_event_rule.security_hub_remediation["example"].event_pattern).detail.findings.Compliance.SecurityControlId == ["S3.8"] &&
      jsondecode(aws_cloudwatch_event_rule.security_hub_remediation["example"].event_pattern).detail.findings.Compliance.Status == ["FAILED"] &&
      jsondecode(aws_cloudwatch_event_rule.security_hub_remediation["example"].event_pattern).detail.findings.RecordState == ["ACTIVE"] &&
      jsondecode(aws_cloudwatch_event_rule.security_hub_remediation["example"].event_pattern).detail.findings.Workflow.Status == ["NEW", "NOTIFIED"] &&
      jsondecode(aws_cloudwatch_event_rule.security_hub_remediation["example"].event_pattern).detail.findings.AwsAccountId == ["111122223333"] &&
      jsondecode(aws_cloudwatch_event_rule.security_hub_remediation["example"].event_pattern).detail.findings.Resources.Id == ["arn:aws:s3:::example-bucket"] &&
      length(aws_cloudwatch_event_target.security_hub_remediation["example"].dead_letter_config) == 1 &&
      aws_cloudwatch_event_target.security_hub_remediation["example"].retry_policy[0].maximum_event_age_in_seconds == 86400 &&
      aws_cloudwatch_event_target.security_hub_remediation_failed["example"].retry_policy[0].maximum_retry_attempts == 185 &&
      aws_sqs_queue.security_hub_remediation_failed_delivery["example"].message_retention_seconds == 1209600 &&
      aws_sqs_queue.security_hub_remediation_failed_delivery["example"].sqs_managed_sse_enabled &&
      jsondecode(aws_iam_role_policy.security_hub_remediation_start["example"].policy).Statement[0].Action == ["states:StartExecution"] &&
      jsondecode(aws_iam_role_policy.security_hub_remediation_start["example"].policy).Statement[0].Resource == "arn:aws:states:eu-central-1:111122223333:stateMachine:example-remediation" &&
      length(aws_cloudwatch_metric_alarm.security_hub_remediation_execution_failed) == 3 &&
      length(aws_cloudwatch_metric_alarm.security_hub_remediation_queue_nonempty) == 1 &&
      length(aws_cloudwatch_metric_alarm.security_hub_remediation_delivery_metric) == 4 &&
      aws_cloudwatch_metric_alarm.security_hub_remediation_queue_nonempty["example"].metric_name == "ApproximateNumberOfMessagesVisible" &&
      aws_cloudwatch_metric_alarm.security_hub_remediation_delivery_metric["example-finding-InvocationsFailedToBeSentToDlq"].metric_name == "InvocationsFailedToBeSentToDlq" &&
      contains(aws_cloudwatch_metric_alarm.security_hub_remediation_queue_nonempty["example"].alarm_actions, "arn:aws:sns:eu-central-1:111122223333:security-escalation") &&
      length(output.security_hub_remediation_routes["example"].delivery_failure_alarm_arns) == 5 &&
      output.security_hub_remediation_routes["example"].escalation_topic_arn == "arn:aws:sns:eu-central-1:111122223333:security-escalation" &&
      output.security_hub_remediation_routes["example"].safety.idempotency_mode == "IDEMPOTENT"
    )
    error_message = "An approved workflow must match only its control and resource, with a failed-start destination."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.security_hub_remediation_start["example"].assume_role_policy).Statement[0].Condition.ArnEquals["aws:SourceArn"] == aws_cloudwatch_event_rule.security_hub_remediation["example"].arn &&
      jsondecode(aws_iam_role.security_hub_remediation_start["example"].assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "111122223333" &&
      length(jsondecode(aws_sqs_queue_policy.security_hub_remediation_failed_delivery["example"].policy).Statement[0].Condition.ArnEquals["aws:SourceArn"]) == 2 &&
      contains(jsondecode(aws_sqs_queue_policy.security_hub_remediation_failed_delivery["example"].policy).Statement[0].Condition.ArnEquals["aws:SourceArn"], aws_cloudwatch_event_rule.security_hub_remediation["example"].arn) &&
      contains(jsondecode(aws_sqs_queue_policy.security_hub_remediation_failed_delivery["example"].policy).Statement[0].Condition.ArnEquals["aws:SourceArn"], aws_cloudwatch_event_rule.security_hub_remediation_failed["example"].arn)
    )
    error_message = "The start role and failure queue must trust only this account's exact remediation rules."
  }
}

run "reject_overlapping_corrective_scopes" {
  command = plan

  variables {
    security_hub = {
      remediation_workflows = {
        first = {
          enabled              = true
          state_machine_arn    = "arn:aws:states:eu-central-1:111122223333:stateMachine:first"
          security_control_ids = ["S3.8"]
          resource_ids         = ["arn:aws:s3:::example-bucket"]
          owner                = "example-ops"
          runbook_url          = "https://example.com/runbook"
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
          safety = {
            idempotency_mode     = "IDEMPOTENT"
            revalidates_scope    = true
            verifies_result      = true
            failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
            rollback_runbook_url = "https://example.com/rollback"
          }
        }
        second = {
          enabled              = true
          state_machine_arn    = "arn:aws:states:eu-central-1:111122223333:stateMachine:second"
          security_control_ids = ["S3.8"]
          resource_ids         = ["arn:aws:s3:::example-bucket"]
          owner                = "example-ops"
          runbook_url          = "https://example.com/runbook"
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
          safety = {
            idempotency_mode     = "IDEMPOTENT"
            revalidates_scope    = true
            verifies_result      = true
            failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
            rollback_runbook_url = "https://example.com/rollback"
          }
        }
      }
    }
  }

  expect_failures = [var.security_hub]
}

run "distinct_workflows_keep_failure_alarm_outputs_separate" {
  command = plan

  variables {
    alarm_actions = {
      enabled         = true
      topic_name      = "example-account-alerts"
      email_addresses = ["security@example.com"]
    }
    security_hub = {
      remediation_workflows = {
        foo = {
          enabled              = true
          state_machine_arn    = "arn:aws:states:eu-central-1:111122223333:stateMachine:foo"
          security_control_ids = ["S3.8"]
          resource_ids         = ["arn:aws:s3:::bucket-one"]
          owner                = "example-ops"
          runbook_url          = "https://example.com/runbook"
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
          safety = {
            idempotency_mode     = "IDEMPOTENT"
            revalidates_scope    = true
            verifies_result      = true
            failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
            rollback_runbook_url = "https://example.com/rollback"
          }
        }
        foo-bar = {
          enabled              = true
          state_machine_arn    = "arn:aws:states:eu-central-1:111122223333:stateMachine:foo-bar"
          security_control_ids = ["S3.8"]
          resource_ids         = ["arn:aws:s3:::bucket-two"]
          owner                = "example-ops"
          runbook_url          = "https://example.com/runbook"
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
          safety = {
            idempotency_mode     = "IDEMPOTENT"
            revalidates_scope    = true
            verifies_result      = true
            failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
            rollback_runbook_url = "https://example.com/rollback"
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_cloudwatch_event_rule.security_hub_remediation) == 2 &&
      length(output.security_hub_remediation_routes["foo"].delivery_failure_alarm_arns) == 5 &&
      length(output.security_hub_remediation_routes["foo-bar"].delivery_failure_alarm_arns) == 5
    )
    error_message = "Distinct workflows must keep exactly their own five delivery alarms."
  }
}

run "reject_unreviewed_repeat_behavior" {
  command = plan

  variables {
    security_hub = {
      remediation_workflows = {
        unsafe = {
          enabled              = true
          state_machine_arn    = "arn:aws:states:eu-central-1:111122223333:stateMachine:unsafe"
          security_control_ids = ["S3.8"]
          resource_ids         = ["arn:aws:s3:::example-bucket"]
          owner                = "example-ops"
          runbook_url          = "https://example.com/runbook"
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
          safety = {
            idempotency_mode     = "NON_IDEMPOTENT"
            revalidates_scope    = false
            verifies_result      = false
            failure_behavior     = "IGNORE"
            rollback_runbook_url = "https://example.com/rollback"
          }
        }
      }
    }
  }

  expect_failures = [var.security_hub]
}

run "reject_missing_workflow_safety_contract" {
  command = plan

  variables {
    security_hub = {
      remediation_workflows = {
        unsafe = {
          enabled              = true
          state_machine_arn    = "arn:aws:states:eu-central-1:111122223333:stateMachine:unsafe"
          security_control_ids = ["S3.8"]
          resource_ids         = ["arn:aws:s3:::example-bucket"]
          owner                = "example-ops"
          runbook_url          = "https://example.com/runbook"
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
        }
      }
    }
  }

  expect_failures = [var.security_hub]
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
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
          safety = {
            idempotency_mode     = "IDEMPOTENT"
            revalidates_scope    = true
            verifies_result      = true
            failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
            rollback_runbook_url = "https://example.com/rollback"
          }
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
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:security-escalation"
          safety = {
            idempotency_mode     = "IDEMPOTENT"
            revalidates_scope    = true
            verifies_result      = true
            failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
            rollback_runbook_url = "https://example.com/rollback"
          }
        }
      }
    }
  }

  expect_failures = [aws_cloudwatch_event_rule.security_hub_remediation]
}

run "reject_shared_corrective_failure_topic" {
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
          escalation_topic_arn = "arn:aws:sns:eu-central-1:111122223333:example-account-alerts"
          safety = {
            idempotency_mode     = "IDEMPOTENT"
            revalidates_scope    = true
            verifies_result      = true
            failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
            rollback_runbook_url = "https://example.com/rollback"
          }
        }
      }
    }
  }

  expect_failures = [aws_cloudwatch_event_rule.security_hub_remediation]
}

run "reject_cross_account_corrective_escalation" {
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
          escalation_topic_arn = "arn:aws:sns:eu-central-1:999988887777:security-escalation"
          safety = {
            idempotency_mode     = "IDEMPOTENT"
            revalidates_scope    = true
            verifies_result      = true
            failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
            rollback_runbook_url = "https://example.com/rollback"
          }
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
