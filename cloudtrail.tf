module "cloudtrail" {
  source  = "dasmeta/modules/aws//modules/cloudtrail/"
  version = "1.7.0"

  count = var.cloudtrail.enabled ? 1 : 0

  name                          = var.cloudtrail.name
  bucket_name                   = var.cloudtrail.bucket_name
  include_global_service_events = var.cloudtrail.include_global_service_events
  enable_log_file_validation    = var.cloudtrail.enable_log_file_validation
  is_organization_trail         = var.cloudtrail.is_organization_trail
  is_multi_region_trail         = var.cloudtrail.is_multi_region_trail
  cloud_watch_logs_group_arn    = var.cloudtrail.cloud_watch_logs_group_arn
  cloud_watch_logs_role_arn     = var.cloudtrail.cloud_watch_logs_role_arn
  enable_logging                = var.cloudtrail.enable_logging
  sns_topic_name                = var.cloudtrail.sns_topic_name
  event_selector                = var.cloudtrail.event_selector
  enable_cloudwatch_logs        = var.cloudtrail.enable_cloudwatch_logs
  cloud_watch_logs_group_name   = "${var.cloudtrail.name}-cloudtrail-logs"
}
