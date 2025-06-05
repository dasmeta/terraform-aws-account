module "this" {
  source = "../../"

  alarm_actions = {
    enabled    = true
    topic_name = "test-account-alarms-handling"
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
