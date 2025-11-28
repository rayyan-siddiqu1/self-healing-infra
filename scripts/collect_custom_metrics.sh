#!/bin/bash

# ==================================
# Custom Metrics Collection Script
# ==================================
# This script collects custom application metrics and publishes them to CloudWatch
#
# Usage: ./collect_custom_metrics.sh [OPTIONS]
# Options:
#   --environment ENV     Environment name (default: prod)
#   --namespace NS        CloudWatch namespace (default: SelfHealingInfra/Custom)
#   --interval SECONDS    Collection interval (default: 60)
#   --daemon              Run as daemon (continuous collection)
#
# Example:
#   ./collect_custom_metrics.sh --environment prod --daemon
#

set -e

# Configuration
ENVIRONMENT="${ENVIRONMENT:-prod}"
PROJECT_NAME="self-healing-infra"
NAMESPACE="${NAMESPACE:-SelfHealingInfra/Custom}"
REGION="${AWS_REGION:-us-east-1}"
INTERVAL=60
DAEMON_MODE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --daemon)
      DAEMON_MODE=true
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --environment ENV     Environment name (default: prod)"
      echo "  --namespace NS        CloudWatch namespace"
      echo "  --interval SECONDS    Collection interval (default: 60)"
      echo "  --daemon              Run as daemon"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Get instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id 2>/dev/null | cut -d " " -f 2 || echo "unknown")
AZ=$(ec2-metadata --availability-zone 2>/dev/null | cut -d " " -f 2 || echo "unknown")

echo -e "${GREEN}Starting custom metrics collection${NC}"
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo "Instance: $INSTANCE_ID"
echo "Region: $REGION"
echo ""

# Function to publish metric to CloudWatch
publish_metric() {
    local metric_name=$1
    local value=$2
    local unit=$3
    local dimensions=$4

    aws cloudwatch put-metric-data \
        --namespace "$NAMESPACE" \
        --metric-name "$metric_name" \
        --value "$value" \
        --unit "$unit" \
        --dimensions "$dimensions" \
        --region "$REGION" \
        2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Published: $metric_name = $value $unit"
    else
        echo -e "${RED}✗${NC} Failed: $metric_name"
    fi
}

# Function to collect system health score
collect_system_health() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

    # Calculate health score (0-100)
    # Lower is better: if all metrics are at 0%, health is 100
    # If all are at 100%, health is 0
    local health_score=$(awk "BEGIN {print 100 - (($cpu_usage + $mem_usage + $disk_usage) / 3)}")

    publish_metric "SystemHealth" "$health_score" "None" "Environment=$ENVIRONMENT,InstanceId=$INSTANCE_ID"
}

# Function to collect active sessions
collect_active_sessions() {
    # Count active SSH sessions
    local ssh_sessions=$(who | wc -l)

    # Count active HTTP connections (if Apache/Nginx is running)
    local http_connections=0
    if command -v netstat &> /dev/null; then
        http_connections=$(netstat -an | grep -c ":80.*ESTABLISHED" || echo 0)
    fi

    local total_sessions=$((ssh_sessions + http_connections))

    publish_metric "ActiveSessions" "$total_sessions" "Count" "Environment=$ENVIRONMENT,InstanceId=$INSTANCE_ID"
}

# Function to collect cache hit rate (example with Redis)
collect_cache_hit_rate() {
    if command -v redis-cli &> /dev/null; then
        local info=$(redis-cli info stats 2>/dev/null || echo "")

        if [ -n "$info" ]; then
            local hits=$(echo "$info" | grep keyspace_hits | cut -d: -f2 | tr -d '\r')
            local misses=$(echo "$info" | grep keyspace_misses | cut -d: -f2 | tr -d '\r')

            if [ -n "$hits" ] && [ -n "$misses" ]; then
                local total=$((hits + misses))
                if [ $total -gt 0 ]; then
                    local hit_rate=$(awk "BEGIN {printf \"%.2f\", ($hits / $total) * 100}")
                    publish_metric "CacheHitRate" "$hit_rate" "Percent" "Environment=$ENVIRONMENT,InstanceId=$INSTANCE_ID"
                fi
            fi
        fi
    fi
}

# Function to collect queue depth (example with RabbitMQ)
collect_queue_depth() {
    if command -v rabbitmqctl &> /dev/null; then
        local queue_depth=$(rabbitmqctl list_queues 2>/dev/null | awk '{sum+=$2} END {print sum}')
        if [ -n "$queue_depth" ]; then
            publish_metric "QueueDepth" "$queue_depth" "Count" "Environment=$ENVIRONMENT,InstanceId=$INSTANCE_ID"
        fi
    fi
}

# Function to collect database connections
collect_database_connections() {
    # PostgreSQL example
    if command -v psql &> /dev/null; then
        local db_connections=$(psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d ' ')
        if [ -n "$db_connections" ]; then
            publish_metric "DatabaseConnections" "$db_connections" "Count" "Environment=$ENVIRONMENT,Type=PostgreSQL,InstanceId=$INSTANCE_ID"
        fi
    fi

    # MySQL example
    if command -v mysql &> /dev/null; then
        local db_connections=$(mysql -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | awk 'NR==2 {print $2}')
        if [ -n "$db_connections" ]; then
            publish_metric "DatabaseConnections" "$db_connections" "Count" "Environment=$ENVIRONMENT,Type=MySQL,InstanceId=$INSTANCE_ID"
        fi
    fi
}

# Function to collect application response time
collect_application_response_time() {
    # Check if application is running on port 80
    if command -v curl &> /dev/null; then
        local start_time=$(date +%s%N)
        local http_code=$(curl -o /dev/null -s -w "%{http_code}" http://localhost/health 2>/dev/null || echo "000")
        local end_time=$(date +%s%N)

        if [ "$http_code" = "200" ]; then
            local response_time=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
            publish_metric "ApplicationResponseTime" "$response_time" "Milliseconds" "Environment=$ENVIRONMENT,InstanceId=$INSTANCE_ID"
        fi
    fi
}

# Function to collect disk I/O metrics
collect_disk_io() {
    if command -v iostat &> /dev/null; then
        local io_util=$(iostat -x 1 2 | awk '/^[a-z]/ {if (NR>3) print $14}' | tail -1)
        if [ -n "$io_util" ]; then
            publish_metric "DiskIOUtilization" "$io_util" "Percent" "Environment=$ENVIRONMENT,InstanceId=$INSTANCE_ID"
        fi
    fi
}

# Function to collect network metrics
collect_network_metrics() {
    if command -v iftop &> /dev/null; then
        # This is a simplified example - you'd need to parse iftop output properly
        local network_throughput=$(cat /proc/net/dev | grep eth0 | awk '{print $2}')
        if [ -n "$network_throughput" ]; then
            publish_metric "NetworkThroughput" "$network_throughput" "Bytes" "Environment=$ENVIRONMENT,InstanceId=$INSTANCE_ID,Direction=In"
        fi
    fi
}

# Main collection function
collect_all_metrics() {
    echo -e "\n${YELLOW}Collecting metrics at $(date)${NC}"

    collect_system_health
    collect_active_sessions
    collect_cache_hit_rate
    collect_queue_depth
    collect_database_connections
    collect_application_response_time
    collect_disk_io

    echo -e "${GREEN}Metrics collection completed${NC}\n"
}

# Main execution
if [ "$DAEMON_MODE" = true ]; then
    echo -e "${YELLOW}Running in daemon mode (interval: ${INTERVAL}s)${NC}"
    echo "Press Ctrl+C to stop"
    echo ""

    while true; do
        collect_all_metrics
        sleep "$INTERVAL"
    done
else
    # Single collection
    collect_all_metrics
fi
