# ==================================
# SNS Module - Outputs
# ==================================

output "topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.alerts.arn
}

output "topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.alerts.name
}

output "topic_id" {
  description = "ID of the SNS topic"
  value       = aws_sns_topic.alerts.id
}

output "kms_key_id" {
  description = "ID of the KMS key used for encryption"
  value       = var.enable_encryption ? aws_kms_key.sns[0].id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = var.enable_encryption ? aws_kms_key.sns[0].arn : null
}

output "email_subscription_arns" {
  description = "ARNs of email subscriptions"
  value       = aws_sns_topic_subscription.email[*].arn
}

output "lambda_subscription_arns" {
  description = "ARNs of Lambda subscriptions"
  value       = aws_sns_topic_subscription.lambda[*].arn
}
