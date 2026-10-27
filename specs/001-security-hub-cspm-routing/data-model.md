# Data model

`security_hub.remediation_workflows` is a map keyed by stable workflow name. Each value records an exact Standard state-machine ARN, one or more Security Hub control IDs, one or more exact ASFF `Resources.Id` values, the accountable owner, and a runbook URL. An optional enable flag defaults false. The account identity and Region come from the active AWS provider; cross-account execution is excluded.

Each enabled entry creates a finding rule, one EventBridge start target, an exact-ARN start role, and a target invocation failure queue. Enabled state-machine ARNs are also watched by one execution failure route. A match only starts the workflow; its own execution role and state definitions control and verify any resource mutation.

The module outputs expose route and queue identifiers. They never expose secrets, finding payloads, or claim acknowledgement or successful correction.
