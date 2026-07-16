resource "aws_cloudwatch_metric_alarm" "haproxy_auto_recovery" {
  count = var.enable_haproxy_auto_recovery ? 1 : 0

  alarm_name          = "${var.project_name}-haproxy-system-recovery"
  alarm_description   = "Recover the HAProxy EC2 instance after repeated system status-check failures."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.haproxy.id
  }

  alarm_actions = ["arn:${data.aws_partition.current.partition}:automate:${var.aws_region}:ec2:recover"]
}
