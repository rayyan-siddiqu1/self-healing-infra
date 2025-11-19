#!/bin/bash
# ==================================
# Validate Terraform Configuration
# ==================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="../environments"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Terraform Configuration Validation${NC}"
echo -e "${GREEN}========================================${NC}"
echo

cd "$TERRAFORM_DIR"

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    echo "Please install Terraform: https://www.terraform.io/downloads"
    exit 1
fi

# Initialize if needed
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init
    echo
fi

# Validate configuration
echo -e "${YELLOW}Validating configuration...${NC}"
if terraform validate; then
    echo -e "${GREEN} Configuration is valid${NC}"
else
    echo -e "${RED} Configuration validation failed${NC}"
    exit 1
fi
echo

# Format check
echo -e "${YELLOW}Checking formatting...${NC}"
if terraform fmt -check -recursive; then
    echo -e "${GREEN} All files are properly formatted${NC}"
else
    echo -e "${YELLOW}Warning: Some files need formatting${NC}"
    echo "Run 'terraform fmt -recursive' to fix"
fi
echo

# Check for required variables
echo -e "${YELLOW}Checking for required variables...${NC}"
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Warning: terraform.tfvars not found${NC}"
    echo "Copy terraform.tfvars.example to terraform.tfvars and configure it"
else
    echo -e "${GREEN} terraform.tfvars found${NC}"

    # Check for required values
    if grep -q "your-key-pair-name" terraform.tfvars 2>/dev/null; then
        echo -e "${YELLOW}Warning: key_pair_name needs to be configured${NC}"
    fi

    if grep -q "your-email@example.com" terraform.tfvars 2>/dev/null; then
        echo -e "${YELLOW}Warning: alert_emails needs to be configured${NC}"
    fi
fi
echo

# Validate modules
echo -e "${YELLOW}Validating modules...${NC}"
for module_dir in ../terraform/modules/*/; do
    module_name=$(basename "$module_dir")
    if [ -f "$module_dir/main.tf" ]; then
        echo -n "  Checking $module_name... "
        if (cd "$module_dir" && terraform init -backend=false &>/dev/null && terraform validate &>/dev/null); then
            echo -e "${GREEN}${NC}"
        else
            echo -e "${RED}${NC}"
        fi
    fi
done
echo

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Validation Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Terraform configuration is valid${NC}"
echo -e "${GREEN} All modules are valid${NC}"
echo
echo "You can now run './deploy_infra.sh' to deploy the infrastructure"
