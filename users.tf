module "users" {
  source  = "dasmeta/modules/aws//modules/aws-iam-user"
  version = "2.1.3"

  for_each = { for user in var.users : user.username => user if user.create }

  username          = each.value.username
  policy_attachment = each.value.policy_attachment
}

module "groups" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "5.17.0"

  for_each = { for groups in var.groups : groups.name => groups }

  name                              = each.value.name
  attach_iam_self_management_policy = each.value.attach_iam_self_management_policy
  aws_account_id                    = data.aws_caller_identity.current.id
  custom_group_policies             = each.value.custom_group_policies
  group_users                       = each.value.users

  depends_on = [
    module.users
  ]
}

# Enforce MFA preparations
module "enforce_mfa_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "5.17.0"

  count = var.enforce_mfa.enabled ? 1 : 0

  name                              = var.enforce_mfa.group_name
  aws_account_id                    = data.aws_caller_identity.current.id
  group_users                       = [for user in var.users : user.username if user.enforce_mfa]
  attach_iam_self_management_policy = var.enforce_mfa.attach_iam_self_management_policy

  depends_on = [
    module.users
  ]
}

module "enforce_mfa" {
  source  = "terraform-module/enforce-mfa/aws"
  version = "~> 1.0"

  for_each = { for group in module.enforce_mfa_group : group.group_name => group }

  policy_name                     = var.enforce_mfa.policy_name
  account_id                      = data.aws_caller_identity.current.id
  groups                          = [each.value.group_name]
  manage_own_signing_certificates = var.enforce_mfa.manage_own_signing_certificates
  manage_own_ssh_public_keys      = var.enforce_mfa.manage_own_ssh_public_keys
  manage_own_git_credentials      = var.enforce_mfa.manage_own_git_credentials
}
