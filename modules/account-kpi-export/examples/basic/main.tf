provider "aws" {
  region = "eu-central-1"
}

module "account_kpi_export" {
  source = "../.."

  cloudbrowser = {
    base_url        = "https://cloudbrowser.example.com"
    client_id       = 123
    secret_arn      = "arn:aws:secretsmanager:eu-central-1:111122223333:secret:example-account-kpi"
    aws_provider_id = 1
  }

  application = {
    enabled = false
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
