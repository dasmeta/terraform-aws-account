# Quickstart: Weekly Account KPI Export

## Before Deployment

1. Query CloudBrowser for the client, AWS provider, four metric definitions, and the AWS account ID.
   Correct missing or ambiguous account metadata before enabling the module.
2. Store `cloudbrowser_api_token` and, for a production application account,
   `grafana_api_token` in one Secrets Manager JSON secret.
3. Confirm Cost Explorer access and the intended Security Hub aggregation Region.
4. Confirm each production Grafana query returns exactly one scalar for a known complete week.
5. Disable `cost_report_export` in the same account before the new Wednesday schedule starts.

## Configure

Use the generic contract example in [contracts/terraform-interface.md](contracts/terraform-interface.md).
Enable `application` only in the client's production application account. Enable the root exporter in
every account that should create its separate cost and security rows.

## Build and Test

```bash
python3 -m unittest discover -s modules/account-kpi-export/tests -v
python3 modules/account-kpi-export/scripts/build_package.py --check
terraform fmt -check -recursive
terraform -chdir=modules/account-kpi-export init -backend=false -upgrade
terraform -chdir=modules/account-kpi-export validate
terraform -chdir=modules/account-kpi-export test
python3 modules/account-kpi-export/tests/check_terraform_plan.py
terraform -chdir=tests/account-kpi-export-enabled init -backend=false -upgrade
terraform -chdir=tests/account-kpi-export-enabled validate
terraform -chdir=tests/account-kpi-export-enabled test
python3 tests/account-kpi-export-enabled/check_terraform_plan.py
terraform -chdir=tests/account-kpi-export-compatibility init -backend=false -upgrade
terraform -chdir=tests/account-kpi-export-compatibility test
terraform -chdir=tests/basic init -backend=false
terraform -chdir=tests/basic validate
terraform -chdir=modules/account-kpi-export/examples/basic init -backend=false
terraform -chdir=modules/account-kpi-export/examples/basic validate
tflint --chdir=modules/account-kpi-export --init
tflint --chdir=modules/account-kpi-export
pre-commit run --all-files
```

Run `terraform-docs` through the repository pre-commit hook after Terraform interfaces are final.
Run Checkov or tfsec when installed; CI supplies both security workflows.

## First Run

After apply, invoke the AWS job manually:

```json
{"job":"aws"}
```

For the production account, also invoke:

```json
{"job":"application"}
```

Verify one row for each enabled metric with the expected client, AWS account, and prior-week Wednesday
date. Invoke the same payload again and verify every row is reported as `skipped_duplicate`.

## Failure Checks

- Remove or mis-map a test account record and confirm no metric write occurs.
- Seed a different value for the same metric/client/account/date and confirm a conflict with no update.
- Deny one AWS source in a test account and confirm the independent source can write before the job
  fails for retry.
- Return an invalid Grafana latency after a valid uptime and confirm neither application row is written.
- Simulate a response lost after a successful CloudBrowser create and confirm reconciliation finds one
  equal row without a second POST.
- Confirm exhausted Scheduler delivery failures and exhausted Lambda handler failures both appear in
  the encrypted SQS queue and the alarms change state.
