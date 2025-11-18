# Running Ansible on Windows

Ansible doesn't run natively on Windows, but you have several excellent options to run it.

## Option 1: WSL2 (Windows Subsystem for Linux) - ⭐ RECOMMENDED

**Best for:** Development, testing, and production use. Most native Linux experience on Windows.

### Setup Steps:

#### 1. Install WSL2
```powershell
# Run in PowerShell as Administrator
wsl --install
# This installs Ubuntu by default
# Restart your computer when prompted
```

#### 2. Set up Ubuntu in WSL2
```bash
# After restart, Ubuntu will open automatically
# Create a username and password when prompted

# Update packages
sudo apt update && sudo apt upgrade -y

# Install Ansible
sudo apt install software-properties-common -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible -y

# Verify installation
ansible --version
```

#### 3. Access your project files
```bash
# Your Windows C: drive is mounted at /mnt/c/
cd /mnt/c/Users/rayyan/Desktop/Project/self-healing-infra/ansible

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml
```

#### 4. Configure SSH keys in WSL
```bash
# Copy your SSH key to WSL (if you have one)
cp /mnt/c/Users/rayyan/.ssh/self-healing-infra-key.pem ~/.ssh/
chmod 400 ~/.ssh/self-healing-infra-key.pem

# Or create a new key in WSL
ssh-keygen -t rsa -b 4096 -f ~/.ssh/self-healing-infra-key
```

#### 5. Configure AWS credentials in WSL
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
# Enter your AWS Access Key ID, Secret, and region
```

#### 6. Run Ansible
```bash
cd /mnt/c/Users/rayyan/Desktop/Project/self-healing-infra/ansible

# Test connectivity
ansible all -i inventories/prod/hosts -m ping

# Run playbooks
ansible-playbook -i inventories/prod/hosts playbooks/deploy_app.yml
```

### Advantages:
✅ Native Linux environment
✅ Full Ansible support
✅ Access to Windows files via /mnt/c/
✅ Can use VS Code with WSL extension
✅ Best performance
✅ Free and built into Windows

### VS Code Integration:
1. Install "Remote - WSL" extension in VS Code
2. Click the green icon in bottom-left corner
3. Select "Connect to WSL"
4. Open your project folder in WSL

---

## Option 2: Docker Container

**Best for:** Isolated environments, CI/CD pipelines.

### Setup Steps:

#### 1. Install Docker Desktop for Windows
Download from: https://www.docker.com/products/docker-desktop/

#### 2. Create Ansible Dockerfile
Create `ansible/Dockerfile`:
```dockerfile
FROM python:3.11-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    ansible \
    openssh-client \
    sshpass \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Ansible collections
WORKDIR /ansible
COPY requirements.yml .
RUN ansible-galaxy collection install -r requirements.yml

# Set working directory
WORKDIR /ansible

CMD ["/bin/bash"]
```

#### 3. Build and run Docker container
```powershell
# Build the image
docker build -t ansible-runner ./ansible

# Run Ansible in container (from project root)
docker run -it --rm `
  -v ${PWD}/ansible:/ansible `
  -v ${HOME}/.ssh:/root/.ssh:ro `
  -v ${HOME}/.aws:/root/.aws:ro `
  ansible-runner `
  ansible-playbook -i inventories/prod/hosts playbooks/deploy_app.yml
```

#### 4. Create helper script (optional)
Create `run-ansible.ps1`:
```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$Playbook,

    [string]$Inventory = "inventories/prod/hosts",

    [string]$ExtraArgs = ""
)

docker run -it --rm `
  -v ${PWD}/ansible:/ansible `
  -v ${HOME}/.ssh:/root/.ssh:ro `
  -v ${HOME}/.aws:/root/.aws:ro `
  ansible-runner `
  ansible-playbook -i $Inventory $Playbook $ExtraArgs
```

Usage:
```powershell
.\run-ansible.ps1 -Playbook playbooks/deploy_app.yml
```

### Advantages:
✅ Isolated environment
✅ Reproducible
✅ No system changes
✅ Works on any platform
✅ Good for CI/CD

---

## Option 3: AWS Systems Manager (SSM) - Cloud-Native

**Best for:** Serverless approach, no local Ansible needed.

### Setup:

The Lambda function already has SSM capabilities built-in! You can trigger remediation directly via SSM Run Command.

#### 1. Update Lambda to use SSM
The Lambda function (`lambda/functions/trigger_remediation/main.py`) already uses SSM:
```python
ssm_client.send_command(
    InstanceIds=[instance_id],
    DocumentName='AWS-RunShellScript',
    Parameters={
        'commands': [
            'echo "Running remediation..."',
            # Commands here
        ]
    }
)
```

#### 2. Create SSM Documents for remediation
Instead of Ansible, use SSM Documents (already supported by infrastructure).

### Advantages:
✅ No local setup needed
✅ Fully managed by AWS
✅ Built into your Lambda
✅ Works from anywhere
✅ Centralized logging in CloudWatch

---

## Option 4: Remote Linux Control Node

**Best for:** Production environments, team collaboration.

### Setup:

#### 1. Launch a small EC2 instance (t3.micro)
```bash
# In AWS Console or via Terraform
# Amazon Linux 2023, t3.micro, in your VPC
```

#### 2. Install Ansible on the instance
```bash
ssh ec2-user@<control-node-ip>
sudo dnf install ansible -y
```

#### 3. Clone your repo
```bash
git clone https://github.com/your-repo/self-healing-infra.git
cd self-healing-infra/ansible
```

#### 4. Run from the control node
```bash
ansible-playbook -i inventories/prod/hosts playbooks/deploy_app.yml
```

#### 5. Connect from Windows
Use VS Code Remote SSH or MobaXterm to work on the remote node.

### Advantages:
✅ Always available
✅ Closer to target instances (lower latency)
✅ Can run scheduled jobs
✅ Team can share access
✅ Production-ready

---

## Option 5: Git Bash + Python (Limited)

**Best for:** Quick testing only (NOT recommended for production).

### Setup:
```bash
# Install Python for Windows
# Install Ansible via pip (limited support)
pip install ansible

# May have compatibility issues
```

⚠️ **Not recommended** - Many features won't work properly on Windows.

---

## 🎯 Recommended Approach

**For your use case, I recommend:**

### Development & Testing: **WSL2** ⭐
- Full Linux environment
- Access to Windows files
- VS Code integration
- Best developer experience

### Production/CI-CD: **Docker** or **Remote Control Node**
- Reproducible
- Can run in CI/CD pipelines
- Team collaboration

### Serverless/Simple: **AWS SSM via Lambda**
- No Ansible needed
- Already built into your Lambda
- Fully managed

---

## Quick Start with WSL2 (5 minutes)

```powershell
# 1. Install WSL2 (PowerShell as Admin)
wsl --install
# Restart computer

# 2. After restart, in Ubuntu terminal:
sudo apt update && sudo apt install ansible -y

# 3. Navigate to project
cd /mnt/c/Users/rayyan/Desktop/Project/self-healing-infra/ansible

# 4. Install collections
ansible-galaxy collection install -r requirements.yml

# 5. Test (after infrastructure is deployed)
ansible all -i inventories/prod/hosts -m ping
```

---

## Need Help?

- WSL2 issues: `wsl --help` or check Windows features
- Docker issues: Ensure Docker Desktop is running
- SSH issues: Check key permissions and paths
- AWS issues: Verify credentials with `aws sts get-caller-identity`

---

**My recommendation:** Start with **WSL2** - it's the most straightforward and gives you the full Linux experience while still being able to use Windows tools like VS Code.
