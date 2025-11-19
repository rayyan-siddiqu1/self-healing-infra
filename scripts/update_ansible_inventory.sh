#!/bin/bash
# ==================================
# Update Ansible Inventory Script
# ==================================
# This script fetches EC2 instance IPs from the deployed infrastructure
# and updates the Ansible inventory file

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/environments"
INVENTORY_DIR="$PROJECT_ROOT/ansible/inventories/prod"
INVENTORY_FILE="$INVENTORY_DIR/hosts.ini"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================${NC}"
echo -e "${GREEN}Updating Ansible Inventory${NC}"
echo -e "${GREEN}==================================${NC}"

# Change to Terraform directory
cd "$TERRAFORM_DIR"

# Get ASG name from Terraform output
echo -e "\n${YELLOW}→ Getting Auto Scaling Group name...${NC}"
ASG_NAME=$(terraform output -raw asg_name 2>/dev/null || echo "")

if [ -z "$ASG_NAME" ]; then
  echo -e "${RED}✗ Could not get ASG name from Terraform output${NC}"
  echo -e "${RED}  Make sure infrastructure is deployed: terraform apply${NC}"
  exit 1
fi

echo -e "${GREEN}✓ ASG Name: $ASG_NAME${NC}"

# Get instance IDs from ASG
echo -e "\n${YELLOW}→ Fetching instance IDs from ASG...${NC}"
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`].InstanceId' \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo -e "${RED}✗ No healthy instances found in ASG${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Found instances: $INSTANCE_IDS${NC}"

# Get instance details (private IPs and tags)
echo -e "\n${YELLOW}→ Fetching instance details...${NC}"
INSTANCE_DATA=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_IDS \
  --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output text)

if [ -z "$INSTANCE_DATA" ]; then
  echo -e "${RED}✗ Could not fetch instance details${NC}"
  exit 1
fi

# Create inventory file
echo -e "\n${YELLOW}→ Creating inventory file...${NC}"

cat > "$INVENTORY_FILE" <<EOF
# ==================================
# Production Inventory
# ==================================
# Auto-generated on $(date)
# DO NOT EDIT MANUALLY - Use scripts/update_ansible_inventory.sh

[web_servers]
EOF

# Parse instance data and add to inventory
COUNTER=1
while IFS=$'\t' read -r INSTANCE_ID PRIVATE_IP PUBLIC_IP NAME; do
  if [ ! -z "$PRIVATE_IP" ]; then
    HOST_NAME="${NAME:-web$(printf "%02d" $COUNTER)}"
    echo "$HOST_NAME ansible_host=$PRIVATE_IP instance_id=$INSTANCE_ID" >> "$INVENTORY_FILE"
    echo -e "${GREEN}✓ Added: $HOST_NAME ($PRIVATE_IP)${NC}"
    ((COUNTER++))
  fi
done <<< "$INSTANCE_DATA"

# Add common variables
cat >> "$INVENTORY_FILE" <<EOF

[all:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=$PROJECT_ROOT/environments/infra-key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
environment=prod
app_name=self-healing-app
asg_name=$ASG_NAME
region=us-east-1
EOF

echo -e "\n${GREEN}==================================${NC}"
echo -e "${GREEN}✓ Inventory updated successfully!${NC}"
echo -e "${GREEN}==================================${NC}"
echo -e "\nInventory file: ${YELLOW}$INVENTORY_FILE${NC}"
echo -e "\nTest connectivity with:"
echo -e "${YELLOW}cd $PROJECT_ROOT/ansible${NC}"
echo -e "${YELLOW}ansible all -i inventories/prod/hosts.ini -m ping${NC}"
