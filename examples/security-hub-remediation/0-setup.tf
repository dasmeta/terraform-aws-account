terraform {
  required_version = "~> 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "Exact approved example bucket name"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "s3_public_access_remediation" {
  name = "example-s3-public-access-remediation"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "s3_public_access_remediation" {
  name = "exact-example-bucket-public-access"
  role = aws_iam_role.s3_public_access_remediation.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock"]
      Resource = "arn:aws:s3:::${var.bucket_name}"
    }]
  })
}

# S3.8 example: refuse every event whose first resource is not the exact bucket.
# This check and the IAM policy protect the action even if EventBridge matched
# another resource in the finding's Resources array.
resource "aws_sfn_state_machine" "s3_public_access_remediation" {
  name     = "example-s3-public-access-remediation"
  role_arn = aws_iam_role.s3_public_access_remediation.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "Correct and verify S3.8 on one approved bucket"
    StartAt = "ValidateFinding"
    States = {
      ValidateFinding = {
        Type = "Choice"
        Choices = [{
          And = [
            { Variable = "$.detail.findings[0].AwsAccountId", StringEquals = data.aws_caller_identity.current.account_id },
            { Variable = "$.detail.findings[0].RecordState", StringEquals = "ACTIVE" },
            { Or = [
              { Variable = "$.detail.findings[0].Workflow.Status", StringEquals = "NEW" },
              { Variable = "$.detail.findings[0].Workflow.Status", StringEquals = "NOTIFIED" }
            ] },
            { Variable = "$.detail.findings[0].Compliance.Status", StringEquals = "FAILED" },
            { Variable = "$.detail.findings[0].Compliance.SecurityControlId", StringEquals = "S3.8" },
            { Variable = "$.detail.findings[0].Resources[0].Id", StringEquals = "arn:aws:s3:::${var.bucket_name}" }
          ]
          Next = "ApplyPublicAccessBlock"
        }]
        Default = "Rejected"
      }
      ApplyPublicAccessBlock = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:s3:putPublicAccessBlock"
        Parameters = {
          Bucket              = var.bucket_name
          ExpectedBucketOwner = data.aws_caller_identity.current.account_id
          PublicAccessBlockConfiguration = {
            BlockPublicAcls       = true
            IgnorePublicAcls      = true
            BlockPublicPolicy     = true
            RestrictPublicBuckets = true
          }
        }
        ResultPath = "$.mutation"
        Next       = "VerifyPublicAccessBlock"
        Catch      = [{ ErrorEquals = ["States.ALL"], Next = "Failed" }]
      }
      VerifyPublicAccessBlock = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:s3:getPublicAccessBlock"
        Parameters = {
          Bucket              = var.bucket_name
          ExpectedBucketOwner = data.aws_caller_identity.current.account_id
        }
        ResultPath = "$.verification"
        Next       = "CheckVerification"
        Catch      = [{ ErrorEquals = ["States.ALL"], Next = "Failed" }]
      }
      CheckVerification = {
        Type = "Choice"
        Choices = [{
          And = [
            { Variable = "$.verification.PublicAccessBlockConfiguration.BlockPublicAcls", BooleanEquals = true },
            { Variable = "$.verification.PublicAccessBlockConfiguration.IgnorePublicAcls", BooleanEquals = true },
            { Variable = "$.verification.PublicAccessBlockConfiguration.BlockPublicPolicy", BooleanEquals = true },
            { Variable = "$.verification.PublicAccessBlockConfiguration.RestrictPublicBuckets", BooleanEquals = true }
          ]
          Next = "Succeeded"
        }]
        Default = "Failed"
      }
      Rejected  = { Type = "Fail", Cause = "Finding is outside the approved S3.8 resource scope" }
      Failed    = { Type = "Fail", Cause = "S3 public-access correction or verification failed" }
      Succeeded = { Type = "Succeed" }
    }
  })

  depends_on = [aws_iam_role_policy.s3_public_access_remediation]
}

variable "enable_remediation" {
  type        = bool
  default     = false
  description = "Enable the corrective trigger after reviewing workflow safety and its exact resource scope"
}

variable "security_escalation_topic_arn" {
  type        = string
  description = "Existing operator-owned SNS topic in this account and Region, separate from the account notification topic"
}
