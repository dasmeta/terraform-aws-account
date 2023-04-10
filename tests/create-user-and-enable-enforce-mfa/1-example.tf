module "this" {
  source = "../../"

  users = [
    {
      username = "test-user-for-account-module"
    }
  ]

  enforce_mfa = {
    enabled     = true
    group_name  = "enforce-mfa-test"
    policy_name = "mfa-enforce-policy-test"
  }
}
