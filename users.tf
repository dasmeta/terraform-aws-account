module "users" {
  source  = "dasmeta/modules/aws//modules/aws-iam-user"
  version = "0.29.1"

  for_each = { for user in var.users : user.username => user }

  username          = each.value.username
  policy_attachment = each.value.policy_attachment
}

resource "aws_iam_user_group_membership" "this" {
  for_each = { for user in var.users : user.username => user }

  user   = each.value.username
  groups = each.value.groups
}

resource "aws_iam_group" "group" {
  for_each = { for groups in var.groups : groups.name => groups }

  name = each.value.groups
}

module "enforce_mfa" {
  source   = "terraform-module/enforce-mfa/aws"
  version  = "~> 1.0"
  for_each = { for user in var.users : user.username => user }

  policy_name                     = "Administrators-managed-mfa-enforce"
  account_id                      = data.aws_caller_identity.current.id
  groups                          = each.value.groups
  manage_own_signing_certificates = true
  manage_own_ssh_public_keys      = true
  manage_own_git_credentials      = true
}
