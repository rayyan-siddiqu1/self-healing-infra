# CI/CD Workflows

This directory contains GitHub Actions workflows for automated testing, building, and deployment of the self-healing infrastructure platform.

## Workflows Overview

### 1. Terraform CI/CD (`terraform.yml`)

**Triggers:**
- Push to `master`/`main` (paths: `terraform/**`, `environments/**`)
- Pull requests to `master`/`main`

**Jobs:**
- **terraform-validate**: Format check, initialization, and validation
- **terraform-plan**: Generate and comment plan on PRs
- **terraform-apply**: Apply changes on merge to master
- **security-scan**: Run tfsec and Checkov security scanning

**Required Secrets:**
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key

### 2. Lambda CI/CD (`lambda.yml`)

**Triggers:**
- Push to `master`/`main` (paths: `lambda/**`)
- Pull requests to `master`/`main`

**Jobs:**
- **test**: Run unit tests with pytest and coverage
- **build**: Package Lambda functions with dependencies
- **deploy**: Deploy to AWS Lambda (on merge to master)
- **security-scan**: Run Bandit security scanning

**Features:**
- Automatic Lambda function packaging
- Version publishing and alias management
- Smoke tests after deployment
- Code coverage reporting

### 3. Ansible CI/CD (`ansible.yml`)

**Triggers:**
- Push to `master`/`main` (paths: `ansible/**`)
- Pull requests to `master`/`main`

**Jobs:**
- **lint**: YAML linting and ansible-lint
- **validate**: Syntax checking and configuration validation
- **security-scan**: Security-focused linting
- **test-dry-run**: Dry-run playbooks (on PRs)

### 4. PR Validation (`pr-validation.yml`)

**Triggers:**
- Pull requests to `master`/`main`

**Jobs:**
- **pr-info**: Display PR statistics
- **changed-files**: Detect which components changed
- **code-quality**: Check for merge conflicts, TODOs, secrets
- **markdown-lint**: Lint markdown files
- **shellcheck**: Check shell scripts
- **dependency-review**: Review dependency changes
- **size-check**: Warn on large PRs
- **label-pr**: Auto-label based on changed files

### 5. Security Scanning (`security.yml`)

**Triggers:**
- Push to `master`/`main`
- Pull requests to `master`/`main`
- Schedule: Daily at 2 AM UTC
- Manual: `workflow_dispatch`

**Jobs:**
- **secret-scanning**: Gitleaks and TruffleHog
- **dependency-scanning**: Safety for Python dependencies
- **infrastructure-scanning**: tfsec, Checkov, Terrascan
- **code-scanning**: CodeQL analysis
- **python-security**: Bandit security scanner
- **license-compliance**: Check open source licenses
- **sast-semgrep**: Semgrep static analysis
- **security-scorecard**: OpenSSF Scorecard

## Setup Instructions

### 1. Configure GitHub Secrets

Navigate to your repository Settings → Secrets and variables → Actions, and add:

**Required:**
- `AWS_ACCESS_KEY_ID`: Your AWS access key ID
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key

**Optional (for notify Lambda):**
- `SLACK_WEBHOOK_URL`: Slack webhook for notifications
- `DISCORD_WEBHOOK_URL`: Discord webhook URL
- `TEAMS_WEBHOOK_URL`: Microsoft Teams webhook URL
- `PAGERDUTY_API_KEY`: PagerDuty API key
- `PAGERDUTY_ROUTING_KEY`: PagerDuty routing key

### 2. Configure GitHub Environments

Create environments in Settings → Environments:

**Production Environment (`prod`):**
- Add protection rules (require reviews, etc.)
- Add environment secrets if different from repository secrets
- Configure deployment branches to `master` only

### 3. Enable GitHub Actions

1. Go to Settings → Actions → General
2. Allow all actions and reusable workflows
3. Set workflow permissions to "Read and write permissions"
4. Enable "Allow GitHub Actions to create and approve pull requests"

### 4. Configure Branch Protection

For `master` branch:
- ✅ Require status checks to pass before merging
  - Terraform Validate
  - Lambda Tests
  - Ansible Lint
  - Code Quality Checks
- ✅ Require pull request reviews before merging
- ✅ Require conversation resolution before merging

## Workflow Dependencies

```
Pull Request → PR Validation
            ├─→ Terraform Validate → Terraform Plan
            ├─→ Lambda Test → Lambda Build
            ├─→ Ansible Lint → Ansible Validate
            └─→ Security Scanning

Merge to Master → Terraform Validate → Terraform Apply
               → Lambda Test → Lambda Build → Lambda Deploy
```

## Local Testing

### Test Terraform Locally

```bash
cd environments/prod
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

### Test Lambda Locally

```bash
cd lambda
pip install -r functions/*/requirements.txt
pip install pytest pytest-cov pytest-mock boto3 moto
pytest tests/ -v --cov
```

### Test Ansible Locally

```bash
cd ansible
ansible-lint playbooks/*.yml
ansible-playbook playbooks/deploy_app.yml --syntax-check
```

## Workflow Outputs

### Artifacts

Workflows generate the following artifacts:

1. **Terraform Plan** (`tfplan-{environment}`): 5 days retention
2. **Lambda Packages** (`lambda-{function}`): 30 days retention
3. **Security Reports**: 30 days retention
   - Bandit reports
   - Safety reports
   - License reports

### Notifications

Workflows comment on PRs with:
- Terraform plan output
- Test results and coverage
- Validation status
- Security scan results

## Troubleshooting

### Terraform Apply Fails

1. Check AWS credentials are valid
2. Verify backend configuration in `environments/*/backend.tf`
3. Check for state lock issues in DynamoDB

### Lambda Deploy Fails

1. Ensure Lambda function exists (deployed via Terraform first)
2. Check IAM permissions for Lambda update
3. Verify function name matches pattern: `self-healing-infra-{env}-{function}`

### Security Scans Failing

1. Review security reports in workflow artifacts
2. Fix critical/high severity issues
3. Use `skip_check` in Checkov for false positives (document why)

### Tests Failing

1. Check test output in workflow logs
2. Run tests locally to reproduce
3. Update mocks if AWS APIs changed

## Best Practices

### Commits

- Write clear, descriptive commit messages
- Keep commits focused and atomic
- Reference issues/PRs in commit messages

### Pull Requests

- Keep PRs small (< 50 files, < 1000 lines)
- Fill out PR description template
- Wait for all checks to pass
- Respond to review comments

### Security

- Never commit secrets to the repository
- Use GitHub Secrets for sensitive data
- Review security scan results regularly
- Keep dependencies up to date

## Monitoring

Monitor workflow runs:
- **Actions tab**: View all workflow runs
- **Pull Request checks**: See status on PRs
- **Email notifications**: Configure in GitHub settings

## Advanced Configuration

### Customize Workflows

Edit workflow files in `.github/workflows/`:
- Adjust triggers and paths
- Modify job steps
- Add/remove security tools
- Change schedule for scans

### Add New Environments

1. Create environment directory: `environments/dev/`
2. Update workflow matrix to include new environment
3. Configure environment in GitHub Settings

### Add Custom Checks

Create new workflow files following the pattern:
```yaml
name: Custom Check
on:
  pull_request:
    branches: [master, main]
jobs:
  custom-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run custom check
        run: ./scripts/custom-check.sh
```

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [AWS Actions](https://github.com/aws-actions)
- [Security Scanning Tools](https://github.com/marketplace?category=security)
