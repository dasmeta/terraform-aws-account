output "lambda_function_data" {
  description = "Lambda function and event source mapping data"
  value       = module.lambda_function
}

output "event_bridge_data" {
  description = "EventBridge rule and target data"
  value       = module.event_bridge
}

output "event_queue_data" {
  description = "Source queue identifiers for pending event deliveries"
  value = {
    arn  = module.event_queue.queue_arn
    name = module.event_queue.queue_name
    url  = module.event_queue.queue_url
  }
}

output "failed_event_queue_data" {
  description = "Dead-letter queue identifiers for terminal event-delivery failures"
  value = {
    arn  = module.event_queue.dead_letter_queue_arn
    name = module.event_queue.dead_letter_queue_name
    url  = module.event_queue.dead_letter_queue_url
  }
}
