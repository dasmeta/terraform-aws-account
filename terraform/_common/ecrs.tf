module "ecrs" {
  source  = "dasmeta/modules/aws//modules/ecr"
  version = "0.29.1"

  repos = var.ecrs
}
