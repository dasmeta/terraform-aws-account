mock_provider "aws" {}

mock_provider "aws" {
  alias = "virginia"
}

mock_provider "archive" {}
mock_provider "external" {}
mock_provider "local" {}
mock_provider "null" {}
mock_provider "random" {}

run "omission_and_explicit_disable_create_no_exporter" {
  command = plan

  assert {
    condition     = output.omitted_exporter == null
    error_message = "Omitting account_kpi_export must create no exporter child and expose a null output."
  }

  assert {
    condition     = output.disabled_exporter == null
    error_message = "Explicitly disabling account_kpi_export must create no exporter child and expose a null output."
  }
}
