# System Architecture

## Overview

MuchToDo is a cloud-native full-stack application deployed on AWS with automated CI/CD pipelines.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
└────────────┬──────────────────────────────────┬─────────────────┘
             │                                   │
             │                                   │
    ┌────────▼────────┐                 ┌───────▼────────┐
    │   CloudFront    │                 │  Application   │
    │  (CDN + HTTPS)  │                 │ Load Balancer  │
    └────────┬────────┘                 └───────┬────────┘
             │                                   │
             │                                   │
    ┌────────▼────────┐                 ┌───────▼────────┐
    │   S3 Bucket     │                 │  Auto Scaling  │
    │  (React App)    │                 │     Group      │
    └─────────────────┘                 └───────┬────────┘
                                                 │
                                        ┌────────▼────────┐
                                        │  EC2 Instances  │
                                        │  (Golang API)   │
                                        └────┬────────┬───┘
                                             │        │
                              ┌──────────────┘        └──────────────┐
                              │                                       │
                     ┌────────▼────────┐                   ┌─────────▼────────┐
                     │    MongoDB      │                   │  ElastiCache     │
                     │   (EC2 hosted)  │                   │     Redis        │
                     └─────────────────┘                   └──────────────────┘
```

## Components

### Frontend (Client)
- **Technology**: React 18 + TypeScript + Vite
- **Hosting**: AWS S3 (static website hosting)
- **CDN**: AWS CloudFront
- **Features**:
  - User authentication (login/register)
  - Todo CRUD operations
  - Responsive UI with shadcn/ui components
  - TanStack Router for routing

### Backend (Server)
- **Technology**: Golang 1.21
- **Hosting**: EC2 instances behind ALB
- **Scaling**: Auto Scaling Group (1-3 instances)
- **Features**:
  - RESTful API
  - JWT authentication
  - MongoDB integration
  - Redis caching (optional)
  - Swagger documentation
  - Structured logging

### Database
- **Technology**: MongoDB 7.0
- **Hosting**: Self-hosted on EC2 (private subnet)
- **Features**:
  - Authentication enabled
  - Replica set configuration
  - Encrypted storage

### Cache
- **Technology**: Redis 7.0
- **Hosting**: AWS ElastiCache
- **Purpose**: Session storage and caching

### Infrastructure
- **IaC**: Terraform
- **Networking**: VPC with public/private subnets across 2 AZs
- **Security**: Security groups, IAM roles, private subnets
- **Monitoring**: CloudWatch Logs, Dashboards, Alarms

## Data Flow

### User Registration/Login
1. User submits credentials via React frontend
2. CloudFront serves static assets from S3
3. Frontend makes API call to ALB
4. ALB routes to healthy EC2 instance
5. Backend validates credentials against MongoDB
6. JWT token generated and returned
7. Token stored in httpOnly cookie

### Todo Operations
1. Authenticated user makes request
2. Backend validates JWT token
3. Check Redis cache for data (if enabled)
4. If cache miss, query MongoDB
5. Update cache with result
6. Return response to frontend

## Security Architecture

### Network Security
- Frontend in public S3 bucket (CloudFront OAI access only)
- Backend in private subnets (ALB in public subnets)
- MongoDB and Redis in private subnets
- Security groups restrict traffic to necessary ports

### Application Security
- JWT-based authentication
- Password hashing (bcrypt)
- HTTPS for frontend (CloudFront)
- Environment variables for secrets
- IAM roles for EC2 (no hardcoded credentials)

### CI/CD Security
- GitHub Secrets for sensitive data
- Docker image vulnerability scanning (Trivy)
- npm security audit
- Code quality checks (golangci-lint)

## Scalability

### Horizontal Scaling
- Auto Scaling Group scales EC2 instances based on CPU
- ALB distributes traffic across instances
- CloudFront caches static assets globally

### Vertical Scaling
- Instance types configurable via Terraform
- MongoDB can be upgraded to larger instance

## High Availability

- Multi-AZ deployment (2 availability zones)
- ALB health checks ensure traffic to healthy instances
- Auto Scaling replaces unhealthy instances
- CloudFront provides global availability

## Monitoring & Observability

### Metrics
- EC2 CPU, memory, network
- ALB request count, latency, errors
- ElastiCache CPU, connections
- Custom application metrics

### Logs
- Application logs → CloudWatch Logs
- Structured JSON logging
- Log Insights for querying

### Alarms
- High CPU utilization
- Unhealthy ALB targets
- 5XX errors
- Redis high CPU

## Disaster Recovery

### Backup Strategy
- MongoDB: Manual snapshots (EBS volumes)
- Application state: Stateless (can be recreated)
- Infrastructure: Terraform state in S3

### Recovery Procedures
1. Infrastructure: `terraform apply`
2. Application: Redeploy via CI/CD
3. Database: Restore from snapshot

## Cost Optimization

- t3.micro instances for backend (burstable)
- cache.t3.micro for Redis
- CloudFront free tier
- S3 lifecycle policies for old logs
- Auto Scaling reduces costs during low traffic

## Future Enhancements

- [ ] HTTPS for backend (ACM certificate + ALB listener)
- [ ] Multi-region deployment
- [ ] MongoDB Atlas migration
- [ ] Container orchestration (ECS/EKS)
- [ ] Blue-green deployments
- [ ] Automated backups
- [ ] WAF for DDoS protection
