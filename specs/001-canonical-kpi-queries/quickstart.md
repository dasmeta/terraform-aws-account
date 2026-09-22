# Quickstart Validation

1. Configure `query_profile = "nginx_ingress"` with a neutral production filter and inspect `local.config_json`.
2. Confirm both generated expressions have the same filter, window placeholder, and end-time placeholder.
3. Configure a complete explicit query pair with no profile/filter and confirm it remains unchanged.
4. Configure filter-only, unknown-profile, mixed profile/raw, and one-query inputs and confirm planning rejects each.
5. Run the root and child Terraform tests, then the existing Python collector suite.
6. Run recursive Terraform formatting checks and inspect the diff for no runtime/package, percentile, or metric-ID changes.
