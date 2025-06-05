module "this" {
  source = "../../"

  secrets = {
    enabled                 = true
    name                    = "test-account-secret"
    value                   = {}
    recovery_window_in_days = 0
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
