# Notify Lambda Function

Multi-channel notification Lambda function that sends alerts to Slack, Discord, Microsoft Teams, PagerDuty, SNS, and Email (SES).

## Features

- **Multi-Channel Support**: Send notifications to multiple channels simultaneously
- **Severity Levels**: Critical, Error, Warning, Info, Success
- **Smart Routing**: PagerDuty only triggered for critical/error events
- **Rich Formatting**: Color-coded messages with metadata
- **Flexible Input**: Supports SNS events, CloudWatch alarms, and direct invocations

## Supported Channels

1. **Slack** - Via webhook
2. **Discord** - Via webhook
3. **Microsoft Teams** - Via webhook
4. **PagerDuty** - Via Events API v2
5. **SNS** - AWS SNS topic
6. **Email** - AWS SES

## Environment Variables

### Required
- `ENVIRONMENT`: Environment name (dev, prod)
- `PROJECT_NAME`: Project identifier
- `AWS_REGION`: AWS region

### Optional - Notification Channels
- `SLACK_WEBHOOK_URL`: Slack incoming webhook URL
- `DISCORD_WEBHOOK_URL`: Discord webhook URL
- `TEAMS_WEBHOOK_URL`: Microsoft Teams webhook URL
- `PAGERDUTY_API_KEY`: PagerDuty API key
- `PAGERDUTY_ROUTING_KEY`: PagerDuty integration routing key
- `SNS_TOPIC_ARN`: SNS topic ARN for notifications
- `DEFAULT_EMAIL`: Email address for SES notifications

## Usage

### Direct Invocation

```python
import boto3
import json

lambda_client = boto3.client('lambda')

payload = {
    'title': 'Database Backup Completed',
    'message': 'Daily backup completed successfully at 2024-01-01 00:00:00',
    'severity': 'success',
    'source': 'backup-job',
    'metadata': {
        'backup_size': '10GB',
        'duration': '5 minutes'
    }
}

response = lambda_client.invoke(
    FunctionName='self-healing-infra-prod-notify',
    InvocationType='Event',  # Async
    Payload=json.dumps(payload)
)
```

### Via SNS

The Lambda automatically subscribes to SNS topics and processes alarm notifications:

```json
{
  "Records": [{
    "EventSource": "aws:sns",
    "Sns": {
      "Message": "{\"Subject\":\"Alert\",\"Message\":\"Service degraded\"}"
    }
  }]
}
```

### Via CloudWatch Alarm

CloudWatch alarms are automatically processed:

```json
{
  "AlarmName": "cpu-utilization-high",
  "NewStateValue": "ALARM",
  "NewStateReason": "Threshold exceeded: 1 datapoint [95.0] was greater than the threshold (80.0)"
}
```

## Severity Levels

| Severity | Color | Emoji | PagerDuty | Use Case |
|----------|-------|-------|-----------|----------|
| `critical` | Red | 🚨 | critical | System down, data loss |
| `error` | Orange | ❌ | error | Failed operations, errors |
| `warning` | Yellow | ⚠️ | warning | Degraded performance |
| `info` | Blue | ℹ️ | info | Informational messages |
| `success` | Green | ✅ | info | Successful operations |

## Message Format

### Input Format

```json
{
  "title": "Notification Title",
  "message": "Detailed message body",
  "severity": "critical|error|warning|info|success",
  "source": "source-identifier",
  "metadata": {
    "key": "value"
  }
}
```

### Slack Output

```
🚨 Critical Alert: Database Connection Lost

Connection to primary database failed after 3 retry attempts.

Severity: CRITICAL
Environment: prod
Source: database-monitor
Timestamp: 2024-01-01T12:00:00Z
```

## Configuration

### Setting Up Slack

1. Create Slack App: https://api.slack.com/apps
2. Enable Incoming Webhooks
3. Create webhook for your channel
4. Set `SLACK_WEBHOOK_URL` environment variable

### Setting Up Discord

1. Open Discord channel settings
2. Go to Integrations → Webhooks
3. Create New Webhook
4. Copy webhook URL
5. Set `DISCORD_WEBHOOK_URL` environment variable

### Setting Up Microsoft Teams

1. Open Teams channel
2. Click ... → Connectors
3. Configure Incoming Webhook
4. Provide name and upload image
5. Copy webhook URL
6. Set `TEAMS_WEBHOOK_URL` environment variable

### Setting Up PagerDuty

1. Create PagerDuty service
2. Add Events API v2 integration
3. Copy Integration Key (routing key)
4. Set `PAGERDUTY_ROUTING_KEY` environment variable
5. Create API key in User Settings
6. Set `PAGERDUTY_API_KEY` environment variable

### Setting Up SES

1. Verify email address in AWS SES
2. Move out of SES sandbox (if needed)
3. Set `DEFAULT_EMAIL` environment variable

## Deployment

### Via Terraform

The Lambda is deployed automatically via Terraform:

```hcl
module "lambda" {
  source = "../../terraform/modules/lambda"

  lambda_environment_variables = {
    SLACK_WEBHOOK_URL = var.slack_webhook_url
    DISCORD_WEBHOOK_URL = var.discord_webhook_url
    # ... other variables
  }
}
```

### Via CI/CD

Push changes to the `lambda/functions/notify/` directory:

```bash
git add lambda/functions/notify/
git commit -m "Update notify Lambda"
git push
```

GitHub Actions will automatically test, build, and deploy.

## Testing

### Unit Tests

```bash
cd lambda
pytest tests/test_notify.py -v --cov
```

### Manual Test

```bash
aws lambda invoke \
  --function-name self-healing-infra-prod-notify \
  --payload '{"message":"Test","severity":"info","title":"Test"}' \
  response.json

cat response.json
```

## Monitoring

### CloudWatch Logs

Logs are available in CloudWatch Logs:
- Log Group: `/aws/lambda/self-healing-infra-prod-notify`
- View errors: Filter pattern `ERROR`
- View invocations: All logs

### CloudWatch Metrics

Monitor Lambda metrics:
- Invocations
- Errors
- Duration
- Throttles

### Alerts

Set up CloudWatch alarms for:
- High error rate
- Long duration
- Throttling

## Troubleshooting

### Slack Notifications Not Received

1. Check `SLACK_WEBHOOK_URL` is set correctly
2. Verify webhook is active in Slack
3. Check CloudWatch logs for errors
4. Test webhook with curl:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test"}' \
     YOUR_WEBHOOK_URL
   ```

### PagerDuty Not Triggering

1. Verify `PAGERDUTY_ROUTING_KEY` is correct
2. Check severity is `critical` or `error`
3. Verify service is not in maintenance mode
4. Check PagerDuty event logs

### Email Not Sending

1. Verify email is verified in SES
2. Check SES sending limits
3. Ensure Lambda has SES permissions
4. Check spam folder

## Security Best Practices

1. **Use SSM Parameter Store** for webhook URLs:
   ```python
   # Store webhooks in SSM
   aws ssm put-parameter \
     --name /prod/notify/slack_webhook \
     --value "https://hooks.slack.com/..." \
     --type SecureString
   ```

2. **Rotate Webhooks** regularly
3. **Limit IAM Permissions** to minimum required
4. **Enable VPC** if sending to internal services
5. **Use Encryption** for environment variables

## Performance

- **Cold Start**: ~500ms
- **Warm Execution**: ~100-200ms
- **Concurrent Executions**: Unlimited (within account limits)
- **Timeout**: 30 seconds (configurable)

## Cost Estimation

For 10,000 notifications/month:
- Lambda invocations: ~$0.20
- CloudWatch Logs: ~$0.50
- SNS: ~$0.50
- SES: ~$1.00
- **Total**: ~$2.20/month

## Examples

### Success Notification

```python
{
    "title": "Deployment Successful",
    "message": "Application v2.1.0 deployed to production",
    "severity": "success",
    "source": "ci-cd",
    "metadata": {
        "version": "2.1.0",
        "environment": "production",
        "deployed_by": "john.doe"
    }
}
```

### Critical Alert

```python
{
    "title": "Service Outage Detected",
    "message": "API gateway is not responding. All production traffic affected.",
    "severity": "critical",
    "source": "monitoring",
    "metadata": {
        "affected_regions": ["us-east-1", "us-west-2"],
        "started_at": "2024-01-01T12:00:00Z"
    }
}
```

### Warning

```python
{
    "title": "High Memory Usage",
    "message": "Memory usage at 85%, approaching threshold of 90%",
    "severity": "warning",
    "source": "cloudwatch",
    "metadata": {
        "current_usage": "85%",
        "threshold": "90%",
        "instance_id": "i-1234567890"
    }
}
```

## Contributing

When modifying the notify Lambda:

1. Update unit tests in `lambda/tests/test_notify.py`
2. Run tests locally: `pytest tests/test_notify.py -v`
3. Update this README if adding features
4. Create PR with clear description
5. Ensure CI/CD passes

## License

Part of the self-healing-infra project.
