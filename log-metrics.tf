module "log_metric_filter" {
  source  = "dasmeta/monitoring/aws//modules/cloudwatch-log-based-metrics"
  version = "1.3.9"

  count = var.log_metrics.enabled ? 1 : 0

  metrics_patterns  = var.log_metrics.metrics_patterns
  log_group_name    = "${var.cloudtrail.name}-cloudtrail-logs"
  metrics_namespace = var.log_metrics.metrics_namespace

  depends_on = [
    module.cloudtrail
  ]
}
