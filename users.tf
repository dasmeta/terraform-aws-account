module "users" {
  source  = "dasmeta/modules/aws//modules/aws-iam-user"
  version = "2.1.2"

  for_each = { for user in var.users : user.username => user if user.create }

  username          = each.value.username
  policy_attachment = each.value.policy_attachment
}

module "groups" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "5.19.0"

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
  version = "5.19.0"

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

# TODO: move this(iam-account-password-policy) sub-module sources form terraform-aws-modules repo into current(terraform-aws-account) or terraform-aws-iam repo
module "password_policy" {
  count = var.password_policy.enabled ? 1 : 0

  source  = "dasmeta/modules/aws//modules/iam-account-password-policy"
  version = "1.5.2"

  allow_users_to_change_password = var.password_policy.allow_users_to_change_password
  minimum_password_length        = var.password_policy.minimum_password_length
  require_lowercase_characters   = var.password_policy.require_lowercase_characters
  require_numbers                = var.password_policy.require_numbers
  require_symbols                = var.password_policy.require_symbols
  require_uppercase_characters   = var.password_policy.require_uppercase_characters
  max_password_age               = var.password_policy.max_password_age
  hard_expiry                    = var.password_policy.hard_expiry
  password_reuse_prevention      = var.password_policy.password_reuse_prevention
}
