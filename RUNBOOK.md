# Operations Runbook

## Common Operations

### Deploying New Version

#### Frontend
```bash
cd scripts
./deploy-frontend.sh
```

**What it does**:
1. Builds React application
2. Syncs to S3
3. Invalidates CloudFront cache

**Verification**:
- Visit CloudFront URL
- Check browser console for errors
- Verify API calls work

#### Backend
```bash
cd scripts
./deploy-backend.sh
```

**What it does**:
1. Builds Docker image
2. Pushes to ECR
3. Deploys to all EC2 instances via SSM
4. Runs health checks

**Verification**:
```bash
./health-check.sh
```

### Health Checks

```bash
cd scripts
./health-check.sh
```

**Checks**:
- Backend /health endpoint
- Swagger documentation
- ALB target health

### Rollback

```bash
cd scripts
./rollback.sh
```

**What it does**:
1. Finds previous Docker image in ECR
2. Deploys to all EC2 instances
3. Verifies health checks

## Troubleshooting

### Frontend Issues

#### Issue: CloudFront shows old version
**Solution**:
```bash
# Manually invalidate CloudFront
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*" \
  --profile christi-project
```

#### Issue: API calls failing (CORS)
**Check**:
1. Verify `VITE_API_BASE_URL` in `.env.production`
2. Check ALB security group allows traffic
3. Verify backend CORS configuration

### Backend Issues

#### Issue: Container not starting
**Debug**:
```bash
# SSH to EC2 instance
aws ssm start-session --target <INSTANCE_ID> --profile christi-project

# Check Docker logs
docker logs backend

# Check container status
docker ps -a
```

**Common causes**:
- Missing environment variables in `/home/ec2-user/.env`
- MongoDB connection failed
- Port 8080 already in use

#### Issue: Health checks failing
**Debug**:
```bash
# Check health endpoint locally on EC2
curl http://localhost:8080/health

# Check application logs
docker logs backend --tail 100

# Check CloudWatch logs
aws logs tail /aws/ec2/starttech-backend --follow --profile christi-project
```

#### Issue: High CPU usage
**Solution**:
1. Check CloudWatch metrics
2. Verify Auto Scaling is working
3. Consider scaling up instance type

```bash
# Check current instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=starttech-backend" \
  --profile christi-project
```

### Database Issues

#### Issue: MongoDB connection timeout
**Debug**:
```bash
# SSH to backend EC2 instance
aws ssm start-session --target <INSTANCE_ID> --profile christi-project

# Test MongoDB connection
nc -zv <MONGODB_PRIVATE_IP> 27017

# Check MongoDB logs on MongoDB instance
aws ssm start-session --target <MONGODB_INSTANCE_ID> --profile christi-project
sudo journalctl -u mongod -f
```

**Common causes**:
- Security group not allowing traffic
- MongoDB service not running
- Incorrect credentials

#### Issue: MongoDB disk full
**Solution**:
```bash
# Check disk usage
df -h

# Clean up old logs
sudo journalctl --vacuum-time=7d

# Resize EBS volume (requires restart)
```

### Redis Issues

#### Issue: Redis connection failed
**Debug**:
```bash
# Check ElastiCache cluster status
aws elasticache describe-cache-clusters \
  --cache-cluster-id starttech-redis \
  --profile christi-project

# Test connection from EC2
redis-cli -h <REDIS_ENDPOINT> ping
```

### ALB Issues

#### Issue: All targets unhealthy
**Debug**:
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --profile christi-project

# Check health check configuration
aws elbv2 describe-target-groups \
  --names starttech-backend-tg \
  --profile christi-project
```

**Common causes**:
- Backend not listening on port 8080
- /health endpoint not responding
- Security group blocking ALB → EC2 traffic

### CI/CD Issues

#### Issue: GitHub Actions workflow failing
**Debug**:
1. Check workflow logs in GitHub Actions tab
2. Verify GitHub Secrets are set correctly
3. Check AWS credentials are valid

**Common failures**:
- `AWS_ACCESS_KEY_ID` expired
- ECR repository doesn't exist
- S3 bucket permissions

#### Issue: Docker build failing
**Debug**:
```bash
# Build locally to see error
cd Server/MuchToDo
docker build -t test .
```

## Monitoring

### CloudWatch Dashboards

Access: `AWS Console → CloudWatch → Dashboards → starttech-dashboard`

**Metrics to watch**:
- ALB request count and latency
- EC2 CPU utilization
- Target health count
- ElastiCache CPU and connections

### CloudWatch Alarms

**Active alarms**:
- `starttech-high-cpu`: CPU > 70%
- `starttech-unhealthy-targets`: Unhealthy count > 0
- `starttech-alb-5xx-errors`: 5XX errors > 10 in 5 min
- `starttech-redis-high-cpu`: Redis CPU > 75%

### Log Analysis

```bash
# View recent logs
aws logs tail /aws/ec2/starttech-backend --follow --profile christi-project

# Search for errors
aws logs filter-log-events \
  --log-group-name /aws/ec2/starttech-backend \
  --filter-pattern "ERROR" \
  --profile christi-project
```

**Common log queries** (CloudWatch Logs Insights):
See `monitoring/log-insights-queries.txt` in infrastructure repo

## Maintenance

### Updating Dependencies

#### Frontend
```bash
cd Client
npm update
npm audit fix
npm run build  # Test build
```

#### Backend
```bash
cd Server/MuchToDo
go get -u ./...
go mod tidy
make test  # Run tests
```

### Scaling Operations

#### Manual scaling
```bash
# Update desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name starttech-backend-asg \
  --desired-capacity 3 \
  --profile christi-project
```

#### Update scaling policies
Edit `terraform/terraform.tfvars`:
```hcl
asg_min_size = 2
asg_max_size = 5
asg_desired_capacity = 3
```

Then apply:
```bash
cd ../starttech-infra/terraform
terraform apply
```

### Backup Procedures

#### MongoDB Backup
```bash
# Create EBS snapshot
aws ec2 create-snapshot \
  --volume-id <VOLUME_ID> \
  --description "MongoDB backup $(date +%Y-%m-%d)" \
  --profile christi-project
```

#### Application State
Application is stateless - can be recreated from code

## Emergency Procedures

### Complete Outage

1. **Check AWS Service Health**
   - Visit AWS Service Health Dashboard

2. **Verify Infrastructure**
   ```bash
   cd ../starttech-infra/terraform
   terraform plan
   ```

3. **Check EC2 Instances**
   ```bash
   aws ec2 describe-instance-status --profile christi-project
   ```

4. **Restart Services**
   ```bash
   # Restart backend containers
   ./scripts/deploy-backend.sh
   ```

### Data Loss

1. **Stop all writes**
2. **Restore from latest snapshot**
3. **Verify data integrity**
4. **Resume operations**

## Contacts

- **DevOps Team**: devops@starttech.com
- **On-call**: +1-XXX-XXX-XXXX
- **AWS Support**: Enterprise support plan

## Useful Commands

```bash
# Get infrastructure outputs
cd ../starttech-infra/terraform && terraform output

# List all EC2 instances
aws ec2 describe-instances --profile christi-project

# Get ALB DNS
aws elbv2 describe-load-balancers --names starttech-backend-alb --profile christi-project

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names starttech-backend-asg --profile christi-project

# View CloudWatch metrics
aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --profile christi-project
```
