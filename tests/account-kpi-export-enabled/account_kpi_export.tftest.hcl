mock_provider "aws" {
  override_during = plan

  mock_resource "aws_lambda_function" {
    defaults = {
      arn           = "arn:aws:lambda:eu-central-1:111122223333:function:example-kpi-export"
      qualified_arn = "arn:aws:lambda:eu-central-1:111122223333:function:example-kpi-export:1"
      version       = "1"
    }
  }

  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:eu-central-1:111122223333:example-kpi-export-failures"
      url = "https://sqs.eu-central-1.amazonaws.com/111122223333/example-kpi-export-failures"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:eu-central-1:111122223333:example-account-alarms"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/example-kpi-role"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::111122223333:policy/example-kpi-policy"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:root"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name   = "eu-central-1"
      region = "eu-central-1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

}

mock_provider "aws" {
  alias = "virginia"
}

mock_provider "archive" {}
mock_provider "external" {}
mock_provider "local" {}
mock_provider "null" {}
mock_provider "random" {}

run "custom_alarm_actions_only" {
  command = plan

  assert {
    condition     = output.account_kpi_export != null
    error_message = "An enabled exporter must expose operational identifiers."
  }

  assert {
    condition = toset(keys(output.account_kpi_export)) == toset([
      "lambda_function_arn", "lambda_function_name", "schedule_arns",
      "failure_queue_arn", "failure_queue_url", "alarm_arns"
    ])
    error_message = "The enabled exporter output must expose only operational identifiers."
  }

}

run "account_alarm_topic_is_merged" {
  command = plan

  variables {
    enable_alarm_actions = true
  }

  assert {
    condition = toset(keys(output.account_kpi_export)) == toset([
      "lambda_function_arn", "lambda_function_name", "schedule_arns",
      "failure_queue_arn", "failure_queue_url", "alarm_arns"
    ])
    error_message = "Account alarm integration must preserve the enabled exporter output shape."
  }
}
