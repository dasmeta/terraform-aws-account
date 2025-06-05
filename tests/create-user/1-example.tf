module "this" {
  source = "../../"

  users = [
    {
      username = "test-user-for-account-module-to-create"
    }
  ]

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
