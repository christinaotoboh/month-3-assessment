#!/bin/bash
# Configure backend EC2 instance environment

INSTANCE_ID=$1

if [ -z "$INSTANCE_ID" ]; then
    echo "Usage: $0 <instance-id>"
    exit 1
fi

echo "Configuring instance: $INSTANCE_ID"

# Create .env file content
ENV_CONTENT='PORT=8080
MONGO_URI=mongodb://admin:StartTech2024SecurePassword!@10.0.2.19:27017
DB_NAME=much_todo_db
ENABLE_CACHE=true
REDIS_ADDR=starttech-redis.jlvbpx.0001.use1.cache.amazonaws.com:6379
JWT_SECRET_KEY=StartTech2024SuperSecureJWTKey!RandomString123456789
JWT_EXPIRATION_HOURS=72
ALLOWED_ORIGINS=https://d2suwtb3fkg2xw.cloudfront.net
COOKIE_DOMAINS=d2suwtb3fkg2xw.cloudfront.net
SECURE_COOKIE=false
LOG_LEVEL=INFO
LOG_FORMAT=json'

# Send command to create .env file
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    'cat > /home/ec2-user/.env <<EOF',
    '$ENV_CONTENT',
    'EOF',
    'chmod 600 /home/ec2-user/.env',
    'chown ec2-user:ec2-user /home/ec2-user/.env',
    'echo \".env file created successfully\"'
  ]" \
  --profile christi-project \
  --region us-east-1 \
  --output text

echo "Configuration command sent to $INSTANCE_ID"
