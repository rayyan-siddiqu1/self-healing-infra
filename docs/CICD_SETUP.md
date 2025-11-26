# CI/CD Setup Guide

Complete guide for setting up the CI/CD pipeline for the self-healing infrastructure platform.

## Overview

The CI/CD pipeline consists of 5 main workflows:
1. **Terraform** - Infrastructure validation and deployment
2. **Lambda** - Serverless function testing and deployment
3. **Ansible** - Configuration management validation
4. **PR Validation** - Pull request quality checks
5. **Security** - Comprehensive security scanning

## Quick Start

### 1. Prerequisites

- GitHub repository with admin access
- AWS account with appropriate permissions
- GitHub Actions enabled

### 2. Configure AWS Credentials

Create an IAM user with the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "autoscaling:*",
        "elasticloadbalancing:*",
        "cloudwatch:*",
        "sns:*",
        "lambda:*",
        "iam:*",
        "s3:*",
        "dynamodb:*",
        "logs:*",
        "ssm:*",
        "ses:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. Add GitHub Secrets

Go to **Settings → Secrets and variables → Actions**:

```bash
# Required secrets
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=secret...

# Optional - for notify Lambda
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
TEAMS_WEBHOOK_URL=https://outlook.office.com/webhook/...
PAGERDUTY_API_KEY=u+...
PAGERDUTY_ROUTING_KEY=R123...
```

### 4. Create GitHub Environment

**Settings → Environments → New environment**:

- Name: `prod`
- **Protection rules:**
  - ✅ Required reviewers (1-2 people)
  - ✅ Wait timer: 0 minutes
  - ✅ Deployment branches: `master` only

### 5. Configure Branch Protection

**Settings → Branches → Add rule** for `master`:

- ✅ Require a pull request before merging
  - Required approvals: 1
- ✅ Require status checks to pass before merging
  - Required checks:
    - `terraform-validate`
    - `test (Lambda)`
    - `lint (Ansible)`
    - `code-quality`
- ✅ Require conversation resolution before merging
- ✅ Do not allow bypassing the above settings

## Detailed Configuration

### Terraform Backend

Ensure your Terraform backend is configured in `environments/*/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "self-healing-infra/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Create S3 bucket and DynamoDB table:**

```bash
# Create S3 bucket
aws s3 mb s3://your-terraform-state-bucket \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Lambda Deployment

The Lambda functions must exist before CI/CD can update them. Deploy initially with Terraform:

```bash
cd environments/prod
terraform init
terraform apply -target=module.lambda
```

This creates the Lambda functions that CI/CD will subsequently update.

### Notification Channels Setup

#### Slack

1. **Create Slack App:**
   - Go to https://api.slack.com/apps
   - Click "Create New App" → "From scratch"
   - Name: "Self-Healing Infrastructure"
   - Select workspace

2. **Enable Incoming Webhooks:**
   - Click "Incoming Webhooks"
   - Toggle "Activate Incoming Webhooks" to On
   - Click "Add New Webhook to Workspace"
   - Select channel (e.g., #alerts)
   - Copy webhook URL

3. **Add to GitHub Secrets:**
   ```
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXX
   ```

#### Discord

1. **Open Discord Server:**
   - Go to Server Settings → Integrations
   - Click "Webhooks" → "New Webhook"
   - Name: "Infrastructure Alerts"
   - Select channel

2. **Copy Webhook URL:**
   - Click "Copy Webhook URL"

3. **Add to GitHub Secrets:**
   ```
   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/123456789/abcdefg
   ```

#### Microsoft Teams

1. **Open Teams Channel:**
   - Click ... next to channel name
   - Select "Connectors"

2. **Configure Incoming Webhook:**
   - Search for "Incoming Webhook"
   - Click "Configure"
   - Name: "Infrastructure Alerts"
   - Upload an icon (optional)
   - Click "Create"

3. **Copy Webhook URL:**
   - Copy the generated URL

4. **Add to GitHub Secrets:**
   ```
   TEAMS_WEBHOOK_URL=https://outlook.office.com/webhook/...
   ```

#### PagerDuty

1. **Create Service:**
   - Go to Services → Service Directory
   - Click "New Service"
   - Name: "Self-Healing Infrastructure"
   - Integration type: "Events API v2"

2. **Get Integration Key:**
   - After creating, go to Integrations tab
   - Copy the "Integration Key" (this is your routing key)

3. **Create API Key:**
   - Go to User Icon → My Profile → User Settings
   - Click "Create API User Token"
   - Name: "GitHub Actions"
   - Copy the API key

4. **Add to GitHub Secrets:**
   ```
   PAGERDUTY_ROUTING_KEY=R03Qxxxxxxxxxxxxx
   PAGERDUTY_API_KEY=u+xxxxxxxxxxxxxx
   ```

#### AWS SES

1. **Verify Email:**
   ```bash
   aws ses verify-email-identity \
     --email-address alerts@yourdomain.com
   ```

2. **Check verification:**
   - Check your email for verification link
   - Click to verify

3. **Request Production Access** (if needed):
   - Go to SES Console → Account Dashboard
   - Click "Request Production Access"

4. **Add to GitHub Secrets:**
   ```
   DEFAULT_EMAIL=alerts@yourdomain.com
   ```

## Workflow Triggers

### Automatic Triggers

| Workflow | Push to master | Pull Request | Schedule | Manual |
|----------|---------------|--------------|----------|--------|
| Terraform | ✅ | ✅ | ❌ | ❌ |
| Lambda | ✅ | ✅ | ❌ | ❌ |
| Ansible | ✅ | ✅ | ❌ | ❌ |
| PR Validation | ❌ | ✅ | ❌ | ❌ |
| Security | ✅ | ✅ | ✅ Daily | ✅ |

### Manual Workflow Dispatch

Run workflows manually:

1. Go to **Actions** tab
2. Select workflow (e.g., "Security Scanning")
3. Click "Run workflow"
4. Select branch
5. Click "Run workflow"

## Development Workflow

### Making Changes

1. **Create Feature Branch:**
   ```bash
   git checkout -b feature/add-monitoring
   ```

2. **Make Changes:**
   ```bash
   # Edit files
   vim terraform/modules/cloudwatch/main.tf
   ```

3. **Test Locally:**
   ```bash
   # Terraform
   terraform fmt
   terraform validate

   # Lambda
   pytest lambda/tests/ -v

   # Ansible
   ansible-lint ansible/playbooks/
   ```

4. **Commit and Push:**
   ```bash
   git add .
   git commit -m "Add CloudWatch dashboard for metrics"
   git push origin feature/add-monitoring
   ```

5. **Create Pull Request:**
   - Go to GitHub
   - Click "Compare & pull request"
   - Fill in description
   - Submit PR

6. **Review CI/CD Results:**
   - Check all workflows pass
   - Review Terraform plan comment
   - Address any security findings

7. **Merge:**
   - Get approval
   - Merge PR
   - CI/CD automatically deploys to production

## Monitoring CI/CD

### GitHub Actions Dashboard

**Actions tab** shows:
- All workflow runs
- Success/failure status
- Duration
- Artifacts

### Notifications

Configure notifications:

**Settings → Notifications → Actions:**
- ✅ Send notifications for failed workflows
- ✅ Send notifications for deployments
- Choose: Email / GitHub UI / Mobile

### Artifacts

Download build artifacts:

1. Go to workflow run
2. Scroll to "Artifacts" section
3. Click to download:
   - Terraform plans
   - Lambda packages
   - Security reports

## Troubleshooting

### Common Issues

#### 1. AWS Credentials Invalid

**Error:** `The security token included in the request is invalid`

**Solution:**
```bash
# Rotate AWS credentials
aws iam create-access-key --user-name github-actions

# Update GitHub secrets with new credentials
```

#### 2. Terraform State Lock

**Error:** `Error locking state: ConditionalCheckFailedException`

**Solution:**
```bash
# List locks
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (CAUTION)
terraform force-unlock LOCK_ID
```

#### 3. Lambda Deployment Fails

**Error:** `ResourceNotFoundException: Function not found`

**Solution:**
```bash
# Deploy Lambda with Terraform first
cd environments/prod
terraform apply -target=module.lambda
```

#### 4. Tests Failing

**Error:** `ModuleNotFoundError: No module named 'boto3'`

**Solution:**
```bash
# Install dependencies locally
pip install -r lambda/functions/*/requirements.txt
pip install pytest pytest-cov pytest-mock moto

# Run tests
pytest lambda/tests/ -v
```

#### 5. Webhook Not Working

**Error:** Notifications not received

**Solution:**
- Check webhook URL is correct
- Verify webhook is active
- Test manually with curl
- Check CloudWatch logs

### Debug Mode

Enable debug logging:

**Settings → Secrets and variables → Actions:**

Add variable:
```
ACTIONS_STEP_DEBUG=true
ACTIONS_RUNNER_DEBUG=true
```

## Security Best Practices

### 1. Secrets Management

- ✅ Use GitHub Secrets for sensitive data
- ✅ Rotate credentials regularly
- ✅ Use environment-specific secrets
- ❌ Never commit secrets to code

### 2. Least Privilege

- ✅ Grant minimum IAM permissions
- ✅ Use separate IAM users per environment
- ✅ Enable MFA on AWS accounts

### 3. Code Review

- ✅ Require PR reviews
- ✅ Run automated security scans
- ✅ Check dependency vulnerabilities
- ✅ Review Terraform plans carefully

### 4. Monitoring

- ✅ Monitor workflow execution
- ✅ Set up alerts for failures
- ✅ Review security scan results
- ✅ Track deployment frequency

## Performance Optimization

### Caching

Workflows use caching for:
- Terraform providers
- Python pip packages
- npm packages (if added)

### Parallel Execution

Jobs run in parallel when possible:
```
Terraform Validate ─┐
Lambda Test ────────┼─→ All pass → Deploy
Ansible Lint ───────┘
```

### Conditional Jobs

Jobs skip when not needed:
```yaml
if: github.event_name == 'pull_request'
```

## Cost Management

### GitHub Actions Usage

Free tier:
- Public repos: Unlimited
- Private repos: 2,000 minutes/month

### Reduce Costs

1. **Use matrix sparingly** - Don't test all combinations
2. **Cache dependencies** - Reuse downloaded packages
3. **Skip redundant jobs** - Use path filters
4. **Optimize test suite** - Run critical tests first

## Next Steps

After setting up CI/CD:

1. **Test the Pipeline:**
   - Make a small change
   - Create PR
   - Verify all checks pass
   - Merge and verify deployment

2. **Set Up Monitoring:**
   - Configure Slack/Discord/Teams
   - Test notifications
   - Set up PagerDuty for critical alerts

3. **Document Processes:**
   - Runbooks for common issues
   - Deployment procedures
   - Rollback procedures

4. **Team Training:**
   - Review workflow with team
   - Practice creating PRs
   - Practice incident response

## Additional Resources

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Terraform CI/CD Best Practices](https://learn.hashicorp.com/tutorials/terraform/automate-terraform)
- [AWS Lambda CI/CD](https://docs.aws.amazon.com/lambda/latest/dg/lambda-cicd.html)
- [Ansible Testing](https://docs.ansible.com/ansible/latest/dev_guide/testing.html)
