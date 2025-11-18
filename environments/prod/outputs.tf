# ==================================
# Self-Healing Infrastructure - Outputs
# ==================================

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.alb.target_group_arn
}

# EC2 Outputs
output "autoscaling_group_name" {
  description = "Name of the Auto Scaling group"
  value       = module.ec2.autoscaling_group_name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling group"
  value       = module.ec2.autoscaling_group_arn
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = module.ec2.launch_template_id
}

# CloudWatch Outputs
output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = module.cloudwatch.log_group_name
}

output "cpu_high_alarm_arn" {
  description = "ARN of the CPU high alarm"
  value       = module.cloudwatch.cpu_high_alarm_arn
}

output "memory_high_alarm_arn" {
  description = "ARN of the memory high alarm"
  value       = module.cloudwatch.memory_high_alarm_arn
}

output "disk_high_alarm_arn" {
  description = "ARN of the disk high alarm"
  value       = module.cloudwatch.disk_high_alarm_arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.cloudwatch.dashboard_name
}

# SNS Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = module.sns.topic_arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = module.sns.topic_name
}

# Lambda Outputs
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda.function_arn
}

# Access Information
output "application_url" {
  description = "URL to access the application"
  value       = "http://${module.alb.alb_dns_name}"
}

output "health_check_url" {
  description = "URL for health check endpoint"
  value       = "http://${module.alb.alb_dns_name}/health"
}
