locals {
  event_rule_name = "${replace(var.name, "_", "-")}-rule"
  event_rule_path = var.event_bridge_bus.name == "default" ? local.event_rule_name : "${var.event_bridge_bus.name}/${local.event_rule_name}"
  event_rule_arn  = "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${local.event_rule_path}"
}

module "event_queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "4.3.1"

  name                       = "${var.name}-queue"
  message_retention_seconds  = var.delivery.message_retention_seconds
  visibility_timeout_seconds = var.delivery.lambda_timeout_seconds * 6
  sqs_managed_sse_enabled    = true

  create_dlq                    = true
  dlq_name                      = "${var.name}-dlq"
  dlq_message_retention_seconds = var.delivery.dlq_retention_seconds
  dlq_sqs_managed_sse_enabled   = true
  redrive_policy = {
    maxReceiveCount = var.delivery.max_receive_count
  }

  create_queue_policy = true
  queue_policy_statements = {
    eventbridge = {
      sid     = "AllowEventBridgeDelivery"
      actions = ["sqs:SendMessage"]
      principals = [{
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }]
      conditions = [{
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [local.event_rule_arn]
      }]
    }
  }

  create_dlq_queue_policy = true
  dlq_queue_policy_statements = {
    eventbridge = {
      sid     = "AllowEventBridgeTargetFailures"
      actions = ["sqs:SendMessage"]
      principals = [{
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }]
      conditions = [{
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [local.event_rule_arn]
      }]
    }
  }
}

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.21.1"

  function_name = "${var.name}-lambda"
  description   = "Deliver buffered account events to the configured webhook endpoint"
  handler       = "index.handler"
  runtime       = "nodejs22.x"

  ## we disable function .zip content generation via code and use .zip for being able to use the module in tf cloud
  # source_path = "${path.module}/src/"
  create_package         = false
  local_existing_package = "${path.module}/account-events-export-lambda.zip"

  publish                           = true
  timeout                           = var.delivery.lambda_timeout_seconds
  reserved_concurrent_executions    = var.delivery.maximum_concurrency
  cloudwatch_logs_retention_in_days = var.logs_retention_in_days
  environment_variables = {
    WEBHOOK_ENDPOINT   = var.webhook_endpoint
    WEBHOOK_TIMEOUT_MS = tostring(var.delivery.webhook_timeout_seconds * 1000)
  }

  event_source_mapping = {
    event_queue = {
      event_source_arn        = module.event_queue.queue_arn
      batch_size              = 1
      function_response_types = ["ReportBatchItemFailures"]
      scaling_config = {
        maximum_concurrency = var.delivery.maximum_concurrency
      }
    }
  }

  attach_policy_statements = true
  policy_statements = {
    event_queue = {
      effect = "Allow"
      actions = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      resources = [module.event_queue.queue_arn]
    }
  }
}

module "event_bridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "3.17.1"

  create_bus = var.event_bridge_bus.create
  bus_name   = var.event_bridge_bus.name

  create_role = false

  rules = {
    (var.name) = {
      description   = "Capture important AWS account events and buffer them for webhook export"
      event_pattern = jsonencode({ "source" : var.event_bridge_bus.rule_pattern_source })
      enabled       = true
    }
  }

  targets = {
    (var.name) = [{
      name            = "Target for ${var.name}-rule events"
      description     = "Buffer events for ${var.name}-lambda"
      arn             = module.event_queue.queue_arn
      dead_letter_arn = module.event_queue.dead_letter_queue_arn
      retry_policy = {
        maximum_event_age_in_seconds = 86400
        maximum_retry_attempts       = 185
      }
    }]
  }

  depends_on = [module.event_queue]
}
