# ==================================
# Lambda Module - Outputs
# ==================================

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.trigger_remediation.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.trigger_remediation.arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.trigger_remediation.invoke_arn
}

output "function_qualified_arn" {
  description = "Qualified ARN of the Lambda function"
  value       = aws_lambda_function.trigger_remediation.qualified_arn
}

output "iam_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda.arn
}

output "iam_role_name" {
  description = "Name of the Lambda IAM role"
  value       = aws_iam_role.lambda.name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.arn
}
