# Monitoring & Observability Guide

Comprehensive guide for monitoring the self-healing infrastructure platform using CloudWatch and Grafana.

## Table of Contents

1. [Overview](#overview)
2. [CloudWatch Dashboards](#cloudwatch-dashboards)
3. [Grafana Dashboards](#grafana-dashboards)
4. [Alarms & Alerts](#alarms--alerts)
5. [Custom Metrics](#custom-metrics)
6. [Log Analysis](#log-analysis)
7. [Setup Instructions](#setup-instructions)
8. [Troubleshooting](#troubleshooting)

## Overview

The monitoring stack consists of:
- **CloudWatch**: Native AWS monitoring, metrics, logs, and alarms
- **Grafana**: Advanced visualization and dashboarding
- **Custom Metrics**: Application-specific metrics via metric filters
- **Log Insights**: Query and analyze logs in real-time

### Architecture

```
EC2 Instances → CloudWatch Agent → CloudWatch Metrics
                                         ↓
Lambda Functions → CloudWatch Logs → Metric Filters → Custom Metrics
                                         ↓
ALB → CloudWatch Metrics                 ↓
                                    CloudWatch Alarms → SNS → Lambda
                                         ↓
                                    CloudWatch Dashboards
                                         ↓
                                    Grafana Dashboards
```

## CloudWatch Dashboards

### Main Dashboard

Located at: `monitoring/dashboards/cloudwatch/main-dashboard.json`

**Metrics Displayed:**
- EC2 CPU Utilization (avg, max)
- Memory Utilization
- Disk Utilization
- Network Traffic (in/out)
- ALB Response Time
- ALB Request Count
- Target Health (healthy/unhealthy)
- HTTP Response Codes (2xx, 4xx, 5xx)
- Auto Scaling Group Capacity
- Lambda Invocations
- Lambda Errors & Throttles
- Lambda Duration
- Recent Lambda Errors (logs)

**Access Dashboard:**
```bash
# Via AWS CLI
aws cloudwatch get-dashboard \
  --dashboard-name self-healing-infra-prod-main

# Via Console
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=self-healing-infra-prod-main
```

### Deploying Dashboard

Dashboard is automatically deployed via Terraform:

```bash
cd environments/prod
terraform apply -target=module.cloudwatch.aws_cloudwatch_dashboard.main
```

## Grafana Dashboards

### System Overview Dashboard

**File:** `monitoring/dashboards/grafana/system_overview.json`

**Panels:**
1. **Stats Widgets** (top row):
   - Instances In Service
   - Healthy Targets
   - Avg CPU Utilization
   - Avg Memory Utilization

2. **Time Series**:
   - EC2 CPU Utilization (avg vs max)
   - Memory Utilization
   - ALB Request Rate
   - ALB Response Time (p95, mean, max)
   - HTTP Response Codes (stacked bars)
   - Auto Scaling Group Capacity

**Features:**
- 30-second auto-refresh
- 6-hour time range
- CloudWatch alarm annotations
- Dark theme optimized

### Self-Healing Dashboard

**File:** `monitoring/dashboards/grafana/self_healing_dashboard.json`

**Panels:**
1. **24h Stats**:
   - Total Remediations
   - Lambda Errors
   - Notifications Sent
   - Failed Notifications

2. **Remediation Tracking**:
   - Remediation Actions by Type (stacked bars)
   - Remediation Distribution (pie chart)
   - Success vs Failures (line chart)

3. **Lambda Performance**:
   - Execution Duration (avg, p95, max)
   - Invocation Rate
   - Error Rate

4. **Notifications**:
   - Notifications by Channel (Slack, PagerDuty, SNS)

5. **Logs**:
   - Recent Remediation Events (CloudWatch Logs)

## Alarms & Alerts

### Alarm Definitions

Located at: `monitoring/dashboards/cloudwatch/alarm-definitions.json`

**Critical Alarms** (trigger PagerDuty):
- `ec2-cpu-utilization-critical` - CPU > 95%
- `memory-utilization-critical` - Memory > 95%
- `disk-utilization-critical` - Disk > 95%
- `alb-no-healthy-targets` - No healthy targets
- `composite-system-health` - Multiple failures

**Warning Alarms** (SNS notification):
- `ec2-cpu-utilization-high` - CPU > 80%
- `memory-utilization-high` - Memory > 85%
- `disk-utilization-high` - Disk > 85%
- `alb-unhealthy-targets` - Unhealthy targets detected
- `alb-high-response-time` - Response time > 1s
- `lambda-errors-high` - Errors > 5 in 5 minutes

**Info Alarms**:
- `ec2-cpu-utilization-low` - CPU < 20% (scale down)
- `asg-instance-termination` - Instance terminated

### Alarm Actions

Alarms trigger different actions based on severity:

```
Critical → SNS → Lambda (notify) → PagerDuty + Slack
Warning  → SNS → Lambda (notify) → Slack
Info     → SNS → Lambda (notify) → Slack (optional)
```

### Viewing Alarms

**AWS Console:**
```
CloudWatch → Alarms → All alarms
Filter by: State (ALARM, OK, INSUFFICIENT_DATA)
```

**AWS CLI:**
```bash
# List all alarms
aws cloudwatch describe-alarms

# List only ALARM state
aws cloudwatch describe-alarms \
  --state-value ALARM

# Get specific alarm
aws cloudwatch describe-alarms \
  --alarm-names "self-healing-infra-prod-cpu-utilization-high"
```

## Custom Metrics

### Metric Filters

Metric filters extract custom metrics from CloudWatch Logs.

**Location:** `monitoring/dashboards/cloudwatch/metric-filters.json`

**Available Metrics:**

#### Remediation Metrics (`SelfHealingInfra/Remediation`):
- `RemediationCount` - Total remediation actions
- `HighCPURemediationCount` - CPU-related remediations
- `MemoryClearCount` - Memory cache clears
- `DiskCleanupCount` - Disk cleanup operations
- `ScalingOperationCount` - Auto-scaling events
- `UnhealthyInstanceTerminations` - Terminated instances
- `RemediationSuccessCount` - Successful remediations
- `RemediationFailureCount` - Failed remediations

#### Notification Metrics (`SelfHealingInfra/Notifications`):
- `NotificationCount` - Total notifications sent
- `NotificationErrorCount` - Failed notifications
- `SlackNotificationCount` - Slack notifications
- `PagerDutyAlertCount` - PagerDuty alerts

#### Application Metrics (`SelfHealingInfra/Application`):
- `ApplicationErrorCount` - Application errors
- `ApplicationResponseTime` - Response time from logs
- `ApplicationRequestCount` - HTTP requests
- `Application5xxCount` - 5xx errors

### Querying Custom Metrics

**AWS CLI:**
```bash
# Get remediation count
aws cloudwatch get-metric-statistics \
  --namespace SelfHealingInfra/Remediation \
  --metric-name RemediationCount \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Get notification count
aws cloudwatch get-metric-statistics \
  --namespace SelfHealingInfra/Notifications \
  --metric-name NotificationCount \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

## Log Analysis

### CloudWatch Logs Insights

**Common Queries:**

#### 1. Remediation Events
```
fields @timestamp, @message
| filter @message like /Remediation/
| sort @timestamp desc
| limit 50
```

#### 2. Error Analysis
```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by @message
| sort count desc
```

#### 3. Lambda Performance
```
fields @timestamp, @duration, @billedDuration, @memorySize, @maxMemoryUsed
| filter @type = "REPORT"
| stats avg(@duration), max(@duration), pct(@duration, 95) by bin(5m)
```

#### 4. Remediation Success Rate
```
fields @timestamp
| filter @message like /successfully/ or @message like /ERROR/
| stats count(*) as total,
  sum(@message like /successfully/) as success,
  sum(@message like /ERROR/) as failures
| extend success_rate = success / total * 100
```

#### 5. Most Common Remediation Types
```
fields @timestamp, @message
| filter @message like /Handling high/
| parse @message /Handling high (?<type>[A-Za-z]+)/
| stats count() by type
| sort count desc
```

### Running Queries

**AWS Console:**
1. Go to CloudWatch → Logs → Insights
2. Select log group: `/aws/lambda/self-healing-infra-prod-trigger_remediation`
3. Paste query
4. Select time range
5. Click "Run query"

**AWS CLI:**
```bash
# Start query
QUERY_ID=$(aws logs start-query \
  --log-group-name "/aws/lambda/self-healing-infra-prod-trigger_remediation" \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /Remediation/ | limit 20' \
  --query 'queryId' \
  --output text)

# Get results
aws logs get-query-results --query-id $QUERY_ID
```

## Setup Instructions

### 1. Deploy CloudWatch Dashboard

```bash
cd environments/prod
terraform apply -target=module.cloudwatch
```

### 2. Setup Grafana

#### Option A: Docker (Recommended for local)

```bash
cd monitoring/grafana

# Ensure AWS credentials are configured
aws configure list

# Start Grafana
docker-compose up -d

# Access Grafana
open http://localhost:3000
# Username: admin
# Password: admin
```

#### Option B: EC2 Instance

```bash
# Install Grafana on Ubuntu
sudo apt-get install -y adduser libfontconfig1
wget https://dl.grafana.com/oss/release/grafana_10.2.3_amd64.deb
sudo dpkg -i grafana_10.2.3_amd64.deb

# Install CloudWatch plugin
sudo grafana-cli plugins install grafana-cloudwatch-datasource

# Start Grafana
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Access: http://<instance-ip>:3000
```

### 3. Import Dashboards

**Via Grafana UI:**
1. Login to Grafana (admin/admin)
2. Go to Dashboards → Import
3. Upload JSON files from `monitoring/dashboards/grafana/`
   - `system_overview.json`
   - `self_healing_dashboard.json`
4. Select "CloudWatch" as datasource
5. Click "Import"

**Via API:**
```bash
# Import system overview dashboard
curl -X POST http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @monitoring/dashboards/grafana/system_overview.json \
  -u admin:admin

# Import self-healing dashboard
curl -X POST http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @monitoring/dashboards/grafana/self_healing_dashboard.json \
  -u admin:admin
```

### 4. Configure Alerts

**In Grafana:**
1. Open dashboard panel
2. Click "Alert" tab
3. Create alert rule:
   - Condition: `WHEN last() OF query(A) IS ABOVE 80`
   - Evaluation: Every `1m` for `5m`
   - Notification: Slack/PagerDuty

### 5. Set Up CloudWatch Agent (for Memory/Disk metrics)

```bash
# Install on EC2 instances
sudo yum install amazon-cloudwatch-agent

# Create config
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard

# Start agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
```

## Troubleshooting

### Dashboard Not Showing Data

**Issue:** Grafana dashboard shows "No data"

**Solutions:**
1. Check AWS credentials:
   ```bash
   aws sts get-caller-identity
   ```

2. Verify datasource configuration:
   - Grafana → Configuration → Data Sources
   - Test connection

3. Check metric names match exactly:
   ```bash
   aws cloudwatch list-metrics --namespace AWS/EC2
   ```

4. Ensure time range is correct (last 6 hours)

### Alarms Not Triggering

**Issue:** Alarms stay in INSUFFICIENT_DATA state

**Solutions:**
1. Check metric is publishing:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/EC2 \
     --metric-name CPUUtilization \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Average
   ```

2. Verify dimensions are correct:
   ```bash
   aws autoscaling describe-auto-scaling-groups \
     --query 'AutoScalingGroups[*].AutoScalingGroupName'
   ```

3. Check alarm configuration:
   ```bash
   aws cloudwatch describe-alarms \
     --alarm-names "your-alarm-name"
   ```

### Custom Metrics Not Appearing

**Issue:** Metric filters not creating metrics

**Solutions:**
1. Check log group exists:
   ```bash
   aws logs describe-log-groups \
     --log-group-name-prefix "/aws/lambda/self-healing"
   ```

2. Verify filter pattern matches logs:
   ```bash
   aws logs test-metric-filter \
     --filter-pattern '[time, request_id, level = ERROR*, ...]' \
     --log-event-messages "2024-01-01 12:00:00 req-123 ERROR Something failed"
   ```

3. Check metric filter exists:
   ```bash
   aws logs describe-metric-filters \
     --log-group-name "/aws/lambda/self-healing-infra-prod-trigger_remediation"
   ```

### Grafana Can't Connect to CloudWatch

**Issue:** "Access denied" or "Invalid credentials"

**Solutions:**
1. Ensure AWS credentials have CloudWatch permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": [
         "cloudwatch:DescribeAlarms",
         "cloudwatch:GetMetricStatistics",
         "cloudwatch:ListMetrics",
         "logs:DescribeLogGroups",
         "logs:GetQueryResults",
         "logs:StartQuery"
       ],
       "Resource": "*"
     }]
   }
   ```

2. For Docker, ensure `.aws` directory is mounted:
   ```yaml
   volumes:
     - ~/.aws:/usr/share/grafana/.aws:ro
   ```

3. Restart Grafana after credential changes

## Best Practices

### 1. Alert Fatigue Prevention
- Set appropriate thresholds
- Use evaluation periods to avoid flapping
- Implement composite alarms for critical issues
- Use different notification channels by severity

### 2. Dashboard Organization
- Group related metrics together
- Use appropriate visualization types
- Add descriptions to panels
- Set reasonable refresh intervals (30s-1m)

### 3. Log Management
- Use structured logging
- Include request IDs for tracing
- Set appropriate retention periods
- Create metric filters for KPIs

### 4. Cost Optimization
- Use metric math to reduce API calls
- Set appropriate retention periods (7-30 days)
- Use log sampling for high-volume logs
- Consolidate similar alarms

### 5. Performance
- Use appropriate query periods (5m for real-time, 1h for trends)
- Limit log query results
- Use caching in Grafana
- Optimize metric filter patterns

## Additional Resources

- [CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)
- [Grafana CloudWatch Data Source](https://grafana.com/docs/grafana/latest/datasources/cloudwatch/)
- [CloudWatch Logs Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [CloudWatch Agent Configuration](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file.html)

## Quick Reference

### Common Commands

```bash
# View recent alarms
aws cloudwatch describe-alarm-history --max-records 10

# Disable alarm
aws cloudwatch disable-alarm-actions --alarm-names "alarm-name"

# Enable alarm
aws cloudwatch enable-alarm-actions --alarm-names "alarm-name"

# Test alarm
aws cloudwatch set-alarm-state \
  --alarm-name "alarm-name" \
  --state-value ALARM \
  --state-reason "Testing alarm"

# Get dashboard
aws cloudwatch get-dashboard --dashboard-name "dashboard-name"

# List metric filters
aws logs describe-metric-filters

# Tail logs
aws logs tail /aws/lambda/self-healing-infra-prod-trigger_remediation --follow
```

### Useful Grafana Queries

```
# Query with math expression
SELECT SUM(value) FROM metrics WHERE time > now() - 1h

# Multiple metrics
SELECT metric1, metric2 FROM metrics

# Percentile calculation
SELECT percentile(latency, 95) FROM metrics GROUP BY time(5m)
```

---

**Last Updated:** 2024-01-01
**Maintainer:** DevOps Team
**Version:** 1.0
