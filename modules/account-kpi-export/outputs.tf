output "lambda_function_arn" {
  description = "ARN of the weekly KPI collector Lambda function."
  value       = module.lambda_function.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the weekly KPI collector Lambda function."
  value       = module.lambda_function.lambda_function_name
}

output "schedule_arns" {
  description = "ARNs of the enabled weekly EventBridge Scheduler schedules."
  value       = module.scheduler.eventbridge_schedule_arns
}

output "failure_queue_arn" {
  description = "ARN of the shared Scheduler delivery and Lambda handler failure queue."
  value       = module.failure_queue.queue_arn
}

output "failure_queue_url" {
  description = "URL of the shared Scheduler delivery and Lambda handler failure queue."
  value       = module.failure_queue.queue_url
}

output "alarm_arns" {
  description = "ARNs of the Lambda error and visible failure-queue alarms."
  value = {
    lambda_errors = module.lambda_errors_alarm.cloudwatch_metric_alarm_arn
    failure_queue = module.failure_queue_alarm.cloudwatch_metric_alarm_arn
  }
}
