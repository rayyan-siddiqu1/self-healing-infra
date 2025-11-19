# Self-Healing Infrastructure on AWS

A fully automated, self-healing infrastructure platform built on AWS using Terraform and Ansible.

## 🚀 Quick Start

### Prerequisites

- **WSL (Windows Subsystem for Linux)** - Already installed
- **AWS Account** with credentials configured
- **SSH Key** in `environments/infra-key.pem`

### Step 1: Set Up Ansible (One-Time)

```bash
cd /mnt/c/Users/rayyan/Desktop/Project/self-healing-infra
./setup.sh
```

This installs Ansible, discovers your EC2 instances, and creates inventory files.

### Step 2: Deploy Application

```bash
cd ansible
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/deploy_app.yml
```

### Step 3: Access Your Application

---

## 📁 Project Structure

```
├── setup.sh                 # Ansible setup (run this first)
├── deploy.sh               # Terraform infrastructure deployment
├── environments/           # Terraform configurations
│   ├── terraform.tfvars   # Your AWS settings
│   └── infra-key.pem      # SSH key for instances
├── ansible/
│   ├── inventories/prod/
│   │   └── hosts_ssm.ini  # Auto-generated instance inventory
│   └── playbooks/
│       ├── deploy_app.yml      # Deploy web application
│       ├── remediation.yml     # Self-healing tasks
│       └── hardening.yml       # Security hardening
└── terraform/modules/     # Infrastructure modules
```

---

## 🎯 Common Commands

### Ansible Operations

```bash
cd ansible

# Test connectivity
ansible all -i inventories/prod/hosts_ssm.ini -m ping

# Deploy application
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/deploy_app.yml

# Run remediation
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/remediation.yml

# Security hardening
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/hardening.yml

# Run ad-hoc commands
ansible all -i inventories/prod/hosts_ssm.ini -a "uptime"
ansible all -i inventories/prod/hosts_ssm.ini -a "df -h"
```

### Update Inventory (After Scaling)

When instances change (Auto Scaling):

```bash
cd /mnt/c/Users/rayyan/Desktop/Project/self-healing-infra
./setup.sh
```

This refreshes the inventory with current instances (takes ~15 seconds).

### Infrastructure Management

```bash
cd environments

# View outputs
terraform output

# Get application URL
terraform output application_url

# Deploy infrastructure changes
terraform plan
terraform apply
```

---

## 🏗️ Architecture

### Components

- **VPC** - Multi-AZ networking with public/private subnets
- **Auto Scaling Group** - 2-4 EC2 instances (t3.micro)
- **Application Load Balancer** - HTTP traffic distribution
- **CloudWatch** - Monitoring, alarms, and dashboards
- **Lambda** - Automated remediation triggers
- **SNS** - Alert notifications
- **Ansible** - Configuration management via AWS SSM

### Self-Healing Features

1. **Automatic Service Recovery** - Restarts failed services
2. **Disk Space Management** - Cleans up when disk is full
3. **Auto-Scaling** - Scales based on CPU/memory usage
4. **Health Monitoring** - CloudWatch alarms trigger remediation
5. **Automated Deployments** - Ansible playbooks for consistency

---

## 📋 How It Works

### Instance Discovery

The `setup.sh` script automatically:
1. Queries AWS for running instances (tagged: `Project=self-healing-infra`)
2. Creates Ansible inventory with unique hostnames
3. Configures AWS SSM for secure connections (no SSH keys needed)

### Connection Method

**AWS Systems Manager (SSM)** is used instead of SSH:
- ✅ Works with private instances (no public IPs needed)
- ✅ No bastion host required
- ✅ More secure (IAM-based authentication)
- ✅ Centralized session logging

### Inventory Files

**`inventories/prod/hosts_ssm.ini`** - Auto-generated inventory:
```ini
[web_servers]
web01 ansible_host=i-09761bd7580b0fbda
web02 ansible_host=i-0a4afa08d8aa6dbf9

[all:vars]
ansible_connection=aws_ssm
ansible_aws_ssm_region=us-east-1
```

Hostnames (`web01`, `web02`) are automatically generated and unique.

---

## 🔧 Configuration

### AWS Tags

Instances must have these tags:
- `Project: self-healing-infra`
- `Environment: prod`

The setup script uses these to discover instances.

### Terraform Variables

Edit `environments/terraform.tfvars`:
```hcl
aws_region         = "us-east-1"
environment        = "prod"
key_pair_name      = "infra-key"
alert_emails       = ["your-email@example.com"]
min_instance_count = 2
max_instance_count = 4
cpu_threshold      = 80
memory_threshold   = 85
```

---

## 📖 Available Playbooks

### 1. Deploy Application (`deploy_app.yml`)

Deploys the web application to all instances:
```bash
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/deploy_app.yml
```

**What it does:**
- Installs Apache web server
- Deploys application files
- Creates health check endpoint
- Starts and enables the service

### 2. Remediation (`remediation.yml`)

Self-healing tasks:
```bash
# Run all remediation tasks
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/remediation.yml

# Run specific task
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/remediation.yml --tags restart_service
```

**Available tags:**
- `restart_service` - Restart failed services
- `fix_disk_space` - Clean up disk space
- `scale_instance` - Trigger scaling
- `redeploy_app` - Redeploy application

### 3. Security Hardening (`hardening.yml`)

Apply security best practices:
```bash
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/hardening.yml
```

---

## 🚨 Troubleshooting

### Setup Script Issues

**Problem:** "No instances found"
```bash
# Check instances exist
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=self-healing-infra" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --output table
```

**Problem:** "AWS credentials not configured"
```bash
aws configure
# Or copy from Windows:
mkdir -p ~/.aws
cp /mnt/c/Users/rayyan/.aws/* ~/.aws/
```

### Ansible Connection Issues

**Problem:** "TargetNotConnected" error
- Wait 2-3 minutes for SSM agent to connect
- Check SSM status:
  ```bash
  aws ssm describe-instance-information
  ```

**Problem:** "UNREACHABLE" errors
- Instance might be terminated/replaced by Auto Scaling
- Re-run `./setup.sh` to refresh inventory

### Application Issues

**Problem:** 502 Bad Gateway
- Application not deployed yet → Run `deploy_app.yml`
- Check target health:
  ```bash
  aws elbv2 describe-target-health \
    --target-group-arn <YOUR_TG_ARN>
  ```

---

## 📚 Additional Documentation
- **[QUICKSTART.md](QUICKSTART.md)** - Infrastructure deployment guide
- **[WINDOWS_ANSIBLE_SETUP.md](WINDOWS_ANSIBLE_SETUP.md)** - WSL setup details
- **[ANSIBLE_GUIDE.md](ANSIBLE_GUIDE.md)** - Advanced Ansible usage

---

## 🎓 Workflow Example

### Initial Setup
```bash
# 1. Set up Ansible
./setup.sh

# 2. Deploy application
cd ansible
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/deploy_app.yml

# 3. Visit application
# http://self-healing-infra-prod-alb-863526104.us-east-1.elb.amazonaws.com
```

### After Auto Scaling Event
```bash
# 1. Refresh inventory (instances changed)
./setup.sh

# 2. Deploy to new instances
cd ansible
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/deploy_app.yml
```

### Regular Operations
```bash
cd ansible

# Check system status
ansible all -i inventories/prod/hosts_ssm.ini -a "uptime"
ansible all -i inventories/prod/hosts_ssm.ini -a "systemctl status httpd"

# Run remediation if needed
ansible-playbook -i inventories/prod/hosts_ssm.ini playbooks/remediation.yml
```

---

## ✨ Key Features

- **Automated Discovery** - Finds instances automatically, no manual configuration
- **SSM-Based** - Secure connections without SSH keys or bastions
- **Self-Healing** - CloudWatch triggers Lambda for automatic remediation
- **Auto-Scaling** - Adjusts capacity based on metrics
- **Multi-AZ** - High availability across availability zones
- **Infrastructure as Code** - Everything defined in Terraform
- **Configuration as Code** - All managed with Ansible

---

## 🆘 Support

For issues:
1. Check AWS credentials: `aws sts get-caller-identity`
2. Verify instances running: `aws ec2 describe-instances`
3. Check SSM connectivity: `aws ssm describe-instance-information`
4. Re-run setup: `./setup.sh`

---

## 📝 Summary

**Two Scripts, Simple Workflow:**

1. **`./setup.sh`** - Sets up Ansible and discovers instances (run once, or when instances change)
2. **`deploy_app.yml`** - Deploys your application to all instances

That's it! Everything else is automated. 🚀
