locals {
  common_users = [
    {
      username = "test-user"
      policy_attachment = [
        "arn:aws:iam::aws:policy/AdministratorAccess",
        "arn:aws:iam::aws:policy/IAMUserChangePassword"
      ]
      groups = ["Administrators"]
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
      ecrs = ["dasmeta-ecr"]
      users = concat(local.common_users, [

      ])
      name = "dasmeta"
      buckets = concat(local.common_buckets, [
        {
          name = "dasmeta"
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
