module "this" {
  source = "../../"

  users = [
    {
      username = module.user.iam_user_name
      create   = false
    }
  ]

  enforce_mfa = {
    enabled     = true
    group_name  = "enforce-mfa-test"
    policy_name = "mfa-enforce-policy-test"
  }
}
