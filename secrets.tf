module "secrets" {
  source  = "dasmeta/modules/aws//modules/secret"
  version = "2.3.2"

  count = var.secrets.enabled ? 1 : 0

  name                    = var.secrets.name
  value                   = var.secrets.value
  recovery_window_in_days = var.secrets.recovery_window_in_days
}
