# MuchToDo - Full-Stack Application

A production-ready full-stack ToDo application with automated CI/CD pipeline deployed on AWS.

## 🏗️ Architecture

- **Frontend**: React + TypeScript + Vite → S3 + CloudFront (HTTPS)
- **Backend**: Golang REST API → EC2 + ALB + Auto Scaling
- **Proxy**: CloudFront configured as a reverse proxy for `/auth`, `/tasks`, `/users`, `/health` to ALB.
- **Database**: MongoDB (self-hosted on EC2 with EBS encryption)
- **Cache**: ElastiCache Redis
- **Infrastructure**: Terraform (see [starttech-infra](https://github.com/christinaotoboh/starttech-infra))

## 📁 Repository Structure

```
starttech-application/
├── .github/workflows/
│   ├── frontend-ci-cd.yml          # Frontend deployment flow
│   └── backend-ci-cd.yml           # Backend deployment flow
├── Client/                         # React frontend application
├── Server/MuchToDo/               # Golang backend API
│   └── Dockerfile                  # Multi-stage Docker build
├── scripts/
│   ├── deploy-frontend.sh          # Manual frontend deploy
│   ├── deploy-backend.sh           # Manual backend deploy
│   ├── health-check.sh             # Verification script
│   └── rollback.sh                 # Emergency rollback
├── README.md
```

## 🚀 Quick Start

### 🌐 Live Demo
- **Application URL**: [https://d2suwtb3fkg2xw.cloudfront.net](https://d2suwtb3fkg2xw.cloudfront.net)
- **API Health Check**: [https://d2suwtb3fkg2xw.cloudfront.net/health](https://d2suwtb3fkg2xw.cloudfront.net/health)
- **API Documentation (Swagger)**: [https://d2suwtb3fkg2xw.cloudfront.net/swagger/index.html](https://d2suwtb3fkg2xw.cloudfront.net/swagger/index.html)

### 📊 Current Infrastructure
| Resource | Value |
|----------|-------|
| **CloudFront Distribution** | `E8ECBBPFRLORX` |
| **CloudFront Domain** | `d2suwtb3fkg2xw.cloudfront.net` |
| **S3 Bucket** | `starttech-frontend-production` |
| **ECR Registry** | `423623832118.dkr.ecr.us-east-1.amazonaws.com` |
| **ECR Repository** | `starttech-backend` |
| **Region** | `us-east-1` |

### Prerequisites
- Node.js 20+
- Go 1.22+
- Docker
- AWS CLI (`christi-project` profile)
- Infrastructure deployed (see [starttech-infra](https://github.com/christinaotoboh/starttech-infra))

### Local Development

#### Frontend
```bash
cd frontend
npm install
npm run dev
# Access at http://localhost:5173
```

#### Backend
```bash
cd backend/MuchToDo
# Ensure MongoDB/Redis are running
make run
# Access at http://localhost:8080
```

## 🔄 CI/CD Pipeline

Both frontend and backend are deployed automatically via GitHub Actions on push to `feature/full-stack`.

### Deployment Status
- ✅ **Frontend CI/CD**: Automated deployment to S3 + CloudFront invalidation
- ✅ **Backend CI/CD**: Automated Docker build → ECR → EC2 deployment via SSM

### Required GitHub Secrets

**Secrets** (Sensitive credentials):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**Environment Variables** (Configured in workflows):
- `S3_BUCKET_NAME`: `starttech-frontend-production`
- `CLOUDFRONT_DISTRIBUTION_ID`: `E8ECBBPFRLORX`
- `CLOUDFRONT_DOMAIN_NAME`: `d2suwtb3fkg2xw.cloudfront.net`
- `ECR_REGISTRY`: `423623832118.dkr.ecr.us-east-1.amazonaws.com`
- `ECR_REPOSITORY`: `starttech-backend`

## 🧠 Implementation Details

### CloudFront Reverse Proxy Pattern
To strictly enforce HTTPS and avoid Mixed Content errors/CORS issues, the frontend does **not** call the ALB directly.
- **Frontend Config**: `VITE_API_BASE_URL` is hardcoded to `/` in the build pipeline.
- **Routing**: API requests (e.g., `/auth/login`) hit CloudFront, which forwards them to the ALB origin. Static assets hit S3.

### strict Go 1.22 Compatibility
The backend toolchain is pinned to **Go 1.22**.
- **Reason**: To solve dependency conflicts (specifically `gin-contrib/sse` and `testcontainers`) that were demanding newer, unstable Go toolchains, we explicitly pinned dependencies in `go.mod` to stable versions compatible with Go 1.22.
- **Linting**: `golangci-lint` is configured to respect this version constraint.

## 🛠️ Operations & Manual Deployment

### 1. Deploy Frontend
Updates the React app and invalidates cache.
```bash
cd scripts
./deploy-frontend.sh
```

### 2. Deploy Backend
Builds new Docker image, pushes to ECR, triggers ASG instance refresh.
```bash
cd scripts
./deploy-backend.sh
```

### 3. Health Checks
Verifies connectivity to Backend (Direct & Proxied via CloudFront) and Swagger docs.
```bash
cd scripts
./health-check.sh
```

### 4. Emergency Rollback
Reverts the backend to the previous ECR image on all active instances.
```bash
cd scripts
./rollback.sh
```

## 🔍 Monitoring & Troubleshooting

### dashboard
- **CloudWatch Dashboard**: `starttech-dashboard`
- **Log Group**: `/aws/ec2/starttech-backend`

### Common Issues

**Frontend 404s or Network Errors:**
- Verify CloudFront behaviors are routing `/api/*` or specific paths to the ALB origin.
- Ensure `VITE_API_BASE_URL` is set to `/` (relative) so requests go through the proxy.

**Backend Startup Failures:**
- Check logs: `aws logs tail /aws/ec2/starttech-backend --follow --profile christi-project`
- Verify `.env` file exists on EC2 at `/home/ec2-user/.env`.
- Ensure MongoDB is reachable from the backend security group.

**Scaling Issues:**
- Check Alarm `starttech-high-cpu`.
- Manually scale if needed:
  ```bash
  aws autoscaling set-desired-capacity --auto-scaling-group-name starttech-backend-asg --desired-capacity 2 --profile christi-project
  ```

## 🔒 Security
- **Strict HTTPS**: Frontend enforces HTTPS via CloudFront.
- **No Mixed Content**: Backend is proxied via CloudFront to present a unified HTTPS origin.
- **Vulnerability Scanning**: Trivy scans in CI pipeline.
- **Private Subnets**: Database and Redis are isolated from public internet.

