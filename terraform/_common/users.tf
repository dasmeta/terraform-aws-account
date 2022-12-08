module "users" {
  source  = "dasmeta/modules/aws//modules/aws-iam-user"
  version = "0.29.1"

  for_each = { for user in var.users : user.username => user }

  username          = each.value.username
  policy_attachment = each.value.policy_attachment
}
