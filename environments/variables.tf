# ==================================
# Self-Healing Infrastructure - Variables
# ==================================

# General Configuration
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = ""
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to instances"
  type        = list(string)
  default     = []
}

variable "min_instance_count" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "max_instance_count" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 4
}

variable "desired_instance_count" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

# Monitoring Thresholds
variable "cpu_threshold" {
  description = "CPU utilization threshold for high alarm (%)"
  type        = number
  default     = 80
}

variable "cpu_threshold_low" {
  description = "CPU utilization threshold for low alarm (%)"
  type        = number
  default     = 20
}

variable "memory_threshold" {
  description = "Memory utilization threshold (%)"
  type        = number
  default     = 85
}

variable "disk_threshold" {
  description = "Disk utilization threshold (%)"
  type        = number
  default     = 85
}

# Notifications
variable "alert_emails" {
  description = "List of email addresses to receive alerts"
  type        = list(string)
  default     = []
}

# Lambda Configuration
variable "lambda_zip_path" {
  description = "Path to Lambda deployment package"
  type        = string
  default     = "../lambda/functions/trigger_remediation/function.zip"
}

# Tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
