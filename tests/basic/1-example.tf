module "this" {
  source = "../../"

  users = [
    {
      username = "test-user-for-account-module"
      policy_attachment = [
        "arn:aws:iam::aws:policy/AdministratorAccess",
        "arn:aws:iam::aws:policy/IAMUserChangePassword"
      ]
    }
  ]

  groups = [
    {
      name  = "Test-Administrators"
      users = ["test-user-for-account-module"]
    }
  ]


  buckets = [{
    name = "test-states-bucket"
    versioning = {
      enabled = true
    }
  }]
}
