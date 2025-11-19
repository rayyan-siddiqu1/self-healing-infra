#!/bin/bash
# ==================================
# Simple Ansible Setup - No SSM Check
# ==================================
# Simplified version that skips SSM validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Simple Ansible Setup${NC}\n"

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_TAG="self-healing-infra"
ENVIRONMENT="prod"

echo -e "${YELLOW}Step 1: Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
  echo -e "${YELLOW}AWS credentials not configured. Run: aws configure${NC}"
  exit 1
fi
echo -e "${GREEN}✓ AWS credentials OK${NC}"

echo -e "\n${YELLOW}Step 2: Discovering instances...${NC}"
INSTANCES=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT_TAG" \
            "Name=tag:Environment,Values=$ENVIRONMENT" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output text)

if [ -z "$INSTANCES" ]; then
  echo -e "${YELLOW}No instances found${NC}"
  exit 1
fi

COUNTER=0
declare -a IDS
declare -a IPS
declare -a NAMES

while IFS=$'\t' read -r ID IP NAME; do
  if [ ! -z "$ID" ]; then
    IDS+=("$ID")
    IPS+=("$IP")
    NAMES+=("$NAME")
    echo -e "${GREEN}✓ $NAME ($ID) - $IP${NC}"
    COUNTER=$((COUNTER + 1))
  fi
done <<< "$INSTANCES"

echo -e "${GREEN}✓ Found $COUNTER instances${NC}"

echo -e "\n${YELLOW}Step 3: Getting ASG info...${NC}"
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
  --region "$AWS_REGION" \
  --query "AutoScalingGroups[?Tags[?Key=='Project' && Value=='$PROJECT_TAG']].AutoScalingGroupName" \
  --output text 2>/dev/null | head -n1)
ASG_NAME=${ASG_NAME:-"$PROJECT_TAG-$ENVIRONMENT-asg"}
echo -e "${GREEN}✓ ASG: $ASG_NAME${NC}"

echo -e "\n${YELLOW}Step 4: Creating inventory files...${NC}"

INVENTORY_DIR="ansible/inventories/$ENVIRONMENT"
mkdir -p "$INVENTORY_DIR"

# Create SSM inventory
cat > "$INVENTORY_DIR/hosts_ssm.ini" <<EOF
# Auto-generated $(date)
[web_servers]
EOF

for i in "${!IDS[@]}"; do
  # Use instance ID suffix to make unique names
  HOST_NUM=$((i + 1))
  INSTANCE_NAME="web$(printf "%02d" $HOST_NUM)"
  echo "$INSTANCE_NAME ansible_host=${IDS[$i]} # ${NAMES[$i]}" >> "$INVENTORY_DIR/hosts_ssm.ini"
done

cat >> "$INVENTORY_DIR/hosts_ssm.ini" <<EOF

[all:vars]
ansible_connection=aws_ssm
ansible_aws_ssm_bucket_name=$PROJECT_TAG-terraform-state
ansible_aws_ssm_region=$AWS_REGION
env=$ENVIRONMENT
app_name=self-healing-app
asg_name=$ASG_NAME
EOF

echo -e "${GREEN}✓ Created: $INVENTORY_DIR/hosts_ssm.ini${NC}"

# Create traditional inventory
cat > "$INVENTORY_DIR/hosts.ini" <<EOF
# Auto-generated $(date)
[web_servers]
EOF

for i in "${!IDS[@]}"; do
  # Use instance ID suffix to make unique names
  HOST_NUM=$((i + 1))
  INSTANCE_NAME="web$(printf "%02d" $HOST_NUM)"
  echo "$INSTANCE_NAME ansible_host=${IPS[$i]} instance_id=${IDS[$i]} # ${NAMES[$i]}" >> "$INVENTORY_DIR/hosts.ini"
done

cat >> "$INVENTORY_DIR/hosts.ini" <<EOF

[all:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=$SCRIPT_DIR/environments/infra-key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
env=$ENVIRONMENT
app_name=self-healing-app
asg_name=$ASG_NAME
EOF

echo -e "${GREEN}✓ Created: $INVENTORY_DIR/hosts.ini${NC}"

# Set SSH key permissions
if [ -f "environments/infra-key.pem" ]; then
  chmod 400 environments/infra-key.pem
fi

echo -e "\n${CYAN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

echo -e "\n${YELLOW}Test connectivity:${NC}"
echo -e "  ${GREEN}cd ansible${NC}"
echo -e "  ${GREEN}ansible all -i inventories/$ENVIRONMENT/hosts_ssm.ini -m ping${NC}"

echo -e "\n${YELLOW}Run playbooks:${NC}"
echo -e "  ${GREEN}ansible-playbook -i inventories/$ENVIRONMENT/hosts_ssm.ini playbooks/remediation.yml${NC}\n"
