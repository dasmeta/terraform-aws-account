module "this" {
  source = "../../"

  groups = [
    {
      name  = "test-group-for-already-created-users"
      users = [module.user.iam_user_name]
    }
  ]

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
