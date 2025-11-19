# ==================================
# CloudWatch Module - Monitoring and Alarms
# ==================================

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-logs"
    }
  )
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-lambda-logs"
    }
  )
}

# CPU Utilization Alarm - High
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-cpu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.cpu_threshold_high
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  tags = var.tags
}

# CPU Utilization Alarm - Low (for scale down)
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-${var.environment}-cpu-utilization-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.cpu_threshold_low
  alarm_description   = "This metric monitors EC2 CPU utilization for scale down"
  alarm_actions       = [var.scale_down_policy_arn]

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  tags = var.tags
}

# Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.project_name}-${var.environment}-memory-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.memory_evaluation_periods
  metric_name         = "MEMORY_USED"
  namespace           = "SelfHealingInfra"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "This metric monitors EC2 memory utilization"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  tags = var.tags
}

# Disk Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "${var.project_name}-${var.environment}-disk-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.disk_evaluation_periods
  metric_name         = "DISK_USED"
  namespace           = "SelfHealingInfra"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.disk_threshold
  alarm_description   = "This metric monitors EC2 disk utilization"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  tags = var.tags
}

# ALB Target Health Alarm
resource "aws_cloudwatch_metric_alarm" "target_health" {
  count = var.enable_alb_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-unhealthy-targets"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = var.healthy_host_threshold
  alarm_description   = "This metric monitors the number of healthy targets"
  alarm_actions       = var.alarm_actions

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# ALB Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "response_time" {
  count = var.enable_alb_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = var.response_time_threshold
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# ALB 5XX Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count = var.enable_alb_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.error_5xx_threshold
  alarm_description   = "This metric monitors 5XX errors from targets"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# CloudWatch Dashboard (optional)
resource "aws_cloudwatch_dashboard" "main" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average", label = "CPU Usage" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["SelfHealingInfra", "MEMORY_USED", { stat = "Average", label = "Memory Usage" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Memory Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["SelfHealingInfra", "DISK_USED", { stat = "Average", label = "Disk Usage" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Disk Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average", label = "Response Time" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ALB Response Time"
        }
      }
    ]
  })
}

data "aws_region" "current" {}
