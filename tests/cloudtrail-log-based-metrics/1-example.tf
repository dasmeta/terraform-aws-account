module "this" {
  source = "../../"

  cloudtrail = {
    enabled                = true
    enable_cloudwatch_logs = true
    name                   = "audit-my-project"
    event_selector = [
      {
        exclude_management_event_sources = [],
        include_management_events        = true
        read_write_type                  = "All"

        data_resource = [
          {
            type = "AWS::S3::Object",
            values = [
              "arn:aws:s3",
            ]
          },
          {
            type = "AWS::Lambda::Function",
            values = [
              "arn:aws:lambda",
            ]
          },
        ]
      }
    ]
    insight_selector = ["ApiCallRateInsight", "ApiErrorRateInsight"]
  }

  log_metrics = {
    enabled = true
    metrics_patterns = [
      {
        name    = "new-user-created"
        pattern = "{ $.eventName = CreateUser }"
      },
      {
        name    = "user-deleted"
        pattern = "{ $.eventName = DeleteUser }"
      }
    ]
  }
}
