data "aws_caller_identity" "current" {}

locals {
  s3_bucket_name = "${var.cloudtrail.name}-cloud-trail-bucket"
}

resource "aws_cloudtrail" "cloudtrail" {
  count = var.cloudtrail.enabled ? 1 : 0

  name                          = var.cloudtrail.name
  s3_bucket_name                = var.cloudtrail.bucket_name != "" ? var.cloudtrail.bucket_name : local.s3_bucket_name
  include_global_service_events = var.cloudtrail.include_global_service_events
  enable_log_file_validation    = var.cloudtrail.enable_log_file_validation
  is_organization_trail         = var.cloudtrail.is_organization_trail
  is_multi_region_trail         = var.cloudtrail.is_multi_region_trail
  cloud_watch_logs_group_arn    = var.cloudtrail.cloud_watch_logs_group_arn
  cloud_watch_logs_role_arn     = var.cloudtrail.cloud_watch_logs_role_arn
  enable_logging                = var.cloudtrail.enable_logging
  sns_topic_name                = var.cloudtrail.sns_topic_name

  dynamic "event_selector" {
    for_each = var.cloudtrail.event_selector
    content {
      include_management_events = lookup(event_selector.value, "include_management_events", null)
      read_write_type           = lookup(event_selector.value, "read_write_type", null)

      dynamic "data_resource" {
        for_each = lookup(event_selector.value, "data_resource", [])
        content {
          type   = data_resource.value.type
          values = data_resource.value.values
        }
      }
    }
  }
}

resource "aws_s3_bucket" "s3" {
  count = var.cloudtrail.bucket_name != "" ? 0 : 1

  bucket        = local.s3_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_policy" "s3" {
  count = var.cloudtrail.bucket_name != "" ? 0 : 1

  bucket = aws_s3_bucket.s3[0].id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${local.s3_bucket_name}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${local.s3_bucket_name}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}
