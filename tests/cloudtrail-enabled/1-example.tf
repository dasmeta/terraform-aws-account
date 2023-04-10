module "this" {
  source = "../../"

  alarm_actions = {
    enabled = true
  }

  cloudtrail = {
    enabled                = true
    enable_logging         = false # disable logging to not have s3 object crated and not allowed to destroy test logs bucket
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
    alerts_events    = ["iam-user-creation-or-deletion", "iam-role-creation-or-deletion"]
  }
}
