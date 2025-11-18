# ==================================
# SNS Module - Input Variables
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

variable "alert_emails" {
  description = "List of email addresses to receive alerts"
  type        = list(string)
  default     = []
}

variable "lambda_endpoints" {
  description = "List of Lambda function ARNs to subscribe to SNS"
  type        = list(string)
  default     = []
}

variable "sms_endpoints" {
  description = "List of phone numbers to receive SMS alerts"
  type        = list(string)
  default     = []
}

variable "enable_encryption" {
  description = "Enable encryption for SNS topic"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
