# ==================================
# SNS Module - Notification Topics
# ==================================

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-${var.environment}-alerts"
  display_name      = "${var.project_name} ${var.environment} Alerts"
  kms_master_key_id = var.enable_encryption ? aws_kms_key.sns[0].id : null

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alerts"
    }
  )
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Sid    = "AllowEventBridgeToPublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Sid    = "AllowAutoScalingToPublish"
        Effect = "Allow"
        Principal = {
          Service = "autoscaling.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Email Subscriptions
resource "aws_sns_topic_subscription" "email" {
  count = length(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

# Lambda Subscriptions
resource "aws_sns_topic_subscription" "lambda" {
  count = length(var.lambda_endpoints)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = var.lambda_endpoints[count.index]
}

# SMS Subscriptions (optional)
resource "aws_sns_topic_subscription" "sms" {
  count = length(var.sms_endpoints)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "sms"
  endpoint  = var.sms_endpoints[count.index]
}

# KMS Key for SNS Encryption (optional)
resource "aws_kms_key" "sns" {
  count = var.enable_encryption ? 1 : 0

  description             = "KMS key for SNS topic encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch to use the key"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "sns" {
  count = var.enable_encryption ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-sns"
  target_key_id = aws_kms_key.sns[0].key_id
}

data "aws_caller_identity" "current" {}
