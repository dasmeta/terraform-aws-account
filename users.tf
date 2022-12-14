module "users" {
  source  = "dasmeta/modules/aws//modules/aws-iam-user"
  version = "1.5.2"

  for_each = { for user in var.users : user.username => user }

  username          = each.value.username
  policy_attachment = each.value.policy_attachment
}

module "groups" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "5.9.2"

  for_each = { for groups in var.groups : groups.name => groups }

  name                              = each.value.name
  attach_iam_self_management_policy = each.value.attach_iam_self_management_policy
  aws_account_id                    = data.aws_caller_identity.current.id
  custom_group_policies             = each.value.custom_group_policies
  group_users                       = each.value.users
}

# Enforce MFA preparations
module "enforce_mfa_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "5.9.2"

  count = var.enforce_mfa.group_name == null ? 0 : 1

  name                              = var.enforce_mfa.group_name
  aws_account_id                    = data.aws_caller_identity.current.id
  group_users                       = [for user in var.users : user.username if user.enforce_mfa]
  attach_iam_self_management_policy = var.enforce_mfa.attach_iam_self_management_policy
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
