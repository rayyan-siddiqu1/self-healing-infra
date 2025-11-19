# ==================================
# Self-Healing Infrastructure - Production Environment
# ==================================

locals {
  project_name = "self-healing-infra"
  common_tags = merge(
    var.tags,
    {
      Project     = local.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# ==================================
# VPC Module
# ==================================

module "vpc" {
  source = "../../terraform/modules/vpc"

  project_name         = local.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = true
  enable_flow_logs     = true

  tags = local.common_tags
}

# ==================================
# SNS Module
# ==================================

module "sns" {
  source = "../../terraform/modules/sns"

  project_name      = local.project_name
  environment       = var.environment
  alert_emails      = var.alert_emails
  enable_encryption = false

  tags = local.common_tags
}

# ==================================
# ALB Module
# ==================================

module "alb" {
  source = "../../terraform/modules/alb"

  project_name      = local.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  health_check_path = "/health"
  enable_https      = false
  enable_stickiness = false

  tags = local.common_tags
}

# ==================================
# EC2 & Auto Scaling Module
# ==================================

module "ec2" {
  source = "../../terraform/modules/ec2"

  project_name           = local.project_name
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  alb_security_group_id  = module.alb.alb_security_group_id
  target_group_arns      = [module.alb.target_group_arn]
  instance_type          = var.instance_type
  key_pair_name          = var.key_pair_name
  ssh_cidr_blocks        = var.ssh_cidr_blocks
  min_instance_count     = var.min_instance_count
  max_instance_count     = var.max_instance_count
  desired_instance_count = var.desired_instance_count

  tags = local.common_tags

  depends_on = [module.alb]
}

# ==================================
# CloudWatch Monitoring Module
# ==================================

module "cloudwatch" {
  source = "../../terraform/modules/cloudwatch"

  project_name            = local.project_name
  environment             = var.environment
  autoscaling_group_name  = module.ec2.autoscaling_group_name
  scale_down_policy_arn   = module.ec2.scale_down_policy_arn
  alarm_actions           = [module.sns.topic_arn, module.ec2.scale_up_policy_arn]
  cpu_threshold_high      = var.cpu_threshold
  cpu_threshold_low       = var.cpu_threshold_low
  memory_threshold        = var.memory_threshold
  disk_threshold          = var.disk_threshold
  enable_alb_alarms       = true
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  alb_arn_suffix          = module.alb.alb_arn_suffix
  create_dashboard        = true

  tags = local.common_tags

  depends_on = [module.ec2, module.sns]
}

# ==================================
# Lambda Self-Healing Module
# ==================================

module "lambda" {
  source = "../../terraform/modules/lambda"

  project_name           = local.project_name
  environment            = var.environment
  sns_topic_arn          = module.sns.topic_arn
  autoscaling_group_name = module.ec2.autoscaling_group_name
  lambda_zip_path        = var.lambda_zip_path
  enable_vpc             = false

  lambda_environment_variables = {
    VPC_ID         = module.vpc.vpc_id
    ALB_DNS_NAME   = module.alb.alb_dns_name
    LOG_GROUP_NAME = module.cloudwatch.log_group_name
  }

  tags = local.common_tags

  depends_on = [module.sns, module.ec2]
}

# Subscribe Lambda to SNS Topic
resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = module.sns.topic_arn
  protocol  = "lambda"
  endpoint  = module.lambda.function_arn

  depends_on = [module.lambda]
}

# ==================================
# RDS Module (Optional - COMMENTED OUT)
# ==================================
# Uncomment and configure if you need a database
#
# module "rds" {
#   count  = var.enable_rds ? 1 : 0
#   source = "../../terraform/modules/rds"
#
#   project_name       = local.project_name
#   environment        = var.environment
#   vpc_id             = module.vpc.vpc_id
#   private_subnet_ids = module.vpc.private_subnet_ids
#   security_group_id  = module.ec2.security_group_id
#   instance_class     = var.db_instance_class
#   db_name            = var.db_name
#   db_username        = var.db_username
#   db_password        = var.db_password
#   tags               = local.common_tags
#
#   depends_on = [module.vpc]
# }