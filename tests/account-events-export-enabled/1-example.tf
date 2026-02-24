module "this" {
  source = "../../"

  enforce_mfa = {
    enabled = false # here we disable this for testing purpose to not have other/extra options enabled beside main cost_report_export one for this test/example
  }

  account_events_export = {
    enabled          = true
    webhook_endpoint = "https://n8n.example.com/webhook/uuid?accountId=123475168"
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
