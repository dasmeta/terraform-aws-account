module "secrets" {
  source  = "dasmeta/modules/aws//modules/secret"
  version = "2.18.0"

  count = var.secrets.enabled ? 1 : 0

  name  = var.secrets.name
  value = var.secrets.value
}
