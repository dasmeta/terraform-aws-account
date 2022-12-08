module "account" {
  source = "./modules/_account"

  users                      = local.config.users
  buckets                    = local.config.buckets
  ecrs                       = local.config.ecrs
  create_cloudwatch_log_role = try(local.config.create_cloudwatch_log_role, false)

  providers = {
    aws = aws
  }
}
