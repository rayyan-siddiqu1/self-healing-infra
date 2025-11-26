"""
Self-Healing Infrastructure - Multi-Channel Notification Lambda
Sends notifications to multiple channels: Slack, Email, SNS, PagerDuty, Discord, Teams
"""

import json
import os
import boto3
from datetime import datetime
from urllib import request, parse
from typing import Dict, Any, List, Optional

# Initialize AWS clients
sns_client = boto3.client('sns')
ses_client = boto3.client('ses')
ssm_client = boto3.client('ssm')

# Environment variables
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'prod')
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'self-healing-infra')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
DEFAULT_EMAIL = os.environ.get('DEFAULT_EMAIL', '')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')

# Notification channels configuration (from environment or SSM)
SLACK_WEBHOOK_URL = os.environ.get('SLACK_WEBHOOK_URL', '')
DISCORD_WEBHOOK_URL = os.environ.get('DISCORD_WEBHOOK_URL', '')
TEAMS_WEBHOOK_URL = os.environ.get('TEAMS_WEBHOOK_URL', '')
PAGERDUTY_API_KEY = os.environ.get('PAGERDUTY_API_KEY', '')
PAGERDUTY_ROUTING_KEY = os.environ.get('PAGERDUTY_ROUTING_KEY', '')

# Severity levels
SEVERITY_LEVELS = {
    'critical': {'color': '#dc3545', 'emoji': '=¨', 'pagerduty': 'critical'},
    'error': {'color': '#fd7e14', 'emoji': 'L', 'pagerduty': 'error'},
    'warning': {'color': '#ffc107', 'emoji': ' ', 'pagerduty': 'warning'},
    'info': {'color': '#17a2b8', 'emoji': '9', 'pagerduty': 'info'},
    'success': {'color': '#28a745', 'emoji': '', 'pagerduty': 'info'}
}


def lambda_handler(event, context):
    """
    Main Lambda handler function
    Processes notification requests and sends to configured channels
    """
    print(f"Received event: {json.dumps(event)}")

    try:
        # Parse the notification payload
        notification = parse_notification(event)

        # Send to all configured channels
        results = send_notifications(notification)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Notifications sent successfully',
                'results': results
            })
        }

    except Exception as e:
        print(f"Error processing notification: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }


def parse_notification(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Parse notification from various event sources
    """
    notification = {
        'title': '',
        'message': '',
        'severity': 'info',
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'source': 'lambda',
        'metadata': {}
    }

    # Check if it's from SNS
    if 'Records' in event:
        for record in event['Records']:
            if record.get('EventSource') == 'aws:sns':
                sns_message = json.loads(record['Sns']['Message'])
                notification.update(parse_sns_message(sns_message))

    # Check if it's a direct invocation
    elif 'message' in event:
        notification['message'] = event['message']
        notification['severity'] = event.get('severity', 'info')
        notification['title'] = event.get('title', f'{PROJECT_NAME} Notification')
        notification['source'] = event.get('source', 'direct')
        notification['metadata'] = event.get('metadata', {})

    # Check if it's a CloudWatch alarm
    elif 'AlarmName' in event:
        notification.update(parse_cloudwatch_alarm(event))

    return notification


def parse_sns_message(message: Dict[str, Any]) -> Dict[str, Any]:
    """Parse SNS message format"""
    return {
        'title': message.get('Subject', 'SNS Notification'),
        'message': message.get('Message', ''),
        'severity': determine_severity_from_message(message.get('Message', '')),
        'source': 'sns',
        'metadata': message
    }


def parse_cloudwatch_alarm(alarm: Dict[str, Any]) -> Dict[str, Any]:
    """Parse CloudWatch alarm format"""
    alarm_name = alarm.get('AlarmName', 'Unknown Alarm')
    new_state = alarm.get('NewStateValue', 'UNKNOWN')
    reason = alarm.get('NewStateReason', '')

    severity = 'critical' if new_state == 'ALARM' else 'success'

    return {
        'title': f'CloudWatch Alarm: {alarm_name}',
        'message': f'State: {new_state}\nReason: {reason}',
        'severity': severity,
        'source': 'cloudwatch',
        'metadata': alarm
    }


def determine_severity_from_message(message: str) -> str:
    """Determine severity based on message content"""
    message_lower = message.lower()

    if any(word in message_lower for word in ['critical', 'down', 'failed', 'failure']):
        return 'critical'
    elif any(word in message_lower for word in ['error', 'problem', 'issue']):
        return 'error'
    elif any(word in message_lower for word in ['warning', 'warn', 'degraded']):
        return 'warning'
    elif any(word in message_lower for word in ['success', 'resolved', 'recovered', 'healthy']):
        return 'success'
    else:
        return 'info'


def send_notifications(notification: Dict[str, Any]) -> Dict[str, Any]:
    """
    Send notification to all configured channels
    """
    results = {}

    # Send to Slack
    if SLACK_WEBHOOK_URL:
        results['slack'] = send_slack_notification(notification)

    # Send to Discord
    if DISCORD_WEBHOOK_URL:
        results['discord'] = send_discord_notification(notification)

    # Send to Microsoft Teams
    if TEAMS_WEBHOOK_URL:
        results['teams'] = send_teams_notification(notification)

    # Send to PagerDuty
    if PAGERDUTY_API_KEY and PAGERDUTY_ROUTING_KEY:
        results['pagerduty'] = send_pagerduty_notification(notification)

    # Send to SNS
    if SNS_TOPIC_ARN:
        results['sns'] = send_sns_notification(notification)

    # Send email via SES
    if DEFAULT_EMAIL:
        results['email'] = send_email_notification(notification)

    return results


def send_slack_notification(notification: Dict[str, Any]) -> Dict[str, str]:
    """Send notification to Slack"""
    try:
        severity_info = SEVERITY_LEVELS.get(notification['severity'], SEVERITY_LEVELS['info'])

        payload = {
            'username': f'{PROJECT_NAME} Monitor',
            'icon_emoji': ':robot_face:',
            'attachments': [{
                'color': severity_info['color'],
                'title': f"{severity_info['emoji']} {notification['title']}",
                'text': notification['message'],
                'fields': [
                    {
                        'title': 'Severity',
                        'value': notification['severity'].upper(),
                        'short': True
                    },
                    {
                        'title': 'Environment',
                        'value': ENVIRONMENT,
                        'short': True
                    },
                    {
                        'title': 'Source',
                        'value': notification['source'],
                        'short': True
                    },
                    {
                        'title': 'Timestamp',
                        'value': notification['timestamp'],
                        'short': True
                    }
                ],
                'footer': PROJECT_NAME,
                'ts': int(datetime.utcnow().timestamp())
            }]
        }

        data = json.dumps(payload).encode('utf-8')
        req = request.Request(
            SLACK_WEBHOOK_URL,
            data=data,
            headers={'Content-Type': 'application/json'}
        )

        with request.urlopen(req) as response:
            result = response.read().decode()
            print(f"Slack notification sent: {result}")
            return {'status': 'success', 'response': result}

    except Exception as e:
        error_msg = f"Error sending Slack notification: {str(e)}"
        print(error_msg)
        return {'status': 'error', 'error': error_msg}


def send_discord_notification(notification: Dict[str, Any]) -> Dict[str, str]:
    """Send notification to Discord"""
    try:
        severity_info = SEVERITY_LEVELS.get(notification['severity'], SEVERITY_LEVELS['info'])

        # Convert hex color to decimal
        color_decimal = int(severity_info['color'].lstrip('#'), 16)

        payload = {
            'username': f'{PROJECT_NAME} Monitor',
            'embeds': [{
                'title': f"{severity_info['emoji']} {notification['title']}",
                'description': notification['message'],
                'color': color_decimal,
                'fields': [
                    {'name': 'Severity', 'value': notification['severity'].upper(), 'inline': True},
                    {'name': 'Environment', 'value': ENVIRONMENT, 'inline': True},
                    {'name': 'Source', 'value': notification['source'], 'inline': True},
                    {'name': 'Timestamp', 'value': notification['timestamp'], 'inline': True}
                ],
                'footer': {'text': PROJECT_NAME},
                'timestamp': notification['timestamp']
            }]
        }

        data = json.dumps(payload).encode('utf-8')
        req = request.Request(
            DISCORD_WEBHOOK_URL,
            data=data,
            headers={'Content-Type': 'application/json'}
        )

        with request.urlopen(req) as response:
            result = response.read().decode()
            print(f"Discord notification sent")
            return {'status': 'success', 'response': result}

    except Exception as e:
        error_msg = f"Error sending Discord notification: {str(e)}"
        print(error_msg)
        return {'status': 'error', 'error': error_msg}


def send_teams_notification(notification: Dict[str, Any]) -> Dict[str, str]:
    """Send notification to Microsoft Teams"""
    try:
        severity_info = SEVERITY_LEVELS.get(notification['severity'], SEVERITY_LEVELS['info'])

        payload = {
            '@type': 'MessageCard',
            '@context': 'https://schema.org/extensions',
            'summary': notification['title'],
            'themeColor': severity_info['color'].lstrip('#'),
            'title': f"{severity_info['emoji']} {notification['title']}",
            'text': notification['message'],
            'sections': [{
                'facts': [
                    {'name': 'Severity', 'value': notification['severity'].upper()},
                    {'name': 'Environment', 'value': ENVIRONMENT},
                    {'name': 'Source', 'value': notification['source']},
                    {'name': 'Timestamp', 'value': notification['timestamp']}
                ]
            }]
        }

        data = json.dumps(payload).encode('utf-8')
        req = request.Request(
            TEAMS_WEBHOOK_URL,
            data=data,
            headers={'Content-Type': 'application/json'}
        )

        with request.urlopen(req) as response:
            result = response.read().decode()
            print(f"Teams notification sent")
            return {'status': 'success', 'response': result}

    except Exception as e:
        error_msg = f"Error sending Teams notification: {str(e)}"
        print(error_msg)
        return {'status': 'error', 'error': error_msg}


def send_pagerduty_notification(notification: Dict[str, Any]) -> Dict[str, str]:
    """Send notification to PagerDuty"""
    try:
        severity_info = SEVERITY_LEVELS.get(notification['severity'], SEVERITY_LEVELS['info'])

        # Only trigger PagerDuty for critical and error events
        if notification['severity'] not in ['critical', 'error']:
            print("Skipping PagerDuty notification for non-critical event")
            return {'status': 'skipped', 'reason': 'non-critical event'}

        payload = {
            'routing_key': PAGERDUTY_ROUTING_KEY,
            'event_action': 'trigger',
            'payload': {
                'summary': notification['title'],
                'source': f"{PROJECT_NAME}-{ENVIRONMENT}",
                'severity': severity_info['pagerduty'],
                'timestamp': notification['timestamp'],
                'custom_details': {
                    'message': notification['message'],
                    'environment': ENVIRONMENT,
                    'source': notification['source'],
                    'metadata': notification.get('metadata', {})
                }
            }
        }

        data = json.dumps(payload).encode('utf-8')
        req = request.Request(
            'https://events.pagerduty.com/v2/enqueue',
            data=data,
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Token token={PAGERDUTY_API_KEY}'
            }
        )

        with request.urlopen(req) as response:
            result = json.loads(response.read().decode())
            print(f"PagerDuty notification sent: {result}")
            return {'status': 'success', 'response': result}

    except Exception as e:
        error_msg = f"Error sending PagerDuty notification: {str(e)}"
        print(error_msg)
        return {'status': 'error', 'error': error_msg}


def send_sns_notification(notification: Dict[str, Any]) -> Dict[str, str]:
    """Send notification via SNS"""
    try:
        message = f"""
{notification['title']}

{notification['message']}

Severity: {notification['severity'].upper()}
Environment: {ENVIRONMENT}
Source: {notification['source']}
Timestamp: {notification['timestamp']}
"""

        response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=notification['title'],
            Message=message
        )

        print(f"SNS notification sent: {response['MessageId']}")
        return {'status': 'success', 'messageId': response['MessageId']}

    except Exception as e:
        error_msg = f"Error sending SNS notification: {str(e)}"
        print(error_msg)
        return {'status': 'error', 'error': error_msg}


def send_email_notification(notification: Dict[str, Any]) -> Dict[str, str]:
    """Send email notification via SES"""
    try:
        severity_info = SEVERITY_LEVELS.get(notification['severity'], SEVERITY_LEVELS['info'])

        html_body = f"""
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; }}
                .header {{ background-color: {severity_info['color']}; color: white; padding: 20px; }}
                .content {{ padding: 20px; }}
                .metadata {{ background-color: #f8f9fa; padding: 15px; margin-top: 20px; }}
                .footer {{ color: #6c757d; padding: 20px; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="header">
                <h1>{severity_info['emoji']} {notification['title']}</h1>
            </div>
            <div class="content">
                <p>{notification['message'].replace(chr(10), '<br>')}</p>

                <div class="metadata">
                    <strong>Severity:</strong> {notification['severity'].upper()}<br>
                    <strong>Environment:</strong> {ENVIRONMENT}<br>
                    <strong>Source:</strong> {notification['source']}<br>
                    <strong>Timestamp:</strong> {notification['timestamp']}
                </div>
            </div>
            <div class="footer">
                <p>This is an automated notification from {PROJECT_NAME}</p>
            </div>
        </body>
        </html>
        """

        response = ses_client.send_email(
            Source=f"{PROJECT_NAME} <{DEFAULT_EMAIL}>",
            Destination={'ToAddresses': [DEFAULT_EMAIL]},
            Message={
                'Subject': {'Data': notification['title']},
                'Body': {
                    'Html': {'Data': html_body},
                    'Text': {'Data': notification['message']}
                }
            }
        )

        print(f"Email notification sent: {response['MessageId']}")
        return {'status': 'success', 'messageId': response['MessageId']}

    except Exception as e:
        error_msg = f"Error sending email notification: {str(e)}"
        print(error_msg)
        return {'status': 'error', 'error': error_msg}


# Helper function to retrieve secrets from SSM Parameter Store
def get_ssm_parameter(parameter_name: str, decrypt: bool = True) -> Optional[str]:
    """Retrieve parameter from SSM Parameter Store"""
    try:
        response = ssm_client.get_parameter(
            Name=parameter_name,
            WithDecryption=decrypt
        )
        return response['Parameter']['Value']
    except Exception as e:
        print(f"Error retrieving SSM parameter {parameter_name}: {str(e)}")
        return None
