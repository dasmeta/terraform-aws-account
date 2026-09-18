# Terraform 1.3 cross-variable validation uses this data source as a precondition carrier.
# tflint-ignore: terraform_unused_declarations
data "aws_partition" "current" {
  lifecycle {
    precondition {
      condition     = var.application.enabled || var.cost.enabled || var.security.enabled
      error_message = "At least one application, cost, or security source must be enabled."
    }
  }
}
