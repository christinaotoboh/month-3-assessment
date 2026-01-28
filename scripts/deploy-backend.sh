#!/bin/bash
set -e

echo "=== Backend Deployment Script ==="

# Configuration
PROFILE="christi-project"
REGION="us-east-1"
ECR_REPOSITORY="starttech-backend"
SERVER_DIR="$(dirname "$0")/../Server/MuchToDo"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

echo "ECR Registry: $ECR_REGISTRY"

# Create ECR repository if it doesn't exist
echo ""
echo "Checking ECR repository..."
aws ecr describe-repositories --repository-names "$ECR_REPOSITORY" --profile "$PROFILE" --region "$REGION" 2>/dev/null || \
    aws ecr create-repository --repository-name "$ECR_REPOSITORY" --profile "$PROFILE" --region "$REGION"

# Login to ECR
echo ""
echo "Logging into ECR..."
aws ecr get-login-password --profile "$PROFILE" --region "$REGION" | \
    docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Navigate to Server directory
cd "$SERVER_DIR"

# Build Docker image
echo ""
echo "Building Docker image..."
IMAGE_TAG="$ECR_REGISTRY/$ECR_REPOSITORY:$(git rev-parse --short HEAD)"
IMAGE_LATEST="$ECR_REGISTRY/$ECR_REPOSITORY:latest"

docker build -t "$IMAGE_TAG" -t "$IMAGE_LATEST" .

# Push to ECR
echo ""
echo "Pushing image to ECR..."
docker push "$IMAGE_TAG"
docker push "$IMAGE_LATEST"

# Get EC2 instance IDs
echo ""
echo "Getting EC2 instance IDs..."
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=starttech-backend" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text \
    --profile "$PROFILE" \
    --region "$REGION")

if [ -z "$INSTANCE_IDS" ]; then
    echo "Error: No running EC2 instances found"
    exit 1
fi

echo "Found instances: $INSTANCE_IDS"

# Deploy to each instance
for INSTANCE_ID in $INSTANCE_IDS; do
    echo ""
    echo "Deploying to instance: $INSTANCE_ID"
    
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[
            '#!/bin/bash',
            'set -e',
            'echo \"Logging into ECR...\"',
            'aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY',
            'echo \"Pulling new image...\"',
            'docker pull $IMAGE_TAG',
            'echo \"Stopping old container...\"',
            'docker stop backend || true',
            'docker rm backend || true',
            'echo \"Starting new container...\"',
            'docker run -d --name backend --restart unless-stopped -p 8080:8080 --env-file /home/ec2-user/.env --log-driver=awslogs --log-opt awslogs-group=/aws/ec2/starttech-backend --log-opt awslogs-stream=\$(ec2-metadata --instance-id | cut -d \" \" -f 2) $IMAGE_TAG',
            'echo \"Waiting for health check...\"',
            'sleep 10',
            'curl -f http://localhost:8080/health || exit 1',
            'echo \"Deployment successful!\"'
        ]" \
        --profile "$PROFILE" \
        --region "$REGION" \
        --query 'Command.CommandId' \
        --output text)
    
    echo "Command ID: $COMMAND_ID"
    
    # Wait for command to complete
    echo "Waiting for deployment to complete..."
    aws ssm wait command-executed \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --profile "$PROFILE" \
        --region "$REGION"
    
    echo "✓ Deployed to $INSTANCE_ID"
done

echo ""
echo "=== Deployment Complete ==="
echo "Image: $IMAGE_TAG"
