data "aws_caller_identity" "current" {}

resource "aws_iam_group" "test-account-module" {
  name = "test-account-module-group"
}

module "enforce_mfa" {
  source  = "terraform-module/enforce-mfa/aws"
  version = "~> 1.0"

  policy_name                     = "test-account-module-managed-mfa-enforce"
  account_id                      = data.aws_caller_identity.current.id
  groups                          = [aws_iam_group.test-account-module.name]
  manage_own_signing_certificates = true
  manage_own_ssh_public_keys      = true
  manage_own_git_credentials      = true
}
