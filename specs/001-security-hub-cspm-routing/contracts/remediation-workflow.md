# Remediation input contract

`security_hub.remediation_workflows` accepts a map of objects. Each object has `enabled` (optional, false), `state_machine_arn` (required Standard Step Functions ARN in the provider account/Region), `security_control_ids` (required nonempty set), `resource_ids` (required nonempty set of exact ASFF `Resources.Id` values), `owner` (required nonempty), and `runbook_url` (required reviewable HTTPS URL).

The module filters only FAILED, ACTIVE, NEW/NOTIFIED findings matching the local account, named controls, and one exact resource ID. It has `states:StartExecution` for the named state machine only. The external workflow must choose and revalidate the resource, enforce its own exact-resource IAM permissions, be idempotent, and prove post-action state. Creation of the route is not approval to mutate a production resource.
