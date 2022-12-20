module "account" {
  source = "../"

  users                      = local.config.users
  buckets                    = local.config.buckets
  name                       = local.config.name
  ecrs                       = local.config.ecrs
  create_cloudwatch_log_role = try(local.config.create_cloudwatch_log_role, false)
  # users = [ {
  #     username = "test-mfa"
  #     policy_attachment = [
  #       "arn:aws:iam::aws:policy/ReadOnlyAccess",
  #       "arn:aws:iam::aws:policy/IAMUserChangePassword"
  #     ]
  #   }]
  # buckets = [{
  #         name = "dasmeta"
  #         # acl    = "private"
  #         ignore_public_acls      = true
  #         restrict_public_buckets = true
  #         block_public_acls       = true
  #         block_public_policy     = true

  #         versioning = {
  #           enabled = true
  #         }
  #     create_cloudwatch_log_role = true
  #   }]
  # name = "dasmeta"
  # ecrs = ["dasmeta-ecr"]
  # create_cloudwatch_log_role = true
  # providers = {
  #   aws = aws
  # }
}
