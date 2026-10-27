# Quickstart and verification

1. Configure Security Hub, a functioning notification destination, and one approved Standard workflow in the same account/Region. Start with the workflow disabled or with an empty workflow map.
2. Review the exact control IDs and `Resources.Id` values from an approved non-production finding. Keep the workflow's execution role restricted to those resources and verify its resource selection, repeat handling, and post-action check.
3. Run `terraform fmt -check -recursive`, `terraform init -backend=false`, `terraform validate`, and `terraform test -filter=tests/security-hub-cspm.tftest.hcl` with Terraform >= 1.6.
4. Inspect the plan before apply. After an approved apply, perform a controlled test, read EventBridge and state-machine execution history, confirm downstream notification receipt and acknowledgement, and record post-action AWS evidence for PR #94.

Validation on 2026-10-27: the focused native suite passed 7/7 plans. The example passed `terraform init -backend=false` and `terraform validate`. Repository `terraform fmt -check -recursive` and `git diff --check` passed. Direct root `terraform validate` still reports the pre-existing unconfigured `aws.virginia` provider alias; the caller example supplies both providers and validates. The root module continues to pin monitoring 1.21.0 until a new immutable monitoring release contains the alert lifecycle and delivery changes.
