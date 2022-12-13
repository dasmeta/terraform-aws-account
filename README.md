# terraform-aws-account

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_buckets"></a> [buckets](#module\_buckets) | dasmeta/modules/aws//modules/s3 | 0.36.7 |
| <a name="module_enforce_mfa"></a> [enforce\_mfa](#module\_enforce\_mfa) | terraform-module/enforce-mfa/aws | ~> 1.0 |
| <a name="module_user-group"></a> [user-group](#module\_user-group) | dasmeta/modules/aws//modules/iam-group | n/a |
| <a name="module_users"></a> [users](#module\_users) | dasmeta/modules/aws//modules/aws-iam-user | 0.29.1 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudtrail.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |
| [aws_iam_group.test-account-module](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group) | resource |
| [aws_s3_bucket.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | n/a | `string` | `null` | no |
| <a name="input_buckets"></a> [buckets](#input\_buckets) | List of buckets | `list(any)` | `[]` | no |
| <a name="input_cloud_watch_logs_group_arn"></a> [cloud\_watch\_logs\_group\_arn](#input\_cloud\_watch\_logs\_group\_arn) | Specifies a log group name using an Amazon Resource Name (ARN), that represents the log group to which CloudTrail logs will be delivered | `string` | `""` | no |
| <a name="input_cloud_watch_logs_role_arn"></a> [cloud\_watch\_logs\_role\_arn](#input\_cloud\_watch\_logs\_role\_arn) | Specifies the role for the CloudWatch Logs endpoint to assume to write to a user’s log group | `string` | `""` | no |
| <a name="input_create_cloudwatch_log_role"></a> [create\_cloudwatch\_log\_role](#input\_create\_cloudwatch\_log\_role) | This is an account level configuration which creates IAM role with policy allowing cloudwatch sync/push logs into cloudwatch | `bool` | `false` | no |
| <a name="input_create_s3_bucket"></a> [create\_s3\_bucket](#input\_create\_s3\_bucket) | n/a | `bool` | `true` | no |
| <a name="input_ecrs"></a> [ecrs](#input\_ecrs) | List of ECR repositories | `list(string)` | `[]` | no |
| <a name="input_enable_log_file_validation"></a> [enable\_log\_file\_validation](#input\_enable\_log\_file\_validation) | Specifies whether log file integrity validation is enabled. Creates signed digest for validated contents of logs | `bool` | `true` | no |
| <a name="input_enable_logging"></a> [enable\_logging](#input\_enable\_logging) | Enable logging for the trail | `bool` | `true` | no |
| <a name="input_event_selector"></a> [event\_selector](#input\_event\_selector) | Specifies an event selector for enabling data event logging. See: https://www.terraform.io/docs/providers/aws/r/cloudtrail.html for details on this variable | <pre>list(object({<br>    include_management_events = bool<br>    read_write_type           = string<br><br>    data_resource = list(object({<br>      type   = string<br>      values = list(string)<br>    }))<br>  }))</pre> | `[]` | no |
| <a name="input_include_global_service_events"></a> [include\_global\_service\_events](#input\_include\_global\_service\_events) | Specifies whether the trail is publishing events from global services such as IAM to the log files | `bool` | `true` | no |
| <a name="input_is_multi_region_trail"></a> [is\_multi\_region\_trail](#input\_is\_multi\_region\_trail) | Specifies whether the trail is created in the current region or in all regions | `bool` | `true` | no |
| <a name="input_is_organization_trail"></a> [is\_organization\_trail](#input\_is\_organization\_trail) | The trail is an AWS Organizations trail | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Name CloudTrail | `string` | n/a | yes |
| <a name="input_sns_topic_name"></a> [sns\_topic\_name](#input\_sns\_topic\_name) | Specifies the name of the Amazon SNS topic defined for notification of log file delivery | `string` | `null` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users | `list(any)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_users"></a> [users](#output\_users) | created users data |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
