# ==================================
# EC2 Module - Input Variables
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

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2 instances"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB"
  type        = string
}

variable "target_group_arns" {
  description = "List of target group ARNs to attach to ASG"
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID to use for instances (leave empty for latest Amazon Linux 2023)"
  type        = string
  default     = ""
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

variable "cloudwatch_config" {
  description = "CloudWatch agent configuration JSON"
  type        = string
  default     = <<-EOF
  {
    "agent": {
      "metrics_collection_interval": 60,
      "run_as_user": "root"
    },
    "metrics": {
      "namespace": "SelfHealingInfra",
      "metrics_collected": {
        "cpu": {
          "measurement": [
            {
              "name": "cpu_usage_idle",
              "rename": "CPU_IDLE",
              "unit": "Percent"
            },
            "cpu_usage_iowait"
          ],
          "metrics_collection_interval": 60,
          "totalcpu": false
        },
        "disk": {
          "measurement": [
            {
              "name": "used_percent",
              "rename": "DISK_USED",
              "unit": "Percent"
            }
          ],
          "metrics_collection_interval": 60,
          "resources": [
            "*"
          ]
        },
        "diskio": {
          "measurement": [
            "io_time"
          ],
          "metrics_collection_interval": 60,
          "resources": [
            "*"
          ]
        },
        "mem": {
          "measurement": [
            {
              "name": "mem_used_percent",
              "rename": "MEMORY_USED",
              "unit": "Percent"
            }
          ],
          "metrics_collection_interval": 60
        },
        "netstat": {
          "measurement": [
            "tcp_established",
            "tcp_time_wait"
          ],
          "metrics_collection_interval": 60
        }
      }
    },
    "logs": {
      "logs_collected": {
        "files": {
          "collect_list": [
            {
              "file_path": "/var/log/messages",
              "log_group_name": "/aws/ec2/self-healing-infra",
              "log_stream_name": "{instance_id}/messages"
            },
            {
              "file_path": "/var/log/httpd/access_log",
              "log_group_name": "/aws/ec2/self-healing-infra",
              "log_stream_name": "{instance_id}/httpd-access"
            },
            {
              "file_path": "/var/log/httpd/error_log",
              "log_group_name": "/aws/ec2/self-healing-infra",
              "log_stream_name": "{instance_id}/httpd-error"
            }
          ]
        }
      }
    }
  }
  EOF
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
