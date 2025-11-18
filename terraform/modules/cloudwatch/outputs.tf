# ==================================
# CloudWatch Module - Outputs
# ==================================

output "log_group_name" {
  description = "Name of the application log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "log_group_arn" {
  description = "ARN of the application log group"
  value       = aws_cloudwatch_log_group.application.arn
}

output "lambda_log_group_name" {
  description = "Name of the Lambda log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "lambda_log_group_arn" {
  description = "ARN of the Lambda log group"
  value       = aws_cloudwatch_log_group.lambda.arn
}

output "cpu_high_alarm_arn" {
  description = "ARN of the CPU high utilization alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
}

output "cpu_low_alarm_arn" {
  description = "ARN of the CPU low utilization alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_low.arn
}

output "memory_high_alarm_arn" {
  description = "ARN of the memory high utilization alarm"
  value       = aws_cloudwatch_metric_alarm.memory_high.arn
}

output "disk_high_alarm_arn" {
  description = "ARN of the disk high utilization alarm"
  value       = aws_cloudwatch_metric_alarm.disk_high.arn
}

output "target_health_alarm_arn" {
  description = "ARN of the target health alarm"
  value       = var.enable_alb_alarms ? aws_cloudwatch_metric_alarm.target_health[0].arn : null
}

output "response_time_alarm_arn" {
  description = "ARN of the response time alarm"
  value       = var.enable_alb_alarms ? aws_cloudwatch_metric_alarm.response_time[0].arn : null
}

output "alb_5xx_alarm_arn" {
  description = "ARN of the ALB 5XX error alarm"
  value       = var.enable_alb_alarms ? aws_cloudwatch_metric_alarm.alb_5xx[0].arn : null
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = var.create_dashboard ? aws_cloudwatch_dashboard.main[0].dashboard_name : null
}
