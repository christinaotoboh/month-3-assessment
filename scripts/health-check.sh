#!/bin/bash
set -e

echo "=== Health Check Script ==="

# Configuration
PROFILE="christi-project"
REGION="us-east-1"

# Get ALB DNS name from Terraform outputs
echo "Fetching ALB DNS name..."
cd "$(dirname "$0")/../../starttech-infra/terraform"
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
    echo "Error: Could not fetch ALB DNS name"
    echo "Checking local backend..."
    ALB_DNS="localhost:8080"
fi

echo "Checking backend health at: http://$ALB_DNS"

# Check backend health endpoint
echo ""
echo "Checking /health endpoint..."
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/health" || echo "000")

if [ "$HEALTH_RESPONSE" = "200" ]; then
    echo "✓ Health check passed (HTTP $HEALTH_RESPONSE)"
else
    echo "✗ Health check failed (HTTP $HEALTH_RESPONSE)"
    exit 1
fi

# Check Swagger documentation
echo ""
echo "Checking /swagger/index.html endpoint..."
SWAGGER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/swagger/index.html" || echo "000")

if [ "$SWAGGER_RESPONSE" = "200" ]; then
    echo "✓ Swagger documentation accessible (HTTP $SWAGGER_RESPONSE)"
else
    echo "⚠ Swagger documentation not accessible (HTTP $SWAGGER_RESPONSE)"
fi

# Check ALB target health
echo ""
echo "Checking ALB target health..."
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
    --names starttech-backend-tg \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text 2>/dev/null || echo "")

if [ -n "$TARGET_GROUP_ARN" ]; then
    HEALTHY_COUNT=$(aws elbv2 describe-target-health \
        --target-group-arn "$TARGET_GROUP_ARN" \
        --profile "$PROFILE" \
        --region "$REGION" \
        --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
        --output text)
    
    TOTAL_COUNT=$(aws elbv2 describe-target-health \
        --target-group-arn "$TARGET_GROUP_ARN" \
        --profile "$PROFILE" \
        --region "$REGION" \
        --query "length(TargetHealthDescriptions)" \
        --output text)
    
    echo "Healthy targets: $HEALTHY_COUNT / $TOTAL_COUNT"
    
    if [ "$HEALTHY_COUNT" -eq "0" ]; then
        echo "✗ No healthy targets!"
        exit 1
    else
        echo "✓ ALB has healthy targets"
    fi
else
    echo "⚠ Could not check ALB target health (infrastructure may not be deployed)"
fi

echo ""
echo "=== All Health Checks Passed ==="
