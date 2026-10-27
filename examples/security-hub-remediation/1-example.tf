module "account" {
  source = "../.."

  alarm_actions = {
    enabled         = true
    topic_name      = "example-account-alerts"
    email_addresses = ["security@example.com"]
    security_hub_alarms = {
      enabled = true
    }
  }

  security_hub = {
    enabled = true
    delivery_failure = {
      owner                = "example-security-operations"
      escalation_topic_arn = var.security_escalation_topic_arn
      runbook_url          = "https://example.com/runbooks/security-hub-delivery"
    }
    remediation_workflows = {
      example_s3_public_access = {
        enabled              = var.enable_remediation
        state_machine_arn    = aws_sfn_state_machine.s3_public_access_remediation.arn
        security_control_ids = ["S3.8"]
        resource_ids         = ["arn:aws:s3:::${var.bucket_name}"]
        owner                = "example-security-operations"
        runbook_url          = "https://example.com/runbooks/s3-public-access"
        escalation_topic_arn = var.security_escalation_topic_arn
        safety = {
          idempotency_mode     = "IDEMPOTENT"
          revalidates_scope    = true
          verifies_result      = true
          failure_behavior     = "ESCALATE_AND_MANUAL_ROLLBACK"
          rollback_runbook_url = "https://example.com/runbooks/s3-public-access-rollback"
        }
      }
    }
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
