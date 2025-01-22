module "this" {
  source = "../../"

  users = [
    {
      username = "test-user-for-account-module"
    }
  ]

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }

  enforce_mfa = {
    enabled     = true
    group_name  = "enforce-mfa-test"
    policy_name = "mfa-enforce-policy-test"
  }
}
