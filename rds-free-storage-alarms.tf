resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  for_each = var.rds_free_storage_alarms.enabled ? toset(data.aws_db_instances.rds_free_storage[0].instance_identifiers) : toset([])

  alarm_name          = "${each.key}-free-storage-space"
  alarm_description   = "RDS instance ${each.key} has less than the configured free storage threshold."
  comparison_operator = var.rds_free_storage_alarms.comparison_operator
  evaluation_periods  = var.rds_free_storage_alarms.evaluation_periods
  datapoints_to_alarm = var.rds_free_storage_alarms.datapoints_to_alarm
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = var.rds_free_storage_alarms.period
  statistic           = var.rds_free_storage_alarms.statistic
  threshold           = var.rds_free_storage_alarms.threshold
  treat_missing_data  = var.rds_free_storage_alarms.treat_missing_data

  dimensions = {
    DBInstanceIdentifier = each.key
  }

  alarm_actions = var.alarm_actions.enabled ? [module.cloudwatch_alarm_actions[0].topic_arn] : []
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_virginia" {
  provider = aws.virginia

  for_each = var.rds_free_storage_alarms.enabled ? toset(data.aws_db_instances.rds_free_storage_virginia[0].instance_identifiers) : toset([])

  alarm_name          = "${each.key}-free-storage-space"
  alarm_description   = "RDS instance ${each.key} has less than the configured free storage threshold."
  comparison_operator = var.rds_free_storage_alarms.comparison_operator
  evaluation_periods  = var.rds_free_storage_alarms.evaluation_periods
  datapoints_to_alarm = var.rds_free_storage_alarms.datapoints_to_alarm
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = var.rds_free_storage_alarms.period
  statistic           = var.rds_free_storage_alarms.statistic
  threshold           = var.rds_free_storage_alarms.threshold
  treat_missing_data  = var.rds_free_storage_alarms.treat_missing_data

  dimensions = {
    DBInstanceIdentifier = each.key
  }

  alarm_actions = var.alarm_actions_virginia.enabled ? [module.cloudwatch_alarm_actions_virginia[0].topic_arn] : []
}
