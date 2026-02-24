module "this" {
  source = "../../"
  # disable default enabled ones
  password_policy = {
    enabled = false
  }
  enforce_mfa = {
    enabled = false
  }

  # enable alarm account level actions, and security hub by default will use them(the configured notification channels of account) for alerting/notify
  alarm_actions = {
    enabled = true
    slack_webhooks = [
      {
        hook_url = var.slack_webhook_url
        channel  = var.slack_channel_name
        username = "reporter"
      }
    ]
    security_hub_alarms = { # by default use_account_topic = true so it will use account level sns topic(and channels) for security hub alarms
      enabled = true
      # use_account_topic = false # if you want to use custom alarm actions(channels), you can set use_account_topic to false and set custom_alarm_actions to a map of alarm actions or a list of alarm actions
      # custom_alarm_actions = {  # here we set custom alarm actions for security hub findings, all possible channels are supported
      #   slack_webhooks = [
      #     {
      #       hook_url = var.slack_webhook_url
      #       channel  = var.slack_channel_name
      #       username = "reporter-security-hub"
      #     }
      #   ]
      # }
    }
  }

  # enable security hub, NOTE: here we just enable security hub and needed modules for it, alarms configs for security hub are in alarm_actions variable
  security_hub = {
    enabled = true
    # enable_security_hub                    = false # by default this is true, set false if it fails with error about security hub is is enabled already, this option is about to not create an object that is exists already
    # enable_security_hub_finding_aggregator = false # by default this is true, but because of error "A finding aggregator cannot be created by a member account" this may be set to false to overcome the error
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
