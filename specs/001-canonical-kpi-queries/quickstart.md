# Quickstart Validation

1. Configure canonical Prometheus mode with a neutral production filter and inspect `local.config_json`.
2. Confirm both generated expressions have the same filter, window placeholder, and end-time placeholder.
3. Configure a complete explicit query pair and confirm it remains unchanged.
4. Configure only one explicit query and confirm planning rejects it.
5. Run the root and child Terraform tests, then the existing Python collector suite.
6. Run recursive Terraform formatting checks and inspect the diff for no runtime/package or metric-ID changes.
