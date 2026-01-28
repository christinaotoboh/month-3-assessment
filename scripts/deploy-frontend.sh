#!/bin/bash
set -e

echo "=== Frontend Deployment Script ==="

# Configuration
PROFILE="christi-project"
REGION="us-east-1"
CLIENT_DIR="$(dirname "$0")/../frontend"

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
cd "$(dirname "$0")/../../starttech-infra/terraform"
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")

if [ -z "$S3_BUCKET" ] || [ -z "$CLOUDFRONT_ID" ]; then
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
npm ci

# Build the application
echo ""
echo "Building application..."
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
