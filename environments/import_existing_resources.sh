#!/bin/bash
# ==================================
# Import Existing AWS Resources
# ==================================
# Use this to import existing resources into Terraform state

set -e

cd "$(dirname "$0")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Importing existing resources into Terraform state...${NC}\n"

# Import CloudWatch Log Group
echo -e "${YELLOW}→ Importing CloudWatch Log Group...${NC}"
terraform import 'module.vpc.aws_cloudwatch_log_group.flow_logs' '/aws/vpc/self-healing-infra-prod' 2>&1 | grep -v "Import complete" || echo -e "${GREEN}✓ Log group imported${NC}"

echo -e "\n${GREEN}✓ Import complete!${NC}"
echo -e "\n${YELLOW}Now you can run:${NC}"
echo -e "  ${GREEN}terraform plan${NC}"
echo -e "  ${GREEN}terraform apply${NC}"
