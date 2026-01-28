#!/bin/bash
set -e

echo "=== Frontend Deployment Script ==="

# Configuration
PROFILE="christi-project"
REGION="us-east-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$SCRIPT_DIR/../frontend"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed"
    exit 1
fi

# Get S3 bucket name and CloudFront distribution ID from Terraform outputs
echo "Fetching infrastructure outputs..."
pushd "$SCRIPT_DIR/../../starttech-infra/terraform" > /dev/null
S3_BUCKET=$(AWS_PROFILE=$PROFILE terraform output -raw s3_bucket_name 2>/dev/null || echo "")
CLOUDFRONT_ID=$(AWS_PROFILE=$PROFILE terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
ALB_DNS=$(AWS_PROFILE=$PROFILE terraform output -raw alb_dns_name 2>/dev/null || echo "")
popd > /dev/null

if [ -z "$S3_BUCKET" ] || [ -z "$CLOUDFRONT_ID" ] || [ -z "$ALB_DNS" ]; then
    echo "Error: Could not fetch infrastructure outputs"
    echo "Please ensure infrastructure is deployed first"
    exit 1
fi

echo "S3 Bucket: $S3_BUCKET"
echo "CloudFront Distribution: $CLOUDFRONT_ID"

# Navigate to Client directory
cd "$CLIENT_DIR"

# Install dependencies
echo ""
echo "Installing dependencies..."
npm ci --fetch-retries 5 --fetch-retry-factor 2 --fetch-retry-mintimeout 20000 --fetch-retry-maxtimeout 120000

# Build the application
# Since CloudFront proxies /auth, /tasks, /users, /health, /swagger to the backend
# We can now use a relative path (or the CloudFront domain itself)
# Ideally relative path "/" works if the app handles it.
# However, Vite needs VITE_API_BASE_URL. If we set it to "", fetch("/auth/login") works.
echo ""
echo "Building application..."
export VITE_API_BASE_URL="/"
echo "Using Backend API: Relative Path (Proxied via CloudFront)"
npm run build

# Sync to S3
echo ""
echo "Syncing files to S3..."
aws s3 sync dist/ "s3://$S3_BUCKET" \
    --delete \
    --cache-control max-age=31536000,public \
    --profile "$PROFILE" \
    --region "$REGION"

# Invalidate CloudFront cache
echo ""
echo "Invalidating CloudFront cache..."
INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$CLOUDFRONT_ID" \
    --paths "/*" \
    --profile "$PROFILE" \
    --query 'Invalidation.Id' \
    --output text)

echo "Invalidation ID: $INVALIDATION_ID"

# Get CloudFront domain
CLOUDFRONT_DOMAIN=$(aws cloudfront get-distribution \
    --id "$CLOUDFRONT_ID" \
    --profile "$PROFILE" \
    --query 'Distribution.DomainName' \
    --output text)

echo ""
echo "=== Deployment Complete ==="
echo "Frontend URL: https://$CLOUDFRONT_DOMAIN"
