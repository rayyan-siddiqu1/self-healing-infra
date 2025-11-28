# Monitoring Directory

This directory contains all monitoring and observability configurations for the self-healing infrastructure.

## Directory Structure

```
monitoring/
├── dashboards/
│   ├── cloudwatch/
│   │   ├── main-dashboard.json         # Main CloudWatch dashboard
│   │   ├── alarm-definitions.json      # Alarm configurations
│   │   └── metric-filters.json         # Custom metric filters
│   └── grafana/
│       ├── system_overview.json        # System metrics dashboard
│       └── self_healing_dashboard.json # Remediation tracking dashboard
├── grafana/
│   ├── docker-compose.yml              # Grafana Docker setup
│   └── provisioning/
│       ├── datasources/
│       │   └── cloudwatch.yml          # CloudWatch datasource config
│       └── dashboards/
│           └── dashboard.yml           # Dashboard provisioning config
└── README.md                           # This file
```

## Quick Start

### 1. Deploy CloudWatch Dashboards

CloudWatch dashboards and metric filters are automatically deployed via Terraform:

```bash
cd environments/prod
terraform apply -target=module.cloudwatch
```

### 2. Launch Grafana

**Using Docker:**
```bash
cd monitoring/grafana
docker-compose up -d

# Access at http://localhost:3000
# Default credentials: admin/admin
```

**View logs:**
```bash
docker-compose logs -f grafana
```

**Stop Grafana:**
```bash
docker-compose down
```

### 3. Import Dashboards

Dashboards are automatically loaded from the `dashboards/grafana/` directory when using the Docker setup.

**Manual import:**
1. Login to Grafana
2. Go to Dashboards → Import
3. Upload JSON files from `dashboards/grafana/`

## Dashboards

### CloudWatch Main Dashboard

**Features:**
- EC2 metrics (CPU, memory, disk, network)
- ALB metrics (requests, response time, health)
- Lambda metrics (invocations, errors, duration)
- Auto Scaling Group capacity
- Real-time log insights

**Access:**
```bash
# Via AWS CLI
aws cloudwatch get-dashboard \
  --dashboard-name self-healing-infra-prod-main

# Via Console
https://console.aws.amazon.com/cloudwatch/home#dashboards:
```

### Grafana System Overview

**Features:**
- Real-time infrastructure metrics
- Multi-AZ visibility
- Response time percentiles (p50, p95, p99)
- HTTP status code distribution
- Auto-refresh every 30 seconds

**Panels:**
- Instance health stats
- CPU & Memory trends
- ALB performance
- HTTP response codes
- Auto Scaling capacity

### Grafana Self-Healing Dashboard

**Features:**
- Remediation action tracking
- Success vs failure rates
- Notification channel distribution
- Lambda performance metrics
- Recent remediation logs

**Panels:**
- 24h remediation stats
- Remediation by type (pie chart)
- Lambda execution duration
- Notification counts by channel
- Real-time log stream

## Custom Metrics

### Publishing Custom Metrics

Use the provided script to collect and publish custom application metrics:

```bash
# Single collection
./scripts/collect_custom_metrics.sh

# Run as daemon (every 60 seconds)
./scripts/collect_custom_metrics.sh --daemon

# Custom interval (every 30 seconds)
./scripts/collect_custom_metrics.sh --daemon --interval 30
```

### Available Custom Metrics

Located in `SelfHealingInfra/Custom` namespace:
- **SystemHealth**: Overall health score (0-100)
- **ActiveSessions**: Number of active connections
- **CacheHitRate**: Cache hit percentage
- **QueueDepth**: Message queue depth
- **DatabaseConnections**: Active DB connections
- **ApplicationResponseTime**: Response time in ms
- **DiskIOUtilization**: Disk I/O utilization percentage

### Creating Custom Metrics from Logs

Metric filters extract metrics from CloudWatch Logs automatically.

**Example:** Count error messages
```json
{
  "filterPattern": "[time, request_id, level = ERROR*, ...]",
  "metricTransformations": [{
    "metricName": "ErrorCount",
    "metricNamespace": "SelfHealingInfra/Application",
    "metricValue": "1"
  }]
}
```

## Alarms

### Viewing Alarms

**AWS Console:**
```
CloudWatch → Alarms → All alarms
```

**AWS CLI:**
```bash
# List all alarms
aws cloudwatch describe-alarms

# List only triggered alarms
aws cloudwatch describe-alarms --state-value ALARM

# Get alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name "self-healing-infra-prod-cpu-utilization-high" \
  --max-records 10
```

### Alarm Severity

- **Critical**: Immediate action required (PagerDuty + Slack)
- **Warning**: Attention needed (Slack)
- **Info**: Informational (Slack optional)

### Testing Alarms

```bash
# Manually trigger alarm (for testing)
aws cloudwatch set-alarm-state \
  --alarm-name "self-healing-infra-prod-cpu-utilization-high" \
  --state-value ALARM \
  --state-reason "Testing alarm notification"
```

## Grafana Configuration

### Datasource Setup

CloudWatch datasource is automatically configured via provisioning.

**Manual setup:**
1. Go to Configuration → Data Sources
2. Add CloudWatch
3. Set authentication type: "AWS SDK Default"
4. Set default region: "us-east-1"
5. Save & Test

### Dashboard Variables

Dashboards support these variables:
- **Environment**: Filter by environment (dev, prod)
- **Instance**: Filter by instance ID
- **Time Range**: Adjustable time window

### Alert Notifications

**Setup Slack:**
1. Go to Alerting → Notification channels
2. Add new channel: Slack
3. Enter webhook URL
4. Test notification

**Setup PagerDuty:**
1. Go to Alerting → Notification channels
2. Add new channel: PagerDuty
3. Enter integration key
4. Set severity mapping

## Log Analysis

### CloudWatch Logs Insights Queries

**View recent errors:**
```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

**Remediation success rate:**
```
fields @timestamp
| filter @message like /Remediation/
| stats count(*) as total,
  sum(@message like /success/) as success
| extend success_rate = success / total * 100
```

**Lambda performance:**
```
fields @timestamp, @duration
| filter @type = "REPORT"
| stats avg(@duration), max(@duration), pct(@duration, 95)
```

### Running Queries

**AWS Console:**
1. CloudWatch → Logs → Insights
2. Select log group
3. Enter query
4. Run query

**AWS CLI:**
```bash
# Start query
QUERY_ID=$(aws logs start-query \
  --log-group-name "/aws/lambda/self-healing-infra-prod-trigger_remediation" \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | limit 20' \
  --query 'queryId' --output text)

# Get results
aws logs get-query-results --query-id $QUERY_ID
```

## Maintenance

### Updating Dashboards

**CloudWatch:**
1. Edit JSON in `dashboards/cloudwatch/`
2. Deploy via Terraform:
   ```bash
   terraform apply -target=module.cloudwatch.aws_cloudwatch_dashboard.main
   ```

**Grafana:**
1. Edit dashboard in Grafana UI
2. Export JSON
3. Save to `dashboards/grafana/`
4. Commit to git

### Backup Dashboards

```bash
# Backup CloudWatch dashboards
aws cloudwatch get-dashboard \
  --dashboard-name self-healing-infra-prod-main \
  > backup-main-dashboard.json

# Backup Grafana dashboards
curl -H "Authorization: Bearer $API_KEY" \
  http://localhost:3000/api/dashboards/uid/self-healing-system \
  > backup-grafana-system.json
```

### Cleanup

```bash
# Stop Grafana
cd monitoring/grafana
docker-compose down -v

# Delete CloudWatch dashboard
aws cloudwatch delete-dashboards \
  --dashboard-names self-healing-infra-prod-main
```

## Troubleshooting

### Grafana Can't Connect to CloudWatch

1. Check AWS credentials:
   ```bash
   aws sts get-caller-identity
   ```

2. Verify credentials are mounted:
   ```bash
   docker-compose exec grafana ls -la /usr/share/grafana/.aws
   ```

3. Check Grafana logs:
   ```bash
   docker-compose logs grafana | grep -i error
   ```

### No Metrics in Dashboard

1. Verify metrics exist:
   ```bash
   aws cloudwatch list-metrics --namespace AWS/EC2
   ```

2. Check time range (metrics may be delayed)

3. Verify dimensions match (ASG name, instance ID)

### Alarms Not Triggering

1. Check alarm state:
   ```bash
   aws cloudwatch describe-alarms \
     --alarm-names "your-alarm-name"
   ```

2. Verify SNS subscription:
   ```bash
   aws sns list-subscriptions-by-topic \
     --topic-arn "your-sns-topic-arn"
   ```

3. Test SNS manually:
   ```bash
   aws sns publish \
     --topic-arn "your-sns-topic-arn" \
     --message "Test notification"
   ```

## Resources

- [Full Monitoring Documentation](../docs/MONITORING.md)
- [CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)
- [Grafana Documentation](https://grafana.com/docs/)
- [CloudWatch Logs Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)

## Quick Reference

```bash
# View CloudWatch dashboard
aws cloudwatch get-dashboard --dashboard-name self-healing-infra-prod-main

# List alarms in ALARM state
aws cloudwatch describe-alarms --state-value ALARM

# Tail Lambda logs
aws logs tail /aws/lambda/self-healing-infra-prod-trigger_remediation --follow

# Get metric statistics
aws cloudwatch get-metric-statistics \
  --namespace SelfHealingInfra/Remediation \
  --metric-name RemediationCount \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Start Grafana
cd monitoring/grafana && docker-compose up -d

# Stop Grafana
cd monitoring/grafana && docker-compose down
```

---

For detailed information, see [MONITORING.md](../docs/MONITORING.md)
