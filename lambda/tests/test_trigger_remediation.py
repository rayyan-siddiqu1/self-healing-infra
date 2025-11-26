"""
Unit tests for the trigger_remediation Lambda function
"""

import json
import pytest
from unittest.mock import Mock, patch, MagicMock
import sys
import os

# Add the function directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../functions/trigger_remediation'))

import main


@pytest.fixture
def mock_env(monkeypatch):
    """Set up environment variables for testing"""
    monkeypatch.setenv('ENVIRONMENT', 'test')
    monkeypatch.setenv('PROJECT_NAME', 'test-project')
    monkeypatch.setenv('SNS_TOPIC_ARN', 'arn:aws:sns:us-east-1:123456789012:test-topic')
    monkeypatch.setenv('ASG_NAME', 'test-asg')


@pytest.fixture
def sns_event_cpu_high():
    """SNS event for high CPU alarm"""
    return {
        'Records': [{
            'EventSource': 'aws:sns',
            'Sns': {
                'Message': json.dumps({
                    'AlarmName': 'test-cpu-utilization-high',
                    'AlarmDescription': 'CPU utilization high',
                    'NewStateValue': 'ALARM',
                    'NewStateReason': 'Threshold exceeded'
                })
            }
        }]
    }


@pytest.fixture
def sns_event_memory_high():
    """SNS event for high memory alarm"""
    return {
        'Records': [{
            'EventSource': 'aws:sns',
            'Sns': {
                'Message': json.dumps({
                    'AlarmName': 'test-memory-utilization-high',
                    'AlarmDescription': 'Memory utilization high',
                    'NewStateValue': 'ALARM',
                    'NewStateReason': 'Threshold exceeded'
                })
            }
        }]
    }


@pytest.fixture
def sns_event_disk_high():
    """SNS event for high disk alarm"""
    return {
        'Records': [{
            'EventSource': 'aws:sns',
            'Sns': {
                'Message': json.dumps({
                    'AlarmName': 'test-disk-utilization-high',
                    'AlarmDescription': 'Disk utilization high',
                    'NewStateValue': 'ALARM',
                    'NewStateReason': 'Threshold exceeded'
                })
            }
        }]
    }


@pytest.fixture
def sns_event_unhealthy_targets():
    """SNS event for unhealthy targets"""
    return {
        'Records': [{
            'EventSource': 'aws:sns',
            'Sns': {
                'Message': json.dumps({
                    'AlarmName': 'test-unhealthy-targets',
                    'AlarmDescription': 'Unhealthy targets detected',
                    'NewStateValue': 'ALARM',
                    'NewStateReason': 'Targets unhealthy'
                })
            }
        }]
    }


@pytest.fixture
def sns_event_ok_state():
    """SNS event for OK state (no action needed)"""
    return {
        'Records': [{
            'EventSource': 'aws:sns',
            'Sns': {
                'Message': json.dumps({
                    'AlarmName': 'test-alarm',
                    'NewStateValue': 'OK',
                    'NewStateReason': 'Threshold not exceeded'
                })
            }
        }]
    }


class TestLambdaHandler:
    """Test the main Lambda handler"""

    @patch('main.process_alarm')
    def test_lambda_handler_success(self, mock_process, sns_event_cpu_high, mock_env):
        """Test successful Lambda execution"""
        context = Mock()
        result = main.lambda_handler(sns_event_cpu_high, context)

        assert result['statusCode'] == 200
        assert 'Remediation triggered successfully' in result['body']
        mock_process.assert_called_once()

    @patch('main.process_alarm')
    @patch('main.send_notification')
    def test_lambda_handler_error(self, mock_send, mock_process, sns_event_cpu_high, mock_env):
        """Test Lambda error handling"""
        mock_process.side_effect = Exception('Test error')

        context = Mock()
        result = main.lambda_handler(sns_event_cpu_high, context)

        assert result['statusCode'] == 500
        assert 'Error' in result['body']
        mock_send.assert_called_once()


class TestProcessAlarm:
    """Test alarm processing logic"""

    @patch('main.handle_high_cpu')
    def test_process_alarm_cpu_high(self, mock_handle, mock_env):
        """Test processing high CPU alarm"""
        message = {
            'AlarmName': 'test-cpu-utilization-high',
            'NewStateValue': 'ALARM',
            'NewStateReason': 'CPU threshold exceeded'
        }

        main.process_alarm(message)
        mock_handle.assert_called_once()

    @patch('main.handle_high_memory')
    def test_process_alarm_memory_high(self, mock_handle, mock_env):
        """Test processing high memory alarm"""
        message = {
            'AlarmName': 'test-memory-utilization-high',
            'NewStateValue': 'ALARM',
            'NewStateReason': 'Memory threshold exceeded'
        }

        main.process_alarm(message)
        mock_handle.assert_called_once()

    @patch('main.handle_high_disk')
    def test_process_alarm_disk_high(self, mock_handle, mock_env):
        """Test processing high disk alarm"""
        message = {
            'AlarmName': 'test-disk-utilization-high',
            'NewStateValue': 'ALARM',
            'NewStateReason': 'Disk threshold exceeded'
        }

        main.process_alarm(message)
        mock_handle.assert_called_once()

    @patch('main.handle_unhealthy_targets')
    def test_process_alarm_unhealthy_targets(self, mock_handle, mock_env):
        """Test processing unhealthy targets alarm"""
        message = {
            'AlarmName': 'test-unhealthy-targets',
            'NewStateValue': 'ALARM',
            'NewStateReason': 'Targets are unhealthy'
        }

        main.process_alarm(message)
        mock_handle.assert_called_once()

    def test_process_alarm_ok_state(self, mock_env):
        """Test that OK state doesn't trigger remediation"""
        message = {
            'AlarmName': 'test-alarm',
            'NewStateValue': 'OK',
            'NewStateReason': 'Back to normal'
        }

        # Should not raise any exception, just skip
        main.process_alarm(message)

    @patch('main.send_notification')
    def test_process_alarm_unknown_type(self, mock_send, mock_env):
        """Test processing unknown alarm type"""
        message = {
            'AlarmName': 'test-unknown-alarm',
            'NewStateValue': 'ALARM',
            'NewStateReason': 'Unknown issue'
        }

        main.process_alarm(message)
        mock_send.assert_called_once()


class TestHandleHighCPU:
    """Test high CPU remediation"""

    @patch('main.asg_client')
    @patch('main.send_notification')
    def test_handle_high_cpu_scale_up(self, mock_send, mock_asg, mock_env):
        """Test scaling up on high CPU"""
        mock_asg.describe_auto_scaling_groups.return_value = {
            'AutoScalingGroups': [{
                'DesiredCapacity': 2,
                'MaxSize': 4
            }]
        }

        main.handle_high_cpu()

        mock_asg.set_desired_capacity.assert_called_once_with(
            AutoScalingGroupName='test-asg',
            DesiredCapacity=3
        )
        mock_send.assert_called_once()

    @patch('main.asg_client')
    @patch('main.send_notification')
    def test_handle_high_cpu_at_max(self, mock_send, mock_asg, mock_env):
        """Test handling high CPU when at max capacity"""
        mock_asg.describe_auto_scaling_groups.return_value = {
            'AutoScalingGroups': [{
                'DesiredCapacity': 4,
                'MaxSize': 4
            }]
        }

        main.handle_high_cpu()

        mock_asg.set_desired_capacity.assert_not_called()
        mock_send.assert_called_once()

    @patch('main.asg_client')
    def test_handle_high_cpu_asg_not_found(self, mock_asg, mock_env):
        """Test handling when ASG not found"""
        mock_asg.describe_auto_scaling_groups.return_value = {
            'AutoScalingGroups': []
        }

        # Should not raise exception
        main.handle_high_cpu()


class TestHandleHighMemory:
    """Test high memory remediation"""

    @patch('main.ssm_client')
    @patch('main.get_asg_instances')
    @patch('main.send_notification')
    def test_handle_high_memory(self, mock_send, mock_get_instances, mock_ssm, mock_env):
        """Test clearing memory caches"""
        mock_get_instances.return_value = ['i-123456', 'i-789012']

        main.handle_high_memory()

        assert mock_ssm.send_command.call_count == 2
        mock_send.assert_called_once()

    @patch('main.get_asg_instances')
    def test_handle_high_memory_no_instances(self, mock_get_instances, mock_env):
        """Test handling when no instances found"""
        mock_get_instances.return_value = []

        # Should not raise exception
        main.handle_high_memory()


class TestHandleHighDisk:
    """Test high disk remediation"""

    @patch('main.ssm_client')
    @patch('main.get_asg_instances')
    @patch('main.send_notification')
    def test_handle_high_disk(self, mock_send, mock_get_instances, mock_ssm, mock_env):
        """Test disk cleanup"""
        mock_get_instances.return_value = ['i-123456', 'i-789012']

        main.handle_high_disk()

        assert mock_ssm.send_command.call_count == 2
        mock_send.assert_called_once()


class TestHandleUnhealthyTargets:
    """Test unhealthy targets remediation"""

    @patch('main.ec2_client')
    @patch('main.asg_client')
    @patch('main.get_asg_instances')
    @patch('main.send_notification')
    def test_handle_unhealthy_targets_terminate(self, mock_send, mock_get_instances, mock_asg, mock_ec2, mock_env):
        """Test terminating unhealthy instances"""
        mock_get_instances.return_value = ['i-123456']
        mock_ec2.describe_instance_status.return_value = {
            'InstanceStatuses': [{
                'InstanceStatus': {'Status': 'impaired'},
                'SystemStatus': {'Status': 'ok'}
            }]
        }

        main.handle_unhealthy_targets()

        mock_asg.terminate_instance_in_auto_scaling_group.assert_called_once_with(
            InstanceId='i-123456',
            ShouldDecrementDesiredCapacity=False
        )
        mock_send.assert_called_once()

    @patch('main.ec2_client')
    @patch('main.get_asg_instances')
    def test_handle_unhealthy_targets_all_healthy(self, mock_get_instances, mock_ec2, mock_env):
        """Test when all instances are healthy"""
        mock_get_instances.return_value = ['i-123456']
        mock_ec2.describe_instance_status.return_value = {
            'InstanceStatuses': [{
                'InstanceStatus': {'Status': 'ok'},
                'SystemStatus': {'Status': 'ok'}
            }]
        }

        # Should not terminate any instances
        main.handle_unhealthy_targets()


class TestGetASGInstances:
    """Test ASG instance retrieval"""

    @patch('main.asg_client')
    def test_get_asg_instances_success(self, mock_asg, mock_env):
        """Test successful instance retrieval"""
        mock_asg.describe_auto_scaling_groups.return_value = {
            'AutoScalingGroups': [{
                'Instances': [
                    {'InstanceId': 'i-123456', 'LifecycleState': 'InService'},
                    {'InstanceId': 'i-789012', 'LifecycleState': 'InService'},
                    {'InstanceId': 'i-pending', 'LifecycleState': 'Pending'}
                ]
            }]
        }

        result = main.get_asg_instances()

        assert len(result) == 2
        assert 'i-123456' in result
        assert 'i-789012' in result
        assert 'i-pending' not in result

    @patch('main.asg_client')
    def test_get_asg_instances_not_found(self, mock_asg, mock_env):
        """Test when ASG not found"""
        mock_asg.describe_auto_scaling_groups.return_value = {
            'AutoScalingGroups': []
        }

        result = main.get_asg_instances()
        assert result == []

    @patch('main.asg_client')
    def test_get_asg_instances_error(self, mock_asg, mock_env):
        """Test error handling"""
        mock_asg.describe_auto_scaling_groups.side_effect = Exception('API error')

        result = main.get_asg_instances()
        assert result == []


class TestSendNotification:
    """Test notification sending"""

    @patch('main.sns_client')
    def test_send_notification_success(self, mock_sns, mock_env):
        """Test successful notification"""
        main.send_notification('Test message')

        mock_sns.publish.assert_called_once()
        call_args = mock_sns.publish.call_args
        assert 'Test message' in call_args[1]['Message']

    @patch('main.sns_client')
    def test_send_notification_no_topic(self, mock_sns, monkeypatch):
        """Test when SNS topic not configured"""
        monkeypatch.setenv('SNS_TOPIC_ARN', '')

        # Should not raise exception
        main.send_notification('Test message')
        mock_sns.publish.assert_not_called()

    @patch('main.sns_client')
    def test_send_notification_error(self, mock_sns, mock_env):
        """Test notification error handling"""
        mock_sns.publish.side_effect = Exception('SNS error')

        # Should not raise exception
        main.send_notification('Test message')


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
