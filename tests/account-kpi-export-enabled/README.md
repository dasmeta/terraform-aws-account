# Enabled weekly account KPI export fixture

This fixture exercises the root module with a generic enabled exporter and non-default settings.
The native tests use a mocked AWS provider and do not create live resources.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_this"></a> [this](#module\_this) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_enable_alarm_actions"></a> [enable\_alarm\_actions](#input\_enable\_alarm\_actions) | n/a | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_kpi_export"></a> [account\_kpi\_export](#output\_account\_kpi\_export) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
