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

output "account_events_export" {
  description = "Regional account event export queue and terminal-failure queue identifiers"
  value = var.account_events_export.enabled ? {
    primary = {
      event_queue        = module.account_events_export[0].event_queue_data
      failed_event_queue = module.account_events_export[0].failed_event_queue_data
    }
    virginia = {
      event_queue        = module.account_events_export_virginia[0].event_queue_data
      failed_event_queue = module.account_events_export_virginia[0].failed_event_queue_data
    }
  } : null
}
