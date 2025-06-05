module "this" {
  source = "../../"

  alarm_actions = {

    security_hub_alarms = {
      enabled                                = true
      securityhub_action_target_name         = "test-sh"
      sns_topic_name                         = "test-sns"
      opsgenie_webhook                       = "https://example.com"
      enable_security_hub                    = false
      enable_security_hub_finding_aggregator = false
    }
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
