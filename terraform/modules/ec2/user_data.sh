#!/bin/bash
# ==================================
# EC2 Instance User Data Script
# ==================================

set -e

# Update system packages
dnf update -y

# Install CloudWatch Agent
dnf install -y amazon-cloudwatch-agent

# Install other useful tools
dnf install -y htop wget curl git unzip

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
${cloudwatch_config}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Install and configure web server (example application)
dnf install -y httpd

# Create a simple health check endpoint
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>${project_name} - ${environment}</title>
</head>
<body>
    <h1>${project_name}</h1>
    <p>Environment: ${environment}</p>
    <p>Instance ID: $(ec2-metadata --instance-id | cut -d " " -f 2)</p>
    <p>Availability Zone: $(ec2-metadata --availability-zone | cut -d " " -f 2)</p>
    <p>Status: <span style="color: green;">Healthy</span></p>
</body>
</html>
EOF

# Create health check endpoint
cat > /var/www/html/health <<EOF
OK
EOF

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Configure firewall (if needed)
systemctl stop firewalld
systemctl disable firewalld

# Log completion
echo "User data script completed successfully" > /var/log/user-data-completion.log
date >> /var/log/user-data-completion.log
