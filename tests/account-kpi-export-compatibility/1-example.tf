module "omitted" {
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

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}

module "disabled" {
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
    enabled = false
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}

output "omitted_exporter" {
  value = module.omitted.account_kpi_export
}

output "disabled_exporter" {
  value = module.disabled.account_kpi_export
}
