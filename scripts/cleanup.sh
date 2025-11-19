#!/bin/bash
# ==================================
# Cleanup Infrastructure
# ==================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="../environments"

echo -e "${RED}========================================${NC}"
echo -e "${RED}Infrastructure Cleanup${NC}"
echo -e "${RED}========================================${NC}"
echo
echo -e "${RED}WARNING: This will destroy ALL infrastructure!${NC}"
echo -e "${RED}This action cannot be undone!${NC}"
echo
echo "This will destroy:"
echo "  - VPC and all networking components"
echo "  - EC2 instances and Auto Scaling Group"
echo "  - Application Load Balancer"
echo "  - CloudWatch alarms and dashboards"
echo "  - SNS topics and subscriptions"
echo "  - Lambda functions"
echo "  - All associated resources"
echo

read -p "Are you absolutely sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${GREEN}Cleanup cancelled${NC}"
    exit 0
fi

echo
read -p "Please type 'DESTROY' to confirm: " confirm2

if [ "$confirm2" != "DESTROY" ]; then
    echo -e "${GREEN}Cleanup cancelled${NC}"
    exit 0
fi

cd "$TERRAFORM_DIR"

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}Terraform not initialized. Initializing...${NC}"
    terraform init
fi

echo
echo -e "${YELLOW}Planning destruction...${NC}"
terraform plan -destroy -out=destroy.tfplan
echo

read -p "Review the plan above. Proceed with destruction? (yes/no): " final_confirm

if [ "$final_confirm" == "yes" ]; then
    echo -e "${RED}Destroying infrastructure...${NC}"
    terraform apply destroy.tfplan

    # Clean up plan file
    rm -f destroy.tfplan

    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Cleanup Complete${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo "All infrastructure has been destroyed."
    echo
    echo "To remove Terraform state files and other artifacts:"
    echo "  cd $TERRAFORM_DIR"
    echo "  rm -rf .terraform terraform.tfstate* tfplan"
else
    echo -e "${GREEN}Cleanup cancelled${NC}"
    rm -f destroy.tfplan
fi
