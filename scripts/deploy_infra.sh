#!/bin/bash
# ==================================
# Deploy Self-Healing Infrastructure
# ==================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="../environments"
LAMBDA_DIR="../lambda/functions/trigger_remediation"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Self-Healing Infrastructure Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    echo "Please install Terraform: https://www.terraform.io/downloads"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Please configure AWS credentials using 'aws configure'"
    exit 1
fi

echo -e "${GREEN} Prerequisites check passed${NC}"
echo

# Check if terraform.tfvars exists
cd "$TERRAFORM_DIR"
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Warning: terraform.tfvars not found${NC}"
    echo "Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${YELLOW}Please edit terraform.tfvars with your values and run this script again${NC}"
    exit 0
fi

# Package Lambda function
echo -e "${YELLOW}Packaging Lambda function...${NC}"
cd "../lambda/functions/trigger_remediation"
if [ ! -f "function.zip" ]; then
    if [ -f "main.py" ]; then
        zip -q function.zip main.py
        echo -e "${GREEN} Lambda function packaged${NC}"
    else
        echo -e "${YELLOW}Warning: main.py not found, creating placeholder...${NC}"
        echo "# Placeholder Lambda function" > main.py
        echo "def lambda_handler(event, context):" >> main.py
        echo "    print('Remediation triggered')" >> main.py
        echo "    return {'statusCode': 200}" >> main.py
        zip -q function.zip main.py
    fi
else
    echo -e "${GREEN} Lambda function already packaged${NC}"
fi

# Return to terraform directory
cd "../../../environments"
echo

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init
echo -e "${GREEN} Terraform initialized${NC}"
echo

# Validate Terraform configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate
echo -e "${GREEN} Configuration is valid${NC}"
echo

# Format Terraform files
echo -e "${YELLOW}Formatting Terraform files...${NC}"
terraform fmt -recursive
echo -e "${GREEN} Files formatted${NC}"
echo

# Plan deployment
echo -e "${YELLOW}Planning infrastructure changes...${NC}"
terraform plan -out=tfplan
echo -e "${GREEN} Plan created${NC}"
echo

# Ask for confirmation
echo -e "${YELLOW}Review the plan above.${NC}"
read -p "Do you want to apply these changes? (yes/no): " confirm

if [ "$confirm" == "yes" ]; then
    echo -e "${YELLOW}Applying infrastructure changes...${NC}"
    terraform apply tfplan
    echo -e "${GREEN} Infrastructure deployed successfully!${NC}"
    echo

    # Display outputs
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    terraform output
    echo
    echo -e "${GREEN}Application URL:${NC} $(terraform output -raw application_url)"
    echo -e "${GREEN}Health Check:${NC} $(terraform output -raw health_check_url)"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Confirm your email subscription in the SNS topic"
    echo "2. Configure Ansible inventories with EC2 instance IPs"
    echo "3. Test the application by visiting the Application URL"
    echo "4. Monitor CloudWatch dashboard for metrics"
else
    echo -e "${YELLOW}Deployment cancelled${NC}"
    rm -f tfplan
fi
