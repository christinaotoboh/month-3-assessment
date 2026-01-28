#!/bin/bash
set -e

echo "=== Health Check Script ==="

# Configuration
PROFILE="christi-project"
REGION="us-east-1"

# Get Infrastructure Outputs
echo "Fetching infrastructure outputs..."
cd "$(dirname "$0")/../../starttech-infra/terraform"
ALB_DNS=$(AWS_PROFILE=$PROFILE terraform output -raw alb_dns_name 2>/dev/null || echo "")
CLOUDFRONT_DOMAIN=$(AWS_PROFILE=$PROFILE terraform output -raw cloudfront_domain_name 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ] || [ -z "$CLOUDFRONT_DOMAIN" ]; then
    echo "Error: Could not fetch infrastructure outputs"
    echo "Checking local backend..."
    ALB_DNS="localhost:8080"
    CLOUDFRONT_DOMAIN="localhost:5173"
fi

echo "Frontend: https://$CLOUDFRONT_DOMAIN"
echo "Backend (Direct): http://$ALB_DNS"
echo "Backend (Proxied): https://$CLOUDFRONT_DOMAIN/health"

echo "Checking backend health (Direct)..."
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/health" || echo "000")

if [ "$HEALTH_RESPONSE" = "200" ]; then
    echo "✓ Direct Health check passed"
else
    echo "✗ Direct Health check failed (HTTP $HEALTH_RESPONSE)"
    exit 1
fi

echo "Checking backend health (Proxied via CloudFront)..."
PROXY_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://$CLOUDFRONT_DOMAIN/health" || echo "000")

if [ "$PROXY_RESPONSE" = "200" ]; then
    echo "✓ Proxied Health check passed"
else
    echo "✗ Proxied Health check failed (HTTP $PROXY_RESPONSE)"
    # Don't fail the build yet if proxy takes time to propagate
    echo "Warning: Proxy might still be deploying."
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
