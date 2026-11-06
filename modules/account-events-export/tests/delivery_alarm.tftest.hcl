mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:root"
    }
  }

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
}

run "uses_the_configured_delivery_queue_age_threshold" {
  command = plan

  variables {
    webhook_endpoint = "https://example.com/webhooks/account-events"
    delivery = {
      oldest_message_age_threshold_seconds = 600
    }
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.event_queue_oldest_message_age.threshold == 600
    error_message = "The primary event-delivery queue age alarm must use delivery.oldest_message_age_threshold_seconds."
  }
}

run "rejects_a_delivery_queue_age_threshold_below_one_minute" {
  command = plan

  variables {
    webhook_endpoint = "https://example.com/webhooks/account-events"
    delivery = {
      oldest_message_age_threshold_seconds = 59
    }
  }

  expect_failures = [var.delivery]
}

run "rejects_a_delivery_queue_age_threshold_beyond_message_retention" {
  command = plan

  variables {
    webhook_endpoint = "https://example.com/webhooks/account-events"
    delivery = {
      message_retention_seconds            = 600
      oldest_message_age_threshold_seconds = 601
    }
  }

  expect_failures = [var.delivery]
}
