"""
Unit tests for the notify Lambda function
"""

import json
import pytest
from unittest.mock import Mock, patch, MagicMock
import sys
import os

# Add the function directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../functions/notify'))

import main


@pytest.fixture
def mock_env(monkeypatch):
    """Set up environment variables for testing"""
    monkeypatch.setenv('ENVIRONMENT', 'test')
    monkeypatch.setenv('PROJECT_NAME', 'test-project')
    monkeypatch.setenv('SNS_TOPIC_ARN', 'arn:aws:sns:us-east-1:123456789012:test-topic')
    monkeypatch.setenv('DEFAULT_EMAIL', 'test@example.com')
    monkeypatch.setenv('AWS_REGION', 'us-east-1')


@pytest.fixture
def sample_notification():
    """Sample notification payload"""
    return {
        'title': 'Test Notification',
        'message': 'This is a test message',
        'severity': 'info',
        'timestamp': '2024-01-01T00:00:00Z',
        'source': 'test',
        'metadata': {}
    }


@pytest.fixture
def sns_event():
    """Sample SNS event"""
    return {
        'Records': [{
            'EventSource': 'aws:sns',
            'Sns': {
                'Message': json.dumps({
                    'Subject': 'Test SNS Message',
                    'Message': 'Test message body'
                })
            }
        }]
    }


@pytest.fixture
def cloudwatch_alarm_event():
    """Sample CloudWatch alarm event"""
    return {
        'AlarmName': 'test-alarm',
        'NewStateValue': 'ALARM',
        'NewStateReason': 'Threshold exceeded'
    }


@pytest.fixture
def direct_invocation_event():
    """Sample direct invocation event"""
    return {
        'message': 'Direct test message',
        'severity': 'warning',
        'title': 'Direct Test',
        'source': 'direct'
    }


class TestParseNotification:
    """Test notification parsing functions"""

    def test_parse_sns_message(self):
        """Test parsing SNS message"""
        message = {
            'Subject': 'Test Subject',
            'Message': 'Test critical message'
        }
        result = main.parse_sns_message(message)

        assert result['title'] == 'Test Subject'
        assert result['message'] == 'Test critical message'
        assert result['source'] == 'sns'
        assert result['severity'] in main.SEVERITY_LEVELS.keys()

    def test_parse_cloudwatch_alarm(self):
        """Test parsing CloudWatch alarm"""
        alarm = {
            'AlarmName': 'cpu-high',
            'NewStateValue': 'ALARM',
            'NewStateReason': 'CPU exceeded threshold'
        }
        result = main.parse_cloudwatch_alarm(alarm)

        assert 'cpu-high' in result['title']
        assert result['severity'] == 'critical'
        assert result['source'] == 'cloudwatch'
        assert 'ALARM' in result['message']

    def test_parse_notification_from_sns(self, sns_event):
        """Test parsing notification from SNS event"""
        result = main.parse_notification(sns_event)

        assert result['source'] == 'sns'
        assert result['title'] != ''
        assert result['message'] != ''

    def test_parse_notification_from_cloudwatch(self, cloudwatch_alarm_event):
        """Test parsing notification from CloudWatch alarm"""
        result = main.parse_notification(cloudwatch_alarm_event)

        assert result['source'] == 'cloudwatch'
        assert 'test-alarm' in result['title']
        assert result['severity'] == 'critical'

    def test_parse_notification_direct(self, direct_invocation_event):
        """Test parsing direct invocation"""
        result = main.parse_notification(direct_invocation_event)

        assert result['message'] == 'Direct test message'
        assert result['severity'] == 'warning'
        assert result['title'] == 'Direct Test'


class TestDetermineSeverity:
    """Test severity determination"""

    def test_critical_severity(self):
        """Test critical severity detection"""
        assert main.determine_severity_from_message('System is down') == 'critical'
        assert main.determine_severity_from_message('Critical failure detected') == 'critical'
        assert main.determine_severity_from_message('Service failed') == 'critical'

    def test_error_severity(self):
        """Test error severity detection"""
        assert main.determine_severity_from_message('An error occurred') == 'error'
        assert main.determine_severity_from_message('Problem detected') == 'error'

    def test_warning_severity(self):
        """Test warning severity detection"""
        assert main.determine_severity_from_message('Warning: high CPU') == 'warning'
        assert main.determine_severity_from_message('Service degraded') == 'warning'

    def test_success_severity(self):
        """Test success severity detection"""
        assert main.determine_severity_from_message('Successfully recovered') == 'success'
        assert main.determine_severity_from_message('System is healthy') == 'success'

    def test_info_severity(self):
        """Test info severity (default)"""
        assert main.determine_severity_from_message('Regular message') == 'info'


class TestNotificationChannels:
    """Test notification channel functions"""

    @patch('main.sns_client')
    def test_send_sns_notification(self, mock_sns, sample_notification, mock_env):
        """Test SNS notification sending"""
        mock_sns.publish.return_value = {'MessageId': 'test-message-id'}

        result = main.send_sns_notification(sample_notification)

        assert result['status'] == 'success'
        assert result['messageId'] == 'test-message-id'
        mock_sns.publish.assert_called_once()

    @patch('main.request.urlopen')
    def test_send_slack_notification_success(self, mock_urlopen, sample_notification, mock_env, monkeypatch):
        """Test successful Slack notification"""
        monkeypatch.setenv('SLACK_WEBHOOK_URL', 'https://hooks.slack.com/test')

        mock_response = MagicMock()
        mock_response.read.return_value = b'ok'
        mock_urlopen.return_value.__enter__.return_value = mock_response

        result = main.send_slack_notification(sample_notification)

        assert result['status'] == 'success'
        mock_urlopen.assert_called_once()

    @patch('main.request.urlopen')
    def test_send_discord_notification_success(self, mock_urlopen, sample_notification, mock_env, monkeypatch):
        """Test successful Discord notification"""
        monkeypatch.setenv('DISCORD_WEBHOOK_URL', 'https://discord.com/api/webhooks/test')

        mock_response = MagicMock()
        mock_response.read.return_value = b''
        mock_urlopen.return_value.__enter__.return_value = mock_response

        result = main.send_discord_notification(sample_notification)

        assert result['status'] == 'success'
        mock_urlopen.assert_called_once()

    @patch('main.request.urlopen')
    def test_send_teams_notification_success(self, mock_urlopen, sample_notification, mock_env, monkeypatch):
        """Test successful Teams notification"""
        monkeypatch.setenv('TEAMS_WEBHOOK_URL', 'https://outlook.office.com/webhook/test')

        mock_response = MagicMock()
        mock_response.read.return_value = b'1'
        mock_urlopen.return_value.__enter__.return_value = mock_response

        result = main.send_teams_notification(sample_notification)

        assert result['status'] == 'success'
        mock_urlopen.assert_called_once()

    def test_send_pagerduty_notification_skip_non_critical(self, sample_notification, mock_env, monkeypatch):
        """Test PagerDuty skips non-critical notifications"""
        monkeypatch.setenv('PAGERDUTY_API_KEY', 'test-key')
        monkeypatch.setenv('PAGERDUTY_ROUTING_KEY', 'test-routing-key')

        # Info severity should be skipped
        sample_notification['severity'] = 'info'
        result = main.send_pagerduty_notification(sample_notification)

        assert result['status'] == 'skipped'

    @patch('main.ses_client')
    def test_send_email_notification(self, mock_ses, sample_notification, mock_env):
        """Test email notification sending"""
        mock_ses.send_email.return_value = {'MessageId': 'email-test-id'}

        result = main.send_email_notification(sample_notification)

        assert result['status'] == 'success'
        assert result['messageId'] == 'email-test-id'
        mock_ses.send_email.assert_called_once()


class TestLambdaHandler:
    """Test the main Lambda handler"""

    @patch('main.send_notifications')
    def test_lambda_handler_success(self, mock_send, direct_invocation_event, mock_env):
        """Test successful Lambda execution"""
        mock_send.return_value = {'sns': {'status': 'success'}}

        context = Mock()
        result = main.lambda_handler(direct_invocation_event, context)

        assert result['statusCode'] == 200
        body = json.loads(result['body'])
        assert body['message'] == 'Notifications sent successfully'
        mock_send.assert_called_once()

    @patch('main.parse_notification')
    def test_lambda_handler_error(self, mock_parse, direct_invocation_event, mock_env):
        """Test Lambda error handling"""
        mock_parse.side_effect = Exception('Test error')

        context = Mock()
        result = main.lambda_handler(direct_invocation_event, context)

        assert result['statusCode'] == 500
        assert 'Error' in result['body']

    @patch('main.send_notifications')
    def test_lambda_handler_with_sns_event(self, mock_send, sns_event, mock_env):
        """Test Lambda with SNS event"""
        mock_send.return_value = {}

        context = Mock()
        result = main.lambda_handler(sns_event, context)

        assert result['statusCode'] == 200
        mock_send.assert_called_once()


class TestSSMIntegration:
    """Test SSM parameter retrieval"""

    @patch('main.ssm_client')
    def test_get_ssm_parameter_success(self, mock_ssm):
        """Test successful SSM parameter retrieval"""
        mock_ssm.get_parameter.return_value = {
            'Parameter': {'Value': 'secret-value'}
        }

        result = main.get_ssm_parameter('/test/parameter')

        assert result == 'secret-value'
        mock_ssm.get_parameter.assert_called_once_with(
            Name='/test/parameter',
            WithDecryption=True
        )

    @patch('main.ssm_client')
    def test_get_ssm_parameter_error(self, mock_ssm):
        """Test SSM parameter retrieval error"""
        mock_ssm.get_parameter.side_effect = Exception('Parameter not found')

        result = main.get_ssm_parameter('/test/parameter')

        assert result is None


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
