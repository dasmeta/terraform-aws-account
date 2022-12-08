output "users" {
  description = "created users data"
  value = {
    for user in values(module.users) : user.iam_user_name => {
      arn                         = user.iam_user_arn
      password_encrypted          = user.iam_user_login_profile_encrypted_password
      access_key_id               = user.iam_access_key_id
      secret_access_key_encrypted = user.iam_access_key_encrypted_secret
    }
  }
}
