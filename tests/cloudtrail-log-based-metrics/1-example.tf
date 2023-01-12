module "this" {
  source = "../../"

  cloudtrail = {
    enabled                = true
    enable_cloudwatch_logs = true
    name                   = "audit-my-project"
  }

  log_metrics = {
    enabled = true
    metrics_patterns = [
      {
        name    = "new-user-created"
        pattern = "{ $.eventName = CreateUser }"
      },
      {
        name    = "user-deleted"
        pattern = "{ $.eventName = DeleteUser }"
      }
    ]
  }
}
