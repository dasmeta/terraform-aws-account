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

    application = { enabled = false }
    cost = {
      enabled = true
      scope   = "organization"
    }
    security = { enabled = false }

    lambda = {
      name = "organization-cost-kpi-export"
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
