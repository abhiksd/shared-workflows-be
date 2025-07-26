# Java Backend1

A Spring Boot microservice for Java Backend1 functionality.

## 🚀 Quick Start

### Local Development
```bash
# Build and run
mvn clean spring-boot:run

# Run with specific profile
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# Or with Docker
docker build -t java-backend1 .
docker run -p 8080:8080 java-backend1
```

### API Endpoints
- **Base URL**: `http://localhost:8080/api`
- **Health Check**: `/actuator/health`
- **Metrics**: `/actuator/prometheus`
- **Info**: `/actuator/info`

## 🏗️ Architecture

- **Framework**: Spring Boot 3.x
- **Java Version**: 21
- **Build Tool**: Maven
- **Database**: PostgreSQL (configurable)
- **Caching**: Redis
- **Monitoring**: Prometheus + Grafana
- **Deployment**: Kubernetes with Helm

## 🔧 Configuration

### Spring Boot Profiles
- **local**: Local development with H2 database
- **dev**: Development environment with PostgreSQL
- **staging**: Staging environment with full monitoring
- **production**: Production environment with all features

### Environment Variables
| Variable | Description | Default | Source |
|----------|-------------|---------|--------|
| `DB_HOST` | Database host | localhost | ConfigMap |
| `DB_PORT` | Database port | 5432 | ConfigMap |
| `DB_NAME` | Database name | java_backend1_dev | ConfigMap |
| `DB_USERNAME` | Database username | app_user | ConfigMap |
| `DB_PASSWORD` | Database password | (required) | Kubernetes Secret |
| `REDIS_HOST` | Redis host | localhost | ConfigMap |
| `REDIS_PORT` | Redis port | 6379 | ConfigMap |
| `REDIS_PASSWORD` | Redis password | (required) | Kubernetes Secret |
| `JWT_SECRET` | JWT signing secret | (required) | Kubernetes Secret |
| `API_KEY` | External API key | (required) | Kubernetes Secret |

## 🚀 Deployment

This service uses shared GitHub Actions workflows from the `no-keyvault-shared-github-actions` branch with Spring Boot profile-based configuration management.

### Manual Deployment
```bash
# Deploy to development
gh workflow run deploy.yml -f environment=dev

# Deploy to staging  
gh workflow run deploy.yml -f environment=staging

# Deploy to production
gh workflow run deploy.yml -f environment=production
```

### Automatic Deployment
- **Dev**: Triggered on push to this branch
- **Staging**: Triggered on push to `release/*` branches
- **Production**: Triggered on push to `main` branch

## 📊 Monitoring & Observability

### Health Checks
- **Liveness**: `/actuator/health/liveness`
- **Readiness**: `/actuator/health/readiness`
- **Custom Health**: Application-specific indicators

### Metrics
- **Prometheus**: `/actuator/prometheus`
- **JVM Metrics**: Memory, GC, threads
- **HTTP Metrics**: Request duration, response codes
- **Custom Metrics**: Business-specific metrics

### Logging
- **Format**: JSON structured logging
- **Levels**: Configurable per environment
- **Correlation**: Request tracing with correlation IDs

## 🛠️ Development

### Prerequisites
- Java 21+
- Maven 3.6+
- Docker & Docker Compose
- PostgreSQL (for local dev)

### Setup
```bash
# Clone and switch to app branch
git clone <repository-url>
git checkout my-java-app

# Install dependencies
mvn clean install

# Run tests
mvn test

# Run with development profile
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

### Testing
```bash
# Unit tests
mvn test

# Integration tests
mvn verify

# Test with specific profile
mvn test -Dspring.profiles.active=dev
```

### Docker Development
```bash
# Build image
docker build -t java-backend1:latest .

# Run with docker-compose (if available)
docker-compose up -d

# Run standalone
docker run -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=dev \
  -e DB_HOST=host.docker.internal \
  java-backend1:latest
```

## 🚀 **Deployment & Branch Strategy**

### Branch-Based Deployment Rules

| Environment | Auto-Deploy Trigger | Manual Deploy Rules |
|-------------|-------------------|-------------------|
| **DEV** | Push to `dev`, `develop` | Override required for other branches |
| **SQE** | Push to `sqe` | Override required for other branches |
| **PPR** | Push to `release/*` | Override required for other branches |
| **PROD** | Push tags (e.g., `v1.0.0`) | Override required for other branches |

### Manual Deployment Commands

#### **Standard Deployment (From Correct Branch)**
```bash
# Deploy to DEV from dev branch
gh workflow run deploy.yml -f environment=dev

# Deploy to PROD from tag
git tag v1.0.0 && git push origin v1.0.0
```

#### **Override Deployment (From Any Branch)**
```bash
# Deploy to DEV from feature branch (requires override)
gh workflow run deploy.yml \
  -f environment=dev \
  -f override_branch_validation=true \
  -f deploy_notes="Testing feature branch deployment"

# Emergency PROD deployment (requires override + notes)
gh workflow run deploy.yml \
  -f environment=prod \
  -f override_branch_validation=true \
  -f deploy_notes="Critical hotfix - approved by incident commander"
```

#### **Override Usage Guidelines**
- ✅ **Emergency hotfixes** and critical patches
- ✅ **Feature branch testing** in lower environments
- ✅ **Rollback scenarios** requiring specific commits
- ❌ **Regular development** should use proper branches
- 📝 **All override usage** is logged with user attribution

> **📚 For complete override documentation, see:** `OVERRIDE_BRANCH_VALIDATION_GUIDE.md`

## 🔗 Branch Structure

This repository uses a branch-based approach:

- **`no-keyvault-shared-github-actions`**: Shared CI/CD workflows with Spring Boot profile-based configuration
- **`no-keyvault-my-app`**: This Spring Boot application (current branch)
- **Environment Branches**: Each environment has a dedicated branch:
  - `dev`: Development environment
  - `sqe`: System Quality Engineering environment
  - `ppr`: Pre-Production environment
- **`main`**: Main branch (not used for automatic deployment)
- **Tags**: Production releases

### Workflow Integration

The deployment workflow references shared workflows:

```yaml
uses: ./.github/workflows/shared-deploy.yml@no-keyvault-shared-github-actions
```

## 🔐 Configuration & Secrets Management

### Spring Boot Profile-Based Configuration
This application uses Spring Boot profiles for environment-specific configuration:
- **Local**: H2 in-memory database, simple caching, debug logging
- **Dev**: PostgreSQL, Redis, development-friendly settings  
- **SQE**: System Quality Engineering - production-like settings with enhanced monitoring
- **PPR**: Pre-Production - final validation environment before production
- **Production**: Full security, performance optimization, minimal logging

### Secret Management Strategy
- **Kubernetes Secrets**: Sensitive data (passwords, API keys, JWT secrets)
- **ConfigMaps**: Non-sensitive configuration (URLs, ports, feature flags)
- **Spring Profiles**: Environment-specific behavior and settings

### Automatic Deployment Strategy
The deployment workflow provides automatic deployment with environment-specific branches for lower environments:
- **Dev**: Automatic deployment from `dev` branch (also supports `develop` for legacy)
- **SQE**: Automatic deployment from `sqe` branch  
- **PPR**: Automatic deployment from `release/**` branches (existing logic preserved)
- **Production**: Automatic deployment from **tags** (existing tagging logic preserved)

**Branch-Environment Mapping**: 
- **Lower environments** (dev, sqe): Use dedicated branches matching environment names
- **Upper environments** (ppr, prod): Keep existing patterns (release/**, tags)
- **Future environments**: Can be easily added by creating branch with same name as environment

### Required Deployment Secrets
The deployment workflow requires these secrets:
- `ACR_LOGIN_SERVER` - Azure Container Registry
- `AZURE_TENANT_ID` - Azure tenant  
- `AZURE_CLIENT_ID` - Azure service principal
- `AZURE_SUBSCRIPTION_ID` - Azure subscription

### Application Secrets (Kubernetes)
- `DB_PASSWORD` - Database password
- `REDIS_PASSWORD` - Redis password
- `JWT_SECRET` - JWT signing secret  
- `API_KEY` - External service API key

## 📚 Documentation

- [Deployment Guide](./DEPLOYMENT.md) - Comprehensive deployment instructions
- [Shared Workflows](../../tree/shared-github-actions) - CI/CD workflows documentation
- [API Documentation](./docs/api.md) - API endpoints and examples

## 🐛 Troubleshooting

### Common Issues

1. **Application won't start**
   - Check database connectivity
   - Verify environment variables
   - Check application logs

2. **Workflow failures**
   - Verify shared workflows are up to date
   - Check repository secrets configuration
   - Review workflow logs

3. **Docker build fails**
   - Check Dockerfile syntax
   - Verify JAR file exists in target/
   - Ensure Maven build completes successfully

### Debug Commands
```bash
# Check application logs
kubectl logs -f deployment/java-backend1

# Check health status
curl http://localhost:8080/actuator/health

# View configuration
curl http://localhost:8080/actuator/configprops
```

## 🤝 Contributing

1. Create a feature branch from `my-java-app`
2. Make your changes
3. Test locally and with CI/CD
4. Create a pull request to `my-java-app`

## 📄 License

This project is licensed under the MIT License.

---

**Service**: Java Backend1  
**Branch**: no-keyvault-my-app  
**Type**: Spring Boot Microservice  
**Configuration**: Spring Boot Profile-based (no external key vault)  
**Shared Workflows**: no-keyvault-shared-github-actions branch  
**Deployment**: GitHub Actions + Kubernetes + Helm
