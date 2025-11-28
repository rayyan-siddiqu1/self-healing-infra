# ==================================
# CloudWatch Dashboard
# ==================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-main"

  dashboard_body = jsonencode({
    widgets = [
      # EC2 CPU Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average", label = "Avg CPU" }],
            ["...", { stat = "Maximum", label = "Max CPU" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EC2 CPU Utilization"
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },
      # Memory Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["CWAgent", "mem_used_percent", { stat = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Memory Utilization"
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      },
      # ALB Response Time
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ALB Response Time"
          period  = 300
        }
        width  = 8
        height = 6
        x      = 0
        y      = 6
      },
      # ALB Request Count
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ALB Request Count"
          period  = 300
        }
        width  = 8
        height = 6
        x      = 8
        y      = 6
      },
      # Target Health
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", { stat = "Average", label = "Healthy" }],
            [".", "UnHealthyHostCount", { stat = "Average", label = "Unhealthy" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Target Health"
          period  = 300
        }
        width  = 8
        height = 6
        x      = 16
        y      = 6
      },
      # Lambda Invocations
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Invocations"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 0
        y      = 12
      },
      # Lambda Errors
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", { stat = "Sum" }],
            [".", "Throttles", { stat = "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Errors & Throttles"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 12
        y      = 12
      }
    ]
  })
}

# ==================================
# CloudWatch Metric Filters
# ==================================

# Error count metric filter
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.project_name}-${var.environment}-error-count"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "[time, request_id, level = ERROR*, ...]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "SelfHealingInfra/Lambda"
    value     = "1"
    default_value = 0
  }
}

# Remediation triggered count
resource "aws_cloudwatch_log_metric_filter" "remediation_count" {
  name           = "${var.project_name}-${var.environment}-remediation-count"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "[time, request_id, level, msg = \"*Remediation triggered*\", ...]"

  metric_transformation {
    name      = "RemediationCount"
    namespace = "SelfHealingInfra/Remediation"
    value     = "1"
    default_value = 0
  }
}

# High CPU remediation count
resource "aws_cloudwatch_log_metric_filter" "high_cpu_remediation" {
  name           = "${var.project_name}-${var.environment}-high-cpu-remediation"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "[time, request_id, level, msg = \"*Handling high CPU*\", ...]"

  metric_transformation {
    name      = "HighCPURemediationCount"
    namespace = "SelfHealingInfra/Remediation"
    value     = "1"
    default_value = 0
  }
}

# Memory clear count
resource "aws_cloudwatch_log_metric_filter" "memory_clear" {
  name           = "${var.project_name}-${var.environment}-memory-clear"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "[time, request_id, level, msg = \"*Handling high memory*\", ...]"

  metric_transformation {
    name      = "MemoryClearCount"
    namespace = "SelfHealingInfra/Remediation"
    value     = "1"
    default_value = 0
  }
}

# Disk cleanup count
resource "aws_cloudwatch_log_metric_filter" "disk_cleanup" {
  name           = "${var.project_name}-${var.environment}-disk-cleanup"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "[time, request_id, level, msg = \"*Handling high disk*\", ...]"

  metric_transformation {
    name      = "DiskCleanupCount"
    namespace = "SelfHealingInfra/Remediation"
    value     = "1"
    default_value = 0
  }
}

# Scaling operations count
resource "aws_cloudwatch_log_metric_filter" "scaling_operations" {
  name           = "${var.project_name}-${var.environment}-scaling-operations"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "[time, request_id, level, msg = \"*Scaling*\", ...]"

  metric_transformation {
    name      = "ScalingOperationCount"
    namespace = "SelfHealingInfra/Remediation"
    value     = "1"
    default_value = 0
  }
}

# Notification count
resource "aws_cloudwatch_log_metric_filter" "notification_count" {
  count          = var.create_notification_metrics ? 1 : 0
  name           = "${var.project_name}-${var.environment}-notification-count"
  log_group_name = "/aws/lambda/${var.project_name}-${var.environment}-notify"
  pattern        = "[time, request_id, level, msg = \"*notification sent*\", ...]"

  metric_transformation {
    name      = "NotificationCount"
    namespace = "SelfHealingInfra/Notifications"
    value     = "1"
    default_value = 0
  }
}

# Remediation success count
resource "aws_cloudwatch_log_metric_filter" "remediation_success" {
  name           = "${var.project_name}-${var.environment}-remediation-success"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "[time, request_id, level, msg = \"*successfully*\", ...]"

  metric_transformation {
    name      = "RemediationSuccessCount"
    namespace = "SelfHealingInfra/Remediation"
    value     = "1"
    default_value = 0
  }
}

# Remediation failure count
resource "aws_cloudwatch_log_metric_filter" "remediation_failure" {
  name           = "${var.project_name}-${var.environment}-remediation-failure"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "[time, request_id, level = ERROR*, msg = \"*remediation*\", ...]"

  metric_transformation {
    name      = "RemediationFailureCount"
    namespace = "SelfHealingInfra/Remediation"
    value     = "1"
    default_value = 0
  }
}
