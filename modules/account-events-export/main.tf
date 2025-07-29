module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.21.1"

  function_name = "${var.name}-lambda"
  description   = "lambda function to be triggered from eventbridge and push into webhook endpoint"
  handler       = "index.handler"
  runtime       = "nodejs22.x"

  ## we disable function .zip content generation via code and use .zip for being able to use the module in tf cloud
  # source_path = "${path.module}/src/"
  create_package         = false
  local_existing_package = "${path.module}/account-events-export-lambda.zip"

  publish                           = true
  cloudwatch_logs_retention_in_days = var.logs_retention_in_days
  environment_variables = {
    WEBHOOK_ENDPOINT = var.webhook_endpoint
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

  rules = {
    "${var.name}" = {
      description   = "Capture all aws important events and sent/export to webhook endpoint"
      event_pattern = jsonencode({ "source" : var.event_bridge_bus.rule_pattern_source })
      enabled       = true
    }
  }

  targets = {
    "${var.name}" = [{
      name            = "Target for ${var.name}-rule events"
      description     = "Trigger for ${var.name}-lambda"
      arn             = module.lambda_function.lambda_function_arn
      attach_role_arn = true
    }]
  }
}
