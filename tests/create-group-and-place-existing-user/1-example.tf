module "this" {
  source = "../../"

  groups = [
    {
      name  = "test-group-for-already-created-users"
      users = [module.user.iam_user_name]
    }
  ]

  # depends_on = [
  #   module.user
  # ]
}
