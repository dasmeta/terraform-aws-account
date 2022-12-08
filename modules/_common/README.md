# _common

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
| <a name="module_buckets"></a> [buckets](#module\_buckets) | dasmeta/modules/aws//modules/s3 | 0.36.7 |
| <a name="module_ecrs"></a> [ecrs](#module\_ecrs) | dasmeta/modules/aws//modules/ecr | 0.29.1 |
| <a name="module_users"></a> [users](#module\_users) | dasmeta/modules/aws//modules/aws-iam-user | 0.29.1 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_buckets"></a> [buckets](#input\_buckets) | List of buckets | `list(any)` | `[]` | no |
| <a name="input_ecrs"></a> [ecrs](#input\_ecrs) | List of ECR repositories | `list(string)` | `[]` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users | `list(any)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_users"></a> [users](#output\_users) | created users data |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
