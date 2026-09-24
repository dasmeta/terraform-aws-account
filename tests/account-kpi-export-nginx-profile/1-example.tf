module "this" {
  source = "../../"

  users                      = []
  groups                     = []
  buckets                    = []
  create_cloudwatch_log_role = false
  enforce_mfa                = { enabled = false }
  password_policy            = { enabled = false }
  cloudtrail                 = { enabled = false }
  alarm_actions              = { enabled = false }
  alarm_actions_virginia     = { enabled = false }
  secrets                    = { enabled = false }
  cost_report_export         = { enabled = false }
  account_events_export      = { enabled = false }
  security_hub               = { enabled = false }

  account_kpi_export = {
    enabled = true

    cloudbrowser = {
      client_id  = 42
      secret_arn = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:account-kpi-example"
    }

    # The generated profile uses the PromQL @ modifier. Use Prometheus 2.33+,
    # Prometheus 2.25-2.32 with promql-at-modifier enabled, or a compatible
    # backend such as VictoriaMetrics.
    application = {
      enabled        = true
      source_type    = "prometheus"
      grafana_url    = "https://grafana.example.com"
      datasource_uid = "example-prometheus"
      query_profile  = "nginx_ingress"
      metric_filter  = "namespace=\"production\", ingress=~\"api|web\""
    }

    # Organization cost is collected once by the management-account exporter.
    cost = { enabled = false }
    security = {
      enabled = true
      region  = "eu-central-1"
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
