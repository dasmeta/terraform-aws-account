module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.21.0"

  function_name = "${var.name}-lambda"
  description   = "lambda function to read aws previous date cost and push into webhook endpoint"
  handler       = "index.handler"
  runtime       = "nodejs22.x"

  ## we disable function .zip content generation via code and use .zip for being able to use the module in tf cloud
  # source_path = "${path.module}/src/"
  create_package         = false
  local_existing_package = "${path.module}/account-cost-report-lambda.zip"

  publish                           = true
  cloudwatch_logs_retention_in_days = var.logs_retention_in_days
  environment_variables = {
    WEBHOOK_ENDPOINT = var.webhook_endpoint
  }

  attach_policy_statements = true
  policy_statements = {
    getAccountCostData = {
      effect    = "Allow",
      actions   = ["ce:GetCostAndUsage"],
      resources = ["arn:aws:ce:us-east-1:${data.aws_caller_identity.current.account_id}:/GetCostAndUsage"]
    }
  }
}

module "event_bridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "3.17.1"

  create_bus = var.event_bridge_bus.create
  bus_name   = var.event_bridge_bus.name

  attach_lambda_policy = true
  lambda_target_arns   = [module.lambda_function.lambda_function_arn]
  role_name            = "${var.name}-role"

  schedules = {
    "${var.name}-schedule" = {
      description         = "Trigger for ${var.name}-lambda"
      schedule_expression = var.event_bridge_bus.schedule
      timezone            = var.event_bridge_bus.timezone
      arn                 = module.lambda_function.lambda_function_arn
      input               = jsonencode({ "job" : "event-bus-scheduled-cron-to-trigger-lambda-to-collect-and-send-previous-day-cost-report" })
    }
  }
}
