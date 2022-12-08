locals {
  common_users = [
    {
      username = "test-account-module"
      policy_attachment = [
        "arn:aws:iam::aws:policy/ReadOnlyAccess",
        "arn:aws:iam::aws:policy/IAMUserChangePassword"
      ]
    }
  ]
  common_buckets = [
  ]

  admin_policy_attachment = [
    "arn:aws:iam::aws:policy/IAMUserChangePassword",
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]

  accounts = {
    dasmeta = {
      ecrs = ["test-account-module"]
      users = concat(local.common_users, [

      ])
      buckets = concat(local.common_buckets, [
        {
          name = "test-account-module"
          # acl    = "private"
          ignore_public_acls      = true
          restrict_public_buckets = true
          block_public_acls       = true
          block_public_policy     = true

          versioning = {
            enabled = true
          }
        }
      ])
      create_cloudwatch_log_role = true
    }
  }
}
