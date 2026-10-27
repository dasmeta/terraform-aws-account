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
    remediation_workflows = {
      example_s3_public_access = {
        enabled              = var.enable_remediation
        state_machine_arn    = aws_sfn_state_machine.s3_public_access_remediation.arn
        security_control_ids = ["S3.8"]
        resource_ids         = ["arn:aws:s3:::${var.bucket_name}"]
        owner                = "example-security-operations"
        runbook_url          = "https://example.com/runbooks/s3-public-access"
      }
    }
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
