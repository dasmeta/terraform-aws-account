data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "account_kpi_export" {
  count = (
    var.account_kpi_export.enabled &&
    var.account_kpi_export.cost.enabled &&
    var.account_kpi_export.cost.scope == "organization"
  ) ? 1 : 0
}

data "aws_region" "current" {
  provider = aws

  # Terraform 1.3 has no check blocks, so this existing data source carries
  # the cross-data-source validation for organization-wide cost collection.
  lifecycle {
    precondition {
      condition = (
        var.account_kpi_export.enabled &&
        var.account_kpi_export.cost.enabled &&
        var.account_kpi_export.cost.scope == "organization"
        ) ? (
        data.aws_caller_identity.current.account_id ==
        data.aws_organizations_organization.account_kpi_export[0].master_account_id
      ) : true
      error_message = "Organization cost scope must be deployed from the AWS Organizations management account."
    }
  }
}

data "aws_db_instances" "rds_free_storage" {
  count = var.rds_free_storage_alarms.enabled ? 1 : 0
}

data "aws_db_instances" "rds_free_storage_virginia" {
  count    = var.rds_free_storage_alarms.enabled ? 1 : 0
  provider = aws.virginia
}
