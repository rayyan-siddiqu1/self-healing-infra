# ==================================
# CloudWatch Module - Input Variables
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

variable "autoscaling_group_name" {
  description = "Name of the Auto Scaling group to monitor"
  type        = string
}

variable "scale_down_policy_arn" {
  description = "ARN of the scale down policy"
  type        = string
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 7
}

variable "alarm_period" {
  description = "Period in seconds over which to evaluate alarms"
  type        = number
  default     = 300
}

# CPU Alarm Variables
variable "cpu_threshold_high" {
  description = "CPU utilization threshold for high alarm"
  type        = number
  default     = 80
}

variable "cpu_threshold_low" {
  description = "CPU utilization threshold for low alarm"
  type        = number
  default     = 20
}

variable "cpu_evaluation_periods" {
  description = "Number of periods to evaluate for CPU alarms"
  type        = number
  default     = 2
}

# Memory Alarm Variables
variable "memory_threshold" {
  description = "Memory utilization threshold"
  type        = number
  default     = 85
}

variable "memory_evaluation_periods" {
  description = "Number of periods to evaluate for memory alarms"
  type        = number
  default     = 2
}

# Disk Alarm Variables
variable "disk_threshold" {
  description = "Disk utilization threshold"
  type        = number
  default     = 85
}

variable "disk_evaluation_periods" {
  description = "Number of periods to evaluate for disk alarms"
  type        = number
  default     = 2
}

# ALB Alarm Variables
variable "enable_alb_alarms" {
  description = "Enable ALB-related alarms"
  type        = bool
  default     = true
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group"
  type        = string
  default     = ""
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB"
  type        = string
  default     = ""
}

variable "healthy_host_threshold" {
  description = "Minimum number of healthy hosts"
  type        = number
  default     = 1
}

variable "response_time_threshold" {
  description = "Response time threshold in seconds"
  type        = number
  default     = 2
}

variable "error_5xx_threshold" {
  description = "Threshold for 5XX errors"
  type        = number
  default     = 10
}

# Dashboard Variables
variable "create_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
