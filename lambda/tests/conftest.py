"""
Shared pytest fixtures and configuration
"""

import pytest
import sys
import os
from unittest.mock import MagicMock

# Mock boto3 modules for testing
sys.modules['boto3'] = MagicMock()
sys.modules['botocore'] = MagicMock()


@pytest.fixture(autouse=True)
def reset_env(monkeypatch):
    """Reset environment variables before each test"""
    # Set default test environment variables
    test_env = {
        'AWS_DEFAULT_REGION': 'us-east-1',
        'AWS_REGION': 'us-east-1',
        'ENVIRONMENT': 'test',
        'PROJECT_NAME': 'test-project'
    }

    for key, value in test_env.items():
        monkeypatch.setenv(key, value)


@pytest.fixture
def lambda_context():
    """Mock Lambda context object"""
    context = MagicMock()
    context.function_name = 'test-function'
    context.function_version = '$LATEST'
    context.invoked_function_arn = 'arn:aws:lambda:us-east-1:123456789012:function:test-function'
    context.memory_limit_in_mb = 128
    context.aws_request_id = 'test-request-id'
    context.log_group_name = '/aws/lambda/test-function'
    context.log_stream_name = 'test-stream'

    return context
