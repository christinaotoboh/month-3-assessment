#!/bin/bash
set -e

echo "=== Rollback Script ==="

# Configuration
PROFILE="christi-project"
REGION="us-east-1"
ECR_REPOSITORY="starttech-backend"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# Get previous image tag
echo "Fetching previous image tags from ECR..."
PREVIOUS_TAG=$(aws ecr describe-images \
    --repository-name "$ECR_REPOSITORY" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'sort_by(imageDetails,& imagePushedAt)[-2].imageTags[0]' \
    --output text)

if [ -z "$PREVIOUS_TAG" ] || [ "$PREVIOUS_TAG" = "None" ]; then
    echo "Error: No previous image found for rollback"
    exit 1
fi

echo "Rolling back to image: $ECR_REGISTRY/$ECR_REPOSITORY:$PREVIOUS_TAG"

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

# Rollback on each instance
for INSTANCE_ID in $INSTANCE_IDS; do
    echo ""
    echo "Rolling back on instance: $INSTANCE_ID"
    
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[
            '#!/bin/bash',
            'set -e',
            'echo \"Logging into ECR...\"',
            'aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY',
            'echo \"Pulling previous image...\"',
            'docker pull $ECR_REGISTRY/$ECR_REPOSITORY:$PREVIOUS_TAG',
            'echo \"Stopping current container...\"',
            'docker stop backend || true',
            'docker rm backend || true',
            'echo \"Starting previous version...\"',
            'docker run -d --name backend --restart unless-stopped -p 8080:8080 --env-file /home/ec2-user/.env --log-driver=awslogs --log-opt awslogs-group=/aws/ec2/starttech-backend --log-opt awslogs-stream=\$(ec2-metadata --instance-id | cut -d \" \" -f 2) $ECR_REGISTRY/$ECR_REPOSITORY:$PREVIOUS_TAG',
            'echo \"Waiting for health check...\"',
            'sleep 10',
            'curl -f http://localhost:8080/health || exit 1',
            'echo \"Rollback successful!\"'
        ]" \
        --profile "$PROFILE" \
        --region "$REGION" \
        --query 'Command.CommandId' \
        --output text)
    
    echo "Command ID: $COMMAND_ID"
    
    # Wait for command to complete
    echo "Waiting for rollback to complete..."
    aws ssm wait command-executed \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --profile "$PROFILE" \
        --region "$REGION"
    
    echo "✓ Rolled back on $INSTANCE_ID"
done

# Verify rollback
echo ""
echo "Verifying rollback..."
sleep 30

TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
    --names starttech-backend-tg \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)

HEALTHY_COUNT=$(aws elbv2 describe-target-health \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
    --output text)

if [ "$HEALTHY_COUNT" -eq "0" ]; then
    echo "✗ Rollback verification failed - no healthy targets!"
    exit 1
fi

echo ""
echo "=== Rollback Complete ==="
echo "Rolled back to: $ECR_REGISTRY/$ECR_REPOSITORY:$PREVIOUS_TAG"
echo "Healthy targets: $HEALTHY_COUNT"
