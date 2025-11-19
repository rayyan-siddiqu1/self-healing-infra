# Quick Start Guide

This guide will help you deploy the self-healing infrastructure in minutes.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** >= 1.0 installed
4. **SSH Key Pair** created in AWS

## Step 1: Create SSH Key Pair (if needed)

```bash
aws ec2 create-key-pair \
  --key-name self-healing-infra-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/self-healing-infra-key.pem

chmod 400 ~/.ssh/self-healing-infra-key.pem
```

## Step 2: Configure Variables

```bash
cd environments
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `key_pair_name` - Your SSH key pair name
- `alert_emails` - Your email address for alerts
- Other variables as needed

## Step 3: Deploy Infrastructure

### Option A: Using the deployment script (Recommended)

```bash
cd scripts
chmod +x deploy_infra.sh
./deploy_infra.sh
```

### Option B: Manual deployment

```bash
cd environments

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan
```

## Step 4: Verify Deployment

After deployment completes, you'll see outputs including:

- **Application URL**: Access your application
- **Health Check URL**: Verify instance health
- **ALB DNS Name**: Load balancer endpoint
- **CloudWatch Dashboard**: Monitor metrics

## Step 5: Confirm Email Subscription

Check your email for an SNS subscription confirmation and click the link to confirm.

## Step 6: Test the System

### Test the application:
```bash
# Get the application URL from outputs
terraform output application_url

# Test health check
curl $(terraform output -raw health_check_url)
```

### View logs:
```bash
# View CloudWatch logs
aws logs tail /aws/ec2/self-healing-infra --follow

# View Lambda logs
aws logs tail /aws/lambda/self-healing-infra-prod-trigger-remediation --follow
```

### Trigger a test alarm:
```bash
# Stress test an instance (requires SSH access)
ssh -i ~/.ssh/self-healing-infra-key.pem ec2-user@<instance-ip>
stress --cpu 8 --timeout 300
```

Watch CloudWatch alarms trigger and observe auto-remediation!

## Architecture Overview

```
CloudWatch Alarms → SNS Topic → Lambda Function → Remediation Actions
                                                    ├─ Scale ASG
                                                    ├─ Clean Disk
                                                    ├─ Clear Memory Cache
                                                    └─ Restart Services
```

## Common Commands

```bash
# View all outputs
terraform output

# Show specific output
terraform output alb_dns_name

# Check infrastructure status
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names <asg-name>

# View CloudWatch dashboard
open "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:"

# Destroy everything
cd scripts
./cleanup.sh
```

## Troubleshooting

### Issue: Terraform initialization fails
```bash
# Clear Terraform cache
rm -rf .terraform
terraform init
```

### Issue: No instances launching
- Check key pair exists in AWS
- Verify subnet has available IP addresses
- Check CloudWatch logs for errors

### Issue: Health checks failing
- Verify security groups allow traffic from ALB
- Check instance user data logs: `tail -f /var/log/user-data.log`
- Verify httpd service is running

## Next Steps

1. ✅ Infrastructure deployed
2. Configure Ansible inventories for configuration management
3. Implement custom remediation playbooks
4. Set up CI/CD pipeline
5. Configure backup and disaster recovery

## Support

For issues or questions:
- Check the main [README.md](README.md)
- Review [CLAUDE.md](CLAUDE.md) for architecture details
- Check Terraform/AWS documentation
