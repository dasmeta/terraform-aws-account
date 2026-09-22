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

run "root_accepts_canonical_nginx_metric_filter" {
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
        grafana_url    = "https://grafana.example.com"
        datasource_uid = "example-prometheus"
        query_profile  = "nginx_ingress"
        metric_filter  = "namespace=\"production\", ingress=~\"api|web\""
      }
      cost = {
        enabled = false
      }
      security = {
        enabled = false
      }
    }
  }
}

run "root_rejects_unknown_cost_scope" {
  command = plan

  variables {
    account_kpi_export = {
      enabled = true
      cloudbrowser = {
        client_id  = 42
        secret_arn = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
      }
      cost = {
        enabled = true
        scope   = "unknown"
      }
      security = {
        enabled = false
      }
    }
  }

  expect_failures = [var.account_kpi_export]
}

run "root_rejects_metric_filter_without_query_profile" {
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
        grafana_url    = "https://grafana.example.com"
        datasource_uid = "example-prometheus"
        metric_filter  = "namespace=\"production\""
      }
      cost = {
        enabled = false
      }
      security = {
        enabled = false
      }
    }
  }

  expect_failures = [var.account_kpi_export]
}

run "root_rejects_unknown_query_profile" {
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
        grafana_url    = "https://grafana.example.com"
        datasource_uid = "example-prometheus"
        query_profile  = "unknown"
        metric_filter  = "namespace=\"production\""
      }
      cost = {
        enabled = false
      }
      security = {
        enabled = false
      }
    }
  }

  expect_failures = [var.account_kpi_export]
}

run "root_rejects_query_profile_with_raw_queries" {
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
        grafana_url    = "https://grafana.example.com"
        datasource_uid = "example-prometheus"
        query_profile  = "nginx_ingress"
        metric_filter  = "namespace=\"production\""
        uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
        latency_query  = "avg_over_time(request_duration_seconds_sum[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      }
    }
  }

  expect_failures = [var.account_kpi_export]
}

run "root_rejects_one_query_even_with_metric_filter" {
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
        grafana_url    = "https://grafana.example.com"
        datasource_uid = "example-prometheus"
        metric_filter  = "namespace=\"production\""
        uptime_query   = "100 * avg_over_time(up[$__account_kpi_window] @ $__account_kpi_end_seconds)"
      }
    }
  }

  expect_failures = [var.account_kpi_export]
}
