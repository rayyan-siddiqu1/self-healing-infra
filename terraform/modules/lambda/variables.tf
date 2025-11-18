# ==================================
# Lambda Module - Input Variables
# ==================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "self-healing-infra"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package zip file"
  type        = string
  default     = "../lambda/functions/trigger_remediation/function.zip"
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  type        = string
}

variable "autoscaling_group_name" {
  description = "Name of the Auto Scaling group"
  type        = string
}

variable "ansible_playbook_url" {
  description = "URL or path to Ansible playbooks"
  type        = string
  default     = ""
}

variable "lambda_environment_variables" {
  description = "Additional environment variables for Lambda function"
  type        = map(string)
  default     = {}
}

variable "enable_vpc" {
  description = "Enable VPC configuration for Lambda"
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Number of days to retain Lambda logs"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
