module "common_resources" {
  source = "../_common"

  users   = var.users
  buckets = var.buckets
  ecrs    = var.ecrs

  providers = {
    aws = aws
  }
}
