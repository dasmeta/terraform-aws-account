module "this" {
  source = "../../"

  log_metrics = {
    enabled = true
    metrics_patterns = [
      {
        name    = "S3-bucket-creation"
        pattern = "{ $.eventName = CreateBucket }"
      },
      {
        name    = "S3-bucket-deletion"
        pattern = "{ $.eventName = DeleteBucket }"
      },
    ]
  }

  alarm_actions = {
    enabled         = true
    topic_name      = "CloudTrail_logs"
    email_addresses = ["test@dasmeta.com"]
  }

  alerts = [
    {
      name : "S3-bucket-creation-alarm"
      source : "LogBasedMetrics/S3-bucket-creation"
      statistic : "sum"
      filters : {}
      equation : "gte"
      threshold : 1
      period : 10
    },
    {
      name : "S3-bucket-deletion-alarm"
      source : "LogBasedMetrics/S3-bucket-deletion"
      statistic : "sum"
      filters : {}
      equation : "gte"
      threshold : 1
      period : 10
    }
  ]
}
