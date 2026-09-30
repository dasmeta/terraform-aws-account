module "this" {
  source = "../../"

  users                      = []
  groups                     = []
  buckets                    = []
  create_cloudwatch_log_role = false
  enforce_mfa = {
    enabled = false
  }
  password_policy = {
    enabled = false
  }
  cloudtrail             = { enabled = false }
  alarm_actions          = { enabled = var.enable_alarm_actions, topic_name = "example-account-alarms" }
  alarm_actions_virginia = { enabled = false }
  secrets                = { enabled = false }
  cost_report_export     = { enabled = false }
  account_events_export  = { enabled = false }
  security_hub           = { enabled = false }

  account_kpi_export = {
    enabled = true

    cloudbrowser = {
      base_url               = "https://cloudbrowser.example.com"
      client_id              = 42
      secret_arn             = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
      aws_provider_id        = 77
      cloudbrowser_token_key = "example_cloudbrowser_token"
      grafana_token_key      = "example_grafana_token"
    }
    application = {
      enabled        = true
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      query_profile  = "nginx_ingress"
      metric_filter  = "namespace=\"production\", ingress=~\"api|web\""
    }
    cost = {
      enabled = true
    }
    security = {
      enabled = false
      region  = "eu-west-1"
    }
    metrics = {
      security = 104
      cost     = 112
      uptime   = 124
      latency  = 126
    }
    schedules = {
      timezone                              = "Europe/Zurich"
      monday_expression                     = "cron(15 7 ? * MON *)"
      wednesday_expression                  = "cron(15 7 ? * WED *)"
      delivery_maximum_event_age_in_seconds = 7200
      delivery_maximum_retry_attempts       = 5
    }
    lambda = {
      name                               = "example-kpi-export"
      timeout                            = 420
      memory_size                        = 512
      logs_retention_in_days             = 60
      async_maximum_event_age_in_seconds = 10800
      async_maximum_retry_attempts       = 1
      alarm_action_arns = [
        "arn:aws:sns:eu-central-1:111122223333:example-custom-kpi-alarms",
        "arn:aws:sns:eu-central-1:111122223333:example-custom-kpi-alarms"
      ]
    }
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}

output "account_kpi_export" {
  value = module.this.account_kpi_export
}
