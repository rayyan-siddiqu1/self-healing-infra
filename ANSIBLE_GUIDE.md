# Ansible Playbooks & Remediation Guide

## Overview

Comprehensive Ansible automation for self-healing infrastructure management, including automated remediation, application deployment, and security hardening.

## Structure

```
ansible/
├── ansible.cfg                    # Ansible configuration
├── requirements.yml               # Required Ansible collections
├── playbooks/                    # Main playbooks
│   ├── remediation.yml           # Self-healing remediation
│   ├── deploy_app.yml            # Application deployment
│   └── hardening.yml             # Security hardening
├── remediation/                  # Remediation tasks & handlers
│   ├── tasks/
│   │   ├── restart_service.yml   # Service recovery
│   │   ├── fix_disk_space.yml    # Disk cleanup
│   │   ├── fix_memory.yml        # Memory optimization
│   │   ├── redeploy_app.yml      # App redeployment
│   │   ├── scale_instance.yml    # ASG scaling
│   │   └── health_check.yml      # System health check
│   └── handlers/
│       └── main.yml              # Remediation handlers
├── roles/
│   └── app_deploy/               # Application deployment role
│       ├── tasks/main.yml
│       └── handlers/main.yml
└── inventories/
    ├── prod/hosts.example        # Production inventory
    └── dev/hosts.example         # Development inventory
```

## Installation

### 1. Install Ansible

```bash
# Amazon Linux 2023 / RHEL
sudo dnf install ansible -y

# Ubuntu
sudo apt update && sudo apt install ansible -y

# macOS
brew install ansible
```

### 2. Install Required Collections

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

### 3. Configure AWS Credentials

```bash
aws configure
# Or set environment variables:
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

### 4. Set Up Inventory

```bash
cd inventories/prod
cp hosts.example hosts
# Edit hosts file with your EC2 instance IPs
nano hosts
```

## Playbooks

### 1. Remediation Playbook (`remediation.yml`)

**Purpose:** Automated self-healing actions triggered by CloudWatch alarms via Lambda.

**Usage:**
```bash
# Run all remediation tasks
ansible-playbook -i inventories/prod/hosts playbooks/remediation.yml

# Run specific remediation type
ansible-playbook -i inventories/prod/hosts playbooks/remediation.yml \
  -e "remediation_type=restart_service"

# Available remediation types:
# - health_check
# - restart_service / unhealthy_target
# - disk_full / high_disk
# - high_memory / memory_leak
# - redeploy_app / app_failure
# - scale_up / high_cpu
```

**Remediation Types:**

| Type | Trigger | Actions |
|------|---------|---------|
| `restart_service` | Service failure, unhealthy targets | Stop service, clear PIDs, restart, verify health |
| `fix_disk_space` | High disk usage (>85%) | Clean logs, temp files, caches, rotate logs |
| `fix_memory` | High memory usage (>85%) | Clear caches, restart services, adjust swappiness |
| `redeploy_app` | Application failure | Backup, clean, redeploy, verify |
| `scale_instance` | High CPU, need capacity | Scale up ASG, wait for healthy instances |
| `health_check` | Regular checks | Comprehensive system health assessment |

### 2. Deploy App Playbook (`deploy_app.yml`)

**Purpose:** Deploy web application to EC2 instances.

**Usage:**
```bash
# Deploy to all hosts
ansible-playbook -i inventories/prod/hosts playbooks/deploy_app.yml

# Deploy to specific hosts
ansible-playbook -i inventories/prod/hosts playbooks/deploy_app.yml --limit web01

# Check deployment status
ansible-playbook -i inventories/prod/hosts playbooks/deploy_app.yml --check
```

**What It Deploys:**
- Apache HTTP Server
- Static web application
- Health check endpoint
- CSS/JS assets
- Log rotation configuration
- Systemd service configuration

### 3. Hardening Playbook (`hardening.yml`)

**Purpose:** Apply security best practices to EC2 instances.

**Usage:**
```bash
# Apply full hardening
ansible-playbook -i inventories/prod/hosts playbooks/hardening.yml

# Dry run (check mode)
ansible-playbook -i inventories/prod/hosts playbooks/hardening.yml --check
```

**Security Measures:**
- System package updates
- Fail2ban installation & configuration
- SSH hardening (disable root, password auth)
- File permission hardening
- Firewall configuration
- Audit daemon (auditd) setup
- Kernel security parameters
- Service hardening

## Remediation Tasks Detail

### restart_service.yml

**Handles:** Service failures, unhealthy ALB targets

**Process:**
1. Check current service status
2. Stop service gracefully
3. Remove stale PID files
4. Check for port conflicts
5. Validate configuration
6. Fix common issues (permissions, directories)
7. Restart service with fresh state
8. Verify HTTP health check
9. Report results

### fix_disk_space.yml

**Handles:** High disk usage (>85%)

**Cleanup Actions:**
- Old log files (>7 days)
- Journal logs (keep 7 days)
- Temporary files
- Package manager cache
- Core dumps
- Large Apache logs (>100MB)
- Application caches
- Old backups (>30 days)

**Result:** Reports space freed and final disk usage

### fix_memory.yml

**Handles:** High memory usage (>85%)

**Optimization Actions:**
- Clear page cache (safe)
- Identify memory hogs
- Restart services using excessive memory
- Clear systemd journal
- Kill zombie processes
- Adjust swappiness

### redeploy_app.yml

**Handles:** Application failures

**Process:**
1. Backup current application
2. Clean application directory
3. Deploy fresh application files
4. Set correct permissions
5. Create health check endpoint
6. Restart service
7. Verify application responds

### scale_instance.yml

**Handles:** High CPU, capacity needs

**Process:**
1. Get current ASG configuration
2. Check if scaling possible
3. Calculate new capacity
4. Update ASG desired capacity
5. Wait for new instances
6. Verify instance health

### health_check.yml

**Handles:** Comprehensive health assessment

**Checks:**
- System uptime & load
- Memory usage
- Disk usage
- Service status (httpd, sshd)
- Network connectivity
- Failed systemd units
- Disk I/O wait

## Inventory Management

### Static Inventory

Edit `inventories/prod/hosts`:
```ini
[web_servers]
web01 ansible_host=10.0.11.10 ansible_user=ec2-user
web02 ansible_host=10.0.11.20 ansible_user=ec2-user

[all:vars]
ansible_ssh_private_key_file=~/.ssh/self-healing-infra-key.pem
environment=prod
asg_name=self-healing-infra-prod-asg
```

### Dynamic Inventory (AWS EC2)

Create `inventories/prod/aws_ec2.yml`:
```yaml
plugin: aws_ec2
regions:
  - us-east-1
filters:
  tag:Environment: prod
  tag:Project: self-healing-infra
  instance-state-name: running
keyed_groups:
  - key: tags.Role
    prefix: role
hostnames:
  - private-ip-address
```

Use with:
```bash
ansible-playbook -i inventories/prod/aws_ec2.yml playbooks/remediation.yml
```

## Integration with Lambda

### Lambda → Ansible Flow

1. **CloudWatch Alarm** triggers (high CPU, disk, memory)
2. **SNS** sends notification to Lambda
3. **Lambda** function processes alarm:
   ```python
   # Lambda identifies issue type
   alarm_name = "cpu-utilization-high"
   remediation_type = "high_cpu"
   ```
4. **Lambda** triggers Ansible via:
   - SSM Run Command
   - CodeBuild
   - Jenkins
   - Direct SSH (if configured)
5. **Ansible** runs remediation playbook:
   ```bash
   ansible-playbook playbooks/remediation.yml \
     -e "remediation_type=high_cpu"
   ```

### Manual Triggering

Test remediation locally:
```bash
# Simulate Lambda trigger
./scripts/trigger_remidiation_local.sh

# Or run Ansible directly
ansible-playbook -i inventories/prod/hosts playbooks/remediation.yml \
  -e "remediation_type=restart_service"
```

## Testing

### Syntax Check

```bash
# Check playbook syntax
ansible-playbook playbooks/remediation.yml --syntax-check
ansible-playbook playbooks/deploy_app.yml --syntax-check
ansible-playbook playbooks/hardening.yml --syntax-check
```

### Dry Run

```bash
# Check what would change
ansible-playbook -i inventories/prod/hosts playbooks/remediation.yml --check --diff
```

### Single Task Testing

```bash
# Test specific task
ansible-playbook playbooks/remediation.yml --tags health_check
ansible-playbook playbooks/remediation.yml --tags disk_space
ansible-playbook playbooks/remediation.yml --tags restart_service
```

### Verbose Output

```bash
# Debug mode
ansible-playbook -i inventories/prod/hosts playbooks/remediation.yml -vvv
```

## Troubleshooting

### Common Issues

**1. Connection Timeout**
```bash
# Check SSH connectivity
ansible all -i inventories/prod/hosts -m ping

# Use bastion host
ansible all -i inventories/prod/hosts -m ping \
  --ssh-common-args='-o ProxyCommand="ssh -W %h:%p ec2-user@bastion-ip"'
```

**2. Permission Denied**
```bash
# Check SSH key permissions
chmod 400 ~/.ssh/self-healing-infra-key.pem

# Verify key in ansible.cfg
grep private_key_file ansible/ansible.cfg
```

**3. Module Not Found**
```bash
# Install required collections
ansible-galaxy collection install -r requirements.yml --force
```

**4. Task Failures**
```bash
# Run with step mode
ansible-playbook -i inventories/prod/hosts playbooks/remediation.yml --step

# Skip failed hosts
ansible-playbook -i inventories/prod/hosts playbooks/remediation.yml --limit @retry_hosts.txt
```

## Best Practices

1. **Always test in dev first**
   ```bash
   ansible-playbook -i inventories/dev/hosts playbooks/hardening.yml
   ```

2. **Use check mode for safety**
   ```bash
   ansible-playbook playbooks/remediation.yml --check --diff
   ```

3. **Tag your plays**
   ```bash
   ansible-playbook playbooks/remediation.yml --tags "restart_service,disk_space"
   ```

4. **Monitor Ansible logs**
   ```bash
   tail -f ansible/ansible.log
   ```

5. **Use vaults for secrets**
   ```bash
   ansible-vault create group_vars/all/vault.yml
   ansible-playbook playbooks/deploy_app.yml --ask-vault-pass
   ```

## Next Steps

1. **Deploy infrastructure** with Terraform
2. **Get EC2 instance IPs** from AWS Console or terraform output
3. **Update inventory** files with actual IPs
4. **Test connectivity** with `ansible all -m ping`
5. **Deploy application** with deploy_app.yml
6. **Apply hardening** with hardening.yml
7. **Test remediation** by triggering alarms

## Support

For issues or questions:
- Check Ansible logs: `ansible/ansible.log`
- Review CloudWatch logs for Lambda triggers
- Test individual tasks with `--tags`
- Use verbose mode `-vvv` for debugging

---
*Ansible playbooks created for self-healing infrastructure automation*
