"""
Self-Healing Infrastructure - Remediation Trigger Lambda
This function receives CloudWatch alarm notifications and triggers appropriate remediation actions.
"""

import json
import os
import boto3
from datetime import datetime

# Initialize AWS clients
ec2_client = boto3.client('ec2')
asg_client = boto3.client('autoscaling')
sns_client = boto3.client('sns')
ssm_client = boto3.client('ssm')

# Environment variables
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'prod')
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'self-healing-infra')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
ASG_NAME = os.environ.get('ASG_NAME', '')


def lambda_handler(event, context):
    """
    Main Lambda handler function
    Processes SNS messages from CloudWatch alarms and triggers remediation
    """
    print(f"Received event: {json.dumps(event)}")

    try:
        # Parse SNS message
        for record in event.get('Records', []):
            if record.get('EventSource') == 'aws:sns':
                message = json.loads(record['Sns']['Message'])
                process_alarm(message)

        return {
            'statusCode': 200,
            'body': json.dumps('Remediation triggered successfully')
        }

    except Exception as e:
        print(f"Error processing event: {str(e)}")
        send_notification(f"Error in remediation Lambda: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }


def process_alarm(message):
    """Process CloudWatch alarm and determine remediation action"""
    alarm_name = message.get('AlarmName', '')
    alarm_description = message.get('AlarmDescription', '')
    new_state = message.get('NewStateValue', '')
    reason = message.get('NewStateReason', '')

    print(f"Processing alarm: {alarm_name}")
    print(f"State: {new_state}")
    print(f"Reason: {reason}")

    if new_state != 'ALARM':
        print(f"Alarm is not in ALARM state, skipping remediation")
        return

    # Determine remediation action based on alarm name
    if 'cpu-utilization-high' in alarm_name.lower():
        handle_high_cpu()
    elif 'memory-utilization-high' in alarm_name.lower():
        handle_high_memory()
    elif 'disk-utilization-high' in alarm_name.lower():
        handle_high_disk()
    elif 'unhealthy-targets' in alarm_name.lower():
        handle_unhealthy_targets()
    else:
        print(f"No specific remediation for alarm: {alarm_name}")
        send_notification(f"Alert: {alarm_name} triggered but no remediation configured")


def handle_high_cpu():
    """Handle high CPU utilization by scaling up"""
    print("Handling high CPU utilization...")

    try:
        # Get current ASG configuration
        response = asg_client.describe_auto_scaling_groups(
            AutoScalingGroupNames=[ASG_NAME]
        )

        if not response['AutoScalingGroups']:
            print(f"ASG {ASG_NAME} not found")
            return

        asg = response['AutoScalingGroups'][0]
        current_capacity = asg['DesiredCapacity']
        max_capacity = asg['MaxSize']

        if current_capacity < max_capacity:
            new_capacity = min(current_capacity + 1, max_capacity)
            print(f"Scaling up from {current_capacity} to {new_capacity} instances")

            asg_client.set_desired_capacity(
                AutoScalingGroupName=ASG_NAME,
                DesiredCapacity=new_capacity
            )

            send_notification(
                f"Remediation: Scaled up {ASG_NAME} from {current_capacity} to {new_capacity} instances due to high CPU"
            )
        else:
            print(f"ASG already at maximum capacity ({max_capacity})")
            send_notification(
                f"Alert: High CPU detected but ASG {ASG_NAME} already at maximum capacity"
            )

    except Exception as e:
        print(f"Error handling high CPU: {str(e)}")
        send_notification(f"Error in high CPU remediation: {str(e)}")


def handle_high_memory():
    """Handle high memory utilization"""
    print("Handling high memory utilization...")

    try:
        # Get instances in the ASG
        instances = get_asg_instances()

        if not instances:
            print("No instances found in ASG")
            return

        # Send command to clear memory caches (safe operation)
        for instance_id in instances:
            print(f"Clearing memory cache on instance {instance_id}")

            try:
                # This command is safe and just drops caches
                ssm_client.send_command(
                    InstanceIds=[instance_id],
                    DocumentName='AWS-RunShellScript',
                    Parameters={
                        'commands': [
                            'echo "Clearing memory caches..."',
                            'sync',
                            'echo 1 > /proc/sys/vm/drop_caches || true',
                            'echo "Cache cleared"'
                        ]
                    },
                    Comment='Clear memory caches - self-healing'
                )
                print(f"Memory cache clear command sent to {instance_id}")

            except Exception as e:
                print(f"Error sending command to {instance_id}: {str(e)}")

        send_notification(f"Remediation: Cleared memory caches on {len(instances)} instances due to high memory usage")

    except Exception as e:
        print(f"Error handling high memory: {str(e)}")
        send_notification(f"Error in high memory remediation: {str(e)}")


def handle_high_disk():
    """Handle high disk utilization"""
    print("Handling high disk utilization...")

    try:
        instances = get_asg_instances()

        for instance_id in instances:
            print(f"Cleaning disk space on instance {instance_id}")

            try:
                # Clean up temporary files and logs
                ssm_client.send_command(
                    InstanceIds=[instance_id],
                    DocumentName='AWS-RunShellScript',
                    Parameters={
                        'commands': [
                            'echo "Cleaning disk space..."',
                            'find /tmp -type f -atime +7 -delete || true',
                            'find /var/log -type f -name "*.log.*" -mtime +7 -delete || true',
                            'journalctl --vacuum-time=7d || true',
                            'echo "Disk cleanup completed"'
                        ]
                    },
                    Comment='Disk cleanup - self-healing'
                )
                print(f"Disk cleanup command sent to {instance_id}")

            except Exception as e:
                print(f"Error sending command to {instance_id}: {str(e)}")

        send_notification(f"Remediation: Cleaned disk space on {len(instances)} instances")

    except Exception as e:
        print(f"Error handling high disk: {str(e)}")
        send_notification(f"Error in high disk remediation: {str(e)}")


def handle_unhealthy_targets():
    """Handle unhealthy target instances"""
    print("Handling unhealthy targets...")

    try:
        instances = get_asg_instances()

        for instance_id in instances:
            # Check instance health
            response = ec2_client.describe_instance_status(
                InstanceIds=[instance_id]
            )

            if response['InstanceStatuses']:
                status = response['InstanceStatuses'][0]
                instance_status = status['InstanceStatus']['Status']
                system_status = status['SystemStatus']['Status']

                if instance_status != 'ok' or system_status != 'ok':
                    print(f"Instance {instance_id} is unhealthy, terminating...")
                    asg_client.terminate_instance_in_auto_scaling_group(
                        InstanceId=instance_id,
                        ShouldDecrementDesiredCapacity=False
                    )
                    send_notification(f"Remediation: Terminated unhealthy instance {instance_id}")

    except Exception as e:
        print(f"Error handling unhealthy targets: {str(e)}")
        send_notification(f"Error in unhealthy target remediation: {str(e)}")


def get_asg_instances():
    """Get list of instance IDs in the Auto Scaling Group"""
    try:
        response = asg_client.describe_auto_scaling_groups(
            AutoScalingGroupNames=[ASG_NAME]
        )

        if not response['AutoScalingGroups']:
            return []

        instances = response['AutoScalingGroups'][0]['Instances']
        instance_ids = [i['InstanceId'] for i in instances if i['LifecycleState'] == 'InService']

        return instance_ids

    except Exception as e:
        print(f"Error getting ASG instances: {str(e)}")
        return []


def send_notification(message):
    """Send notification to SNS topic"""
    if not SNS_TOPIC_ARN:
        print("SNS_TOPIC_ARN not configured, skipping notification")
        return

    try:
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f'{PROJECT_NAME} - Self-Healing Action',
            Message=f"{message}\n\nTimestamp: {datetime.utcnow().isoformat()}Z\nEnvironment: {ENVIRONMENT}"
        )
        print(f"Notification sent: {message}")

    except Exception as e:
        print(f"Error sending notification: {str(e)}")
