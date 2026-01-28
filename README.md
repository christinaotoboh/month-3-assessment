# MuchToDo - Full-Stack Application

A production-ready full-stack ToDo application with automated CI/CD pipeline deployed on AWS.

## 🏗️ Architecture

- **Frontend**: React + TypeScript + Vite → S3 + CloudFront
- **Backend**: Golang REST API → EC2 + ALB + Auto Scaling
- **Database**: MongoDB (self-hosted on EC2)
- **Cache**: ElastiCache Redis
- **Infrastructure**: Terraform (see [starttech-infra](https://github.com/christinaotoboh/starttech-infra))

## 📁 Repository Structure

```
month-3-assessment/
├── .github/workflows/
│   ├── frontend-ci-cd.yml          # Frontend deployment pipeline
│   └── backend-ci-cd.yml           # Backend deployment pipeline
├── Client/                         # React frontend application
├── Server/MuchToDo/               # Golang backend API
│   └── Dockerfile                  # Multi-stage Docker build
├── scripts/
│   ├── deploy-frontend.sh          # Frontend deployment script
│   ├── deploy-backend.sh           # Backend deployment script
│   ├── health-check.sh             # Health verification script
│   └── rollback.sh                 # Rollback to previous version
├── README.md
├── ARCHITECTURE.md
└── RUNBOOK.md
```

## 🚀 Quick Start

### Prerequisites

- Node.js 20+
- Go 1.21+
- Docker
- AWS CLI configured with `christi-project` profile
- Infrastructure deployed (see [starttech-infra](https://github.com/christinaotoboh/starttech-infra))

### Local Development

#### Frontend
```bash
cd Client
npm install
npm run dev
# Access at http://localhost:5173
```

#### Backend
```bash
cd Server/MuchToDo
cp .env.example .env
# Edit .env with your MongoDB and Redis connection details
docker-compose up -d  # Start MongoDB and Redis
make run
# Access at http://localhost:8080
# Swagger docs at http://localhost:8080/swagger/index.html
```

## 🔄 CI/CD Pipeline

### Automated Deployments

Both frontend and backend are automatically deployed when changes are pushed to the `feature/full-stack` branch.

**Frontend Pipeline**:
1. Install dependencies
2. Run security audit
3. Build production bundle
4. Sync to S3
5. Invalidate CloudFront cache

**Backend Pipeline**:
1. Run unit tests
2. Run code quality checks (golangci-lint)
3. Build Docker image
4. Scan image for vulnerabilities (Trivy)
5. Push to Amazon ECR
6. Deploy to EC2 instances via SSM
7. Verify health checks

### Required GitHub Secrets

Add these to repository settings (Settings → Secrets and variables → Actions):

```
AWS_ACCESS_KEY_ID              # AWS access key
AWS_SECRET_ACCESS_KEY          # AWS secret key
API_BASE_URL                   # ALB DNS name (e.g., http://starttech-backend-alb-123.us-east-1.elb.amazonaws.com)
S3_BUCKET_NAME                 # Frontend S3 bucket name
CLOUDFRONT_DISTRIBUTION_ID     # CloudFront distribution ID
CLOUDFRONT_DOMAIN_NAME         # CloudFront domain name
ECR_REGISTRY                   # ECR registry URL (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com)
```

### Manual Deployment

#### Deploy Frontend
```bash
cd scripts
./deploy-frontend.sh
```

#### Deploy Backend
```bash
cd scripts
./deploy-backend.sh
```

#### Health Check
```bash
cd scripts
./health-check.sh
```

#### Rollback
```bash
cd scripts
./rollback.sh
```

## 📊 Monitoring

### CloudWatch Logs
```
AWS Console → CloudWatch → Log groups → /aws/ec2/starttech-backend
```

### CloudWatch Dashboard
```
AWS Console → CloudWatch → Dashboards → starttech-dashboard
```

### Application URLs

After deployment, access the application at:
- **Frontend**: `https://<cloudfront-domain-name>`
- **Backend API**: `http://<alb-dns-name>`
- **Swagger Docs**: `http://<alb-dns-name>/swagger/index.html`

Get these URLs from Terraform outputs:
```bash
cd ../starttech-infra/terraform
terraform output
```

## 🔒 Security Features

- ✅ Docker image vulnerability scanning (Trivy)
- ✅ npm security audit
- ✅ Code quality checks (golangci-lint)
- ✅ IAM roles with least-privilege access
- ✅ Security groups restricting traffic
- ✅ Secrets managed via GitHub Secrets
- ✅ HTTPS for frontend (CloudFront)
- ✅ MongoDB and Redis in private subnets

## 🛠️ Development Workflow

1. **Create feature branch**
   ```bash
   git checkout -b feature/your-feature
   ```

2. **Make changes and test locally**

3. **Commit and push**
   ```bash
   git add .
   git commit -m "feat: your feature description"
   git push origin feature/your-feature
   ```

4. **Merge to feature/full-stack** to trigger deployment

## 📚 API Documentation

Interactive API documentation is available at:
```
http://<alb-dns-name>/swagger/index.html
```

### Key Endpoints

- `GET /health` - Health check
- `POST /api/v1/users/register` - User registration
- `POST /api/v1/users/login` - User login
- `GET /api/v1/todos` - List todos
- `POST /api/v1/todos` - Create todo
- `PUT /api/v1/todos/:id` - Update todo
- `DELETE /api/v1/todos/:id` - Delete todo

## 🧪 Testing

### Frontend Tests
```bash
cd Client
npm test
```

### Backend Tests
```bash
cd Server/MuchToDo
make unit-test
make integration-test
```

## 📖 Additional Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)**: Detailed system architecture
- **[RUNBOOK.md](RUNBOOK.md)**: Operations and troubleshooting guide
- **[Infrastructure Repo](https://github.com/christinaotoboh/starttech-infra)**: Terraform infrastructure code

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally
5. Submit a pull request

## 📝 License

This project is part of the StartTech Month 3 Assessment.

## 📧 Support

For issues or questions, please create an issue in this repository.

---

**Built with ❤️ for StartTech DevOps Assessment**
