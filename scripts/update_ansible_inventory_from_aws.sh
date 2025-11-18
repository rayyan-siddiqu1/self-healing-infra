#!/bin/bash
# ==================================
# Update Ansible Inventory from AWS
# ==================================
# This script fetches EC2 instance IPs directly from AWS
# No Terraform output needed - works with existing infrastructure

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INVENTORY_DIR="$PROJECT_ROOT/ansible/inventories/prod"
INVENTORY_FILE="$INVENTORY_DIR/hosts.ini"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================${NC}"
echo -e "${GREEN}Updating Ansible Inventory from AWS${NC}"
echo -e "${GREEN}==================================${NC}"

# Check AWS credentials
echo -e "\n${YELLOW}→ Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
  echo -e "${RED}✗ AWS credentials not configured${NC}"
  echo -e "${YELLOW}  Run: aws configure${NC}"
  exit 1
fi
echo -e "${GREEN}✓ AWS credentials verified${NC}"

# Get instances by tags
echo -e "\n${YELLOW}→ Querying AWS for running instances...${NC}"
echo -e "${YELLOW}  Filters: Project=self-healing-infra, Environment=prod${NC}"

INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=self-healing-infra" \
            "Name=tag:Environment,Values=prod" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output text 2>&1)

if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Failed to query AWS${NC}"
  echo -e "${RED}$INSTANCES${NC}"
  exit 1
fi

if [ -z "$INSTANCES" ] || [ "$INSTANCES" == "None" ]; then
  echo -e "${RED}✗ No running instances found${NC}"
  echo -e "${YELLOW}Troubleshooting:${NC}"
  echo -e "1. Check if instances are running:"
  echo -e "   ${GREEN}aws ec2 describe-instances --filters \"Name=instance-state-name,Values=running\"${NC}"
  echo -e "2. Verify instances have correct tags:"
  echo -e "   ${GREEN}aws ec2 describe-instances --query 'Reservations[*].Instances[*].Tags'${NC}"
  echo -e "3. Check region (currently using default from aws configure)"
  exit 1
fi

echo -e "${GREEN}✓ Found instances${NC}"

# Try to get ASG name (optional - for reference only)
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?Tags[?Key=='Project' && Value=='self-healing-infra']].AutoScalingGroupName" \
  --output text 2>/dev/null | head -n1)

if [ -z "$ASG_NAME" ] || [ "$ASG_NAME" == "None" ]; then
  ASG_NAME="self-healing-infra-prod-asg"
  echo -e "${YELLOW}! Could not find ASG, using default name: $ASG_NAME${NC}"
else
  echo -e "${GREEN}✓ ASG Name: $ASG_NAME${NC}"
fi

# Create inventory directory
mkdir -p "$INVENTORY_DIR"

# Create inventory file
echo -e "\n${YELLOW}→ Creating inventory file...${NC}"

cat > "$INVENTORY_FILE" <<EOF
# ==================================
# Production Inventory
# ==================================
# Auto-generated on $(date)
# Source: AWS EC2 API
# DO NOT EDIT MANUALLY - Use scripts/update_ansible_inventory_from_aws.sh

[web_servers]
EOF

# Parse instance data and add to inventory
COUNTER=1
while IFS=$'\t' read -r INSTANCE_ID PRIVATE_IP PUBLIC_IP NAME; do
  if [ ! -z "$PRIVATE_IP" ] && [ "$PRIVATE_IP" != "None" ]; then
    HOST_NAME="${NAME:-web$(printf "%02d" $COUNTER)}"
    echo "$HOST_NAME ansible_host=$PRIVATE_IP instance_id=$INSTANCE_ID public_ip=${PUBLIC_IP:-N/A}" >> "$INVENTORY_FILE"
    echo -e "${GREEN}✓ Added: $HOST_NAME (Private: $PRIVATE_IP, Public: ${PUBLIC_IP:-N/A})${NC}"
    ((COUNTER++))
  fi
done <<< "$INSTANCES"

TOTAL_HOSTS=$((COUNTER - 1))

if [ $TOTAL_HOSTS -eq 0 ]; then
  echo -e "${RED}✗ No valid instances found${NC}"
  exit 1
fi

# Add common variables
cat >> "$INVENTORY_FILE" <<EOF

[all:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=$PROJECT_ROOT/environments/infra-key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
environment=prod
app_name=self-healing-app
asg_name=$ASG_NAME
region=us-east-1
EOF

echo -e "\n${GREEN}==================================${NC}"
echo -e "${GREEN}✓ Inventory updated successfully!${NC}"
echo -e "${GREEN}  Total hosts: $TOTAL_HOSTS${NC}"
echo -e "${GREEN}==================================${NC}"
echo -e "\nInventory file: ${YELLOW}$INVENTORY_FILE${NC}"

echo -e "\n${YELLOW}Test connectivity with:${NC}"
echo -e "${GREEN}cd $PROJECT_ROOT/ansible${NC}"
echo -e "${GREEN}ansible all -i inventories/prod/hosts.ini -m ping${NC}"

echo -e "\n${YELLOW}Or use dynamic inventory (recommended):${NC}"
echo -e "${GREEN}ansible all -i inventories/prod/aws_ec2.yml -m ping${NC}"
