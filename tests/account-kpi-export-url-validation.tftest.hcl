mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "aws" {
  alias = "virginia"
}

run "root_rejects_insecure_cloudbrowser_base_url" {
  command = plan

  variables {
    account_kpi_export = {
      enabled = true
      cloudbrowser = {
        base_url   = "http://cloudbrowser.example.com"
        client_id  = 42
        secret_arn = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
      }
    }
  }

  expect_failures = [var.account_kpi_export]
}

run "root_rejects_userinfo_grafana_base_url" {
  command = plan

  variables {
    account_kpi_export = {
      enabled = true
      cloudbrowser = {
        client_id  = 42
        secret_arn = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
      }
      application = {
        enabled        = true
        grafana_url    = "https://token@grafana.example.com"
        datasource_uid = "example-prometheus"
        uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
        latency_query  = "avg_over_time(request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      }
    }
  }

  expect_failures = [var.account_kpi_export]
}

run "root_rejects_incomplete_cloudwatch_alb_application_source" {
  command = plan

  variables {
    account_kpi_export = {
      enabled = true
      cloudbrowser = {
        client_id  = 42
        secret_arn = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
      }
      application = {
        enabled        = true
        source_type    = "cloudwatch_alb"
        grafana_url    = "https://grafana.example.com"
        datasource_uid = "cloudwatch"
        region         = "eu-central-1"
      }
    }
  }

  expect_failures = [var.account_kpi_export]
}
