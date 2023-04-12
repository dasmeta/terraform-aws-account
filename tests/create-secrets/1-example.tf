module "this" {
  source = "../../"

  secrets = {
    enabled                 = true
    name                    = "test-account-secret"
    value                   = {}
    recovery_window_in_days = 0
  }
}
