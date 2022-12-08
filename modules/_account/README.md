<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 0.15.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_common_resources"></a> [common\_resources](#module\_common\_resources) | ../_common | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_buckets"></a> [buckets](#input\_buckets) | List of account level buckets, to create environment/product level buckets please use corresponding terraform setups | `list(any)` | `[]` | no |
| <a name="input_create_cloudwatch_log_role"></a> [create\_cloudwatch\_log\_role](#input\_create\_cloudwatch\_log\_role) | This is an account level configuration which creates IAM role with policy allowing cloudwatch sync/push logs into cloudwatch | `bool` | `false` | no |
| <a name="input_ecrs"></a> [ecrs](#input\_ecrs) | List of ecrs | `list(string)` | `[]` | no |
| <a name="input_users"></a> [users](#input\_users) | List of account level create users, to create environment/product level users please use corresponding terraform setups | `list(any)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_users"></a> [users](#output\_users) | created users data |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
