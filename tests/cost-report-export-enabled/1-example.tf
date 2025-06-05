module "this" {
  source = "../../"

  enforce_mfa = {
    enabled = false # here we disable this for testing purpose to not have other/extra options enabled beside main cost_report_export one for this test/example
  }

  cost_report_export = {
    enabled          = true
    webhook_endpoint = "https://example-webhook-endpoint.com"
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
