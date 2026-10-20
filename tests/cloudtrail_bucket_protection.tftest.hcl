# Mocked AWS: apply simulates state; no AWS infrastructure is changed.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012", arn = "arn:aws:iam::123456789012:root", id = "123456789012" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_region" { defaults = { name = "us-east-2", id = "us-east-2" } }
  mock_data "aws_partition" { defaults = { partition = "aws", dns_suffix = "amazonaws.com", reverse_dns_prefix = "com.amazonaws" } }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/example-policy" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { id = "example-audit-cloud-trail-bucket", arn = "arn:aws:s3:::example-audit-cloud-trail-bucket" }
  }
}
mock_provider "aws" {
  alias = "virginia"
}

run "disabled_default" {
  command = plan
  assert {
    condition     = length(module.cloudtrail) == 0 && var.cloudtrail.bucket_protection.force_destroy && !var.cloudtrail.bucket_protection.versioning_enabled && var.cloudtrail.bucket_protection.governance_retention_years == 0
    error_message = "Protection must remain opt-in and preserve all default values."
  }
}
run "protected_cloudtrail" {
  command = apply
  variables {
    cloudtrail = {
      enabled               = true
      name                  = "example-audit"
      is_organization_trail = false
      bucket_protection = {
        force_destroy               = false
        versioning_enabled          = true
        governance_retention_days   = 1827
        governance_bypass_role_arns = ["arn:aws:iam::123456789012:role/example-audit-emergency"]
      }
    }
  }
  assert {
    condition     = module.cloudtrail[0].s3_bucket_name == "example-audit-cloud-trail-bucket"
    error_message = "The wrapper must retain the existing CloudTrail bucket naming contract."
  }
  # Resource-level passthrough assertions are performed by check_cloudtrail_protection.py
  # against this verbose test state, so dropping the forwarded object is detected.
}
