output "users" {
  description = "created users data"
  value = {
    for user in values(module.users) : user.iam_user_name => {
      arn                         = user.iam_user_arn
      password_encrypted          = user.iam_user_login_profile_encrypted_password
      access_key_id               = user.iam_access_key_id
      secret_access_key_encrypted = user.iam_access_key_secret
    }
  }
  sensitive = true
}

output "account_kpi_export" {
  description = "Operational Lambda, schedule, failure queue, and alarm identifiers; null when the weekly KPI exporter is disabled."
  value = var.account_kpi_export.enabled ? {
    lambda_function_arn  = module.account_kpi_export[0].lambda_function_arn
    lambda_function_name = module.account_kpi_export[0].lambda_function_name
    schedule_arns        = module.account_kpi_export[0].schedule_arns
    failure_queue_arn    = module.account_kpi_export[0].failure_queue_arn
    failure_queue_url    = module.account_kpi_export[0].failure_queue_url
    alarm_arns           = module.account_kpi_export[0].alarm_arns
  } : null
}
