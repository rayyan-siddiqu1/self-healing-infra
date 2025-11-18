#!/bin/bash
# ==================================
# Complete Deployment Script
# ==================================
# This script deploys the entire self-healing infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║   Self-Healing Infrastructure Deployer   ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
echo -e "${BLUE}→ Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
  echo -e "${RED}✗ Terraform not found${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Terraform: $(terraform version | head -n1)${NC}"

if ! command -v aws &> /dev/null; then
  echo -e "${RED}✗ AWS CLI not found${NC}"
  exit 1
fi
echo -e "${GREEN}✓ AWS CLI: $(aws --version)${NC}"

# Verify AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
  echo -e "${RED}✗ AWS credentials not configured${NC}"
  echo -e "${YELLOW}  Run: aws configure${NC}"
  exit 1
fi
echo -e "${GREEN}✓ AWS credentials configured${NC}"

# Check SSH key
SSH_KEY="$SCRIPT_DIR/environments/infra-key.pem"
if [ ! -f "$SSH_KEY" ]; then
  echo -e "${RED}✗ SSH key not found at: $SSH_KEY${NC}"
  exit 1
fi
echo -e "${GREEN}✓ SSH key found${NC}"

# Set correct permissions on SSH key
chmod 400 "$SSH_KEY"
echo -e "${GREEN}✓ SSH key permissions set${NC}"

# Step 1: Create backend resources
echo -e "\n${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 1: Setting up Terraform Backend${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

BUCKET_NAME="self-healing-infra-terraform-state"

# Check if bucket exists
if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
  echo -e "${YELLOW}→ Creating S3 bucket for Terraform state...${NC}"
  aws s3 mb "s3://$BUCKET_NAME" --region us-east-1

  echo -e "${YELLOW}→ Enabling bucket versioning...${NC}"
  aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

  echo -e "${YELLOW}→ Enabling bucket encryption...${NC}"
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

  echo -e "${GREEN}✓ S3 bucket created${NC}"
else
  echo -e "${GREEN}✓ S3 bucket already exists${NC}"
fi

# Check if DynamoDB table exists
if ! aws dynamodb describe-table --table-name terraform-state-lock --region us-east-1 &> /dev/null; then
  echo -e "${YELLOW}→ Creating DynamoDB table for state locking...${NC}"
  aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1

  echo -e "${YELLOW}→ Waiting for table to be active...${NC}"
  aws dynamodb wait table-exists --table-name terraform-state-lock --region us-east-1
  echo -e "${GREEN}✓ DynamoDB table created${NC}"
else
  echo -e "${GREEN}✓ DynamoDB table already exists${NC}"
fi

# Step 2: Package Lambda function
echo -e "\n${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 2: Packaging Lambda Function${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

LAMBDA_DIR="lambda/functions/trigger_remediation"
echo -e "${YELLOW}→ Packaging Lambda function...${NC}"
cd "$LAMBDA_DIR"
zip -q -r function.zip main.py
echo -e "${GREEN}✓ Lambda function packaged: $(ls -lh function.zip | awk '{print $5}')${NC}"
cd "$SCRIPT_DIR"

# Step 3: Deploy infrastructure with Terraform
echo -e "\n${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 3: Deploying Infrastructure${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

cd environments

echo -e "${YELLOW}→ Initializing Terraform...${NC}"
terraform init

echo -e "${YELLOW}→ Validating configuration...${NC}"
terraform validate
echo -e "${GREEN}✓ Configuration valid${NC}"

echo -e "${YELLOW}→ Formatting Terraform files...${NC}"
terraform fmt -recursive

echo -e "\n${YELLOW}→ Planning deployment...${NC}"
terraform plan -out=tfplan

echo -e "\n${BLUE}═══════════════════════════════════════════${NC}"
read -p "$(echo -e ${YELLOW}Ready to deploy? This will create AWS resources. [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${RED}Deployment cancelled${NC}"
  exit 1
fi

echo -e "\n${YELLOW}→ Applying Terraform configuration...${NC}"
echo -e "${YELLOW}  This will take 5-10 minutes...${NC}\n"
terraform apply tfplan

echo -e "\n${GREEN}✓ Infrastructure deployed successfully!${NC}"

# Step 4: Get outputs
echo -e "\n${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 4: Deployment Information${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

echo -e "\n${BLUE}Application URLs:${NC}"
echo -e "  ${GREEN}Application:${NC}  $(terraform output -raw application_url)"
echo -e "  ${GREEN}Health Check:${NC} $(terraform output -raw health_check_url)"
echo -e "  ${GREEN}Load Balancer:${NC} $(terraform output -raw alb_dns_name)"

echo -e "\n${BLUE}Infrastructure:${NC}"
echo -e "  ${GREEN}VPC ID:${NC}       $(terraform output -raw vpc_id)"
echo -e "  ${GREEN}ASG Name:${NC}     $(terraform output -raw asg_name)"
echo -e "  ${GREEN}Lambda:${NC}       $(terraform output -raw lambda_function_name)"

# Save outputs to file
terraform output -json > "$SCRIPT_DIR/terraform-outputs.json"
echo -e "\n${GREEN}✓ Outputs saved to: terraform-outputs.json${NC}"

cd "$SCRIPT_DIR"

# Step 5: Set up Ansible inventory
echo -e "\n${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 5: Setting up Ansible Inventory${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

if [ -f "scripts/update_ansible_inventory.sh" ]; then
  echo -e "${YELLOW}→ Waiting for instances to be ready (30 seconds)...${NC}"
  sleep 30

  echo -e "${YELLOW}→ Updating Ansible inventory...${NC}"
  bash scripts/update_ansible_inventory.sh
else
  echo -e "${YELLOW}! Inventory script not found, skipping...${NC}"
fi

# Final steps
echo -e "\n${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}✓ Deployment Complete!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}Important Next Steps:${NC}"
echo -e "1. ${GREEN}Check your email${NC} (rayyan@rootsraja.in) and confirm SNS subscription"
echo -e "2. ${GREEN}Test the application:${NC}"
echo -e "   curl $(cd environments && terraform output -raw health_check_url)"
echo -e "\n3. ${GREEN}Test Ansible connectivity:${NC}"
echo -e "   cd ansible"
echo -e "   ansible all -i inventories/prod/aws_ec2.yml -m ping"
echo -e "\n4. ${GREEN}View CloudWatch Dashboard:${NC}"
echo -e "   https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:"

echo -e "\n${YELLOW}Monitor logs:${NC}"
echo -e "aws logs tail /aws/lambda/self-healing-infra-prod-trigger-remediation --follow"

echo -e "\n${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Deployment successful! 🎉               ║${NC}"
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}\n"
