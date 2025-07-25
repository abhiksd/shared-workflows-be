# Backend Services Migration Guide
## From Monorepo to Independent Repositories

This comprehensive guide helps you migrate your Spring Boot and Node.js backend services from a monorepo structure to independent repositories while maintaining centralized workflows and ensuring zero downtime.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Migration Strategy](#migration-strategy)
4. [Step-by-Step Migration](#step-by-step-migration)
5. [Post-Migration Verification](#post-migration-verification)
6. [Rollback Strategy](#rollback-strategy)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

### Current Monorepo Structure
```
shared-workflows-be/
├── apps/
│   ├── java-backend1/           # User Management Service
│   ├── java-backend2/           # Product Catalog Service
│   ├── java-backend3/           # Order Management Service
│   ├── nodejs-backend1/         # Notification Service
│   ├── nodejs-backend2/         # Analytics Service
│   └── nodejs-backend3/         # File Management Service
├── .github/workflows/           # Shared workflows
├── .github/actions/             # Composite actions
└── scripts/                     # Migration scripts
```

### Target Independent Structure
```
java-backend1-user-management/   # ✅ Independent repo
├── .github/workflows/deploy.yml # References external workflows
├── src/main/java/              # Spring Boot application
├── helm/                       # Kubernetes deployment charts
├── Dockerfile                  # Container definition
├── pom.xml                     # Maven configuration
└── DEPLOYMENT.md              # Service-specific docs

shared-workflows/               # ✅ Centralized workflows
├── .github/workflows/
│   ├── shared-deploy.yml       # Reusable deployment
│   ├── shared-security-scan.yml # Security scanning
│   └── rollback-deployment.yml # Rollback procedures
└── .github/actions/            # Composite actions
```

---

## 🔧 Prerequisites

### Required Tools
- **GitHub CLI** (`gh`) version 2.0+
- **Git** version 2.25+
- **Docker** (for local testing)
- **Maven** 3.6+ (for Java services)
- **Node.js** 18+ LTS (for Node.js services)
- **Helm** 3.8+ (for Kubernetes deployments)

### Required Access
- **GitHub Organization Owner** or **Admin** permissions
- **Azure DevOps** access (if using Azure pipelines)
- **Kubernetes cluster** access for testing
- **Container Registry** push permissions

### Verify Prerequisites
```bash
# Run the prerequisite check script
./scripts/check-migration-prerequisites.sh

# Or manually verify:
gh --version
git --version
docker --version
mvn --version
helm version
```

---

## 🎯 Migration Strategy

### 1. **Zero-Downtime Approach**
- Services continue running during migration
- Gradual transition with parallel deployments
- Immediate rollback capability

### 2. **Workflow Preservation**
- All existing CI/CD workflows preserved
- Composite actions centralized and reusable
- Environment-specific configurations maintained

### 3. **Service Independence**
- Each service gets its own repository
- Independent versioning and releases
- Team-specific access controls

---

## 📚 Step-by-Step Migration

### Phase 1: Preparation

#### 1.1 Backup Current State
```bash
# Create backup branch
git checkout -b migration-backup
git push origin migration-backup

# Archive current workflows
./scripts/backup-current-state.sh
```

#### 1.2 Validate Current Setup
```bash
# Verify all services are working
./scripts/validate-services.sh

# Check workflow integrity
./scripts/validate-workflows.sh
```

### Phase 2: Create Shared Workflows Repository

#### 2.1 Initialize Shared Workflows
```bash
# Create shared workflows repository
./scripts/create-shared-workflows-repo.sh <org-name> [shared-workflows-repo-name]

# Example:
./scripts/create-shared-workflows-repo.sh mycompany shared-workflows
```

#### 2.2 Migrate Composite Actions
```bash
# Copy and configure composite actions
./scripts/migrate-composite-actions.sh mycompany/shared-workflows
```

### Phase 3: Migrate Individual Services

#### 3.1 Migrate Java Backend Services

##### For java-backend1 (User Management Service):
```bash
# Run migration script
./scripts/migrate-java-service.sh java-backend1 mycompany/java-backend1-user-management

# This script will:
# 1. Create new repository
# 2. Copy all source code and configurations
# 3. Update workflow references
# 4. Migrate Spring Boot profiles
# 5. Update Helm charts
# 6. Create service-specific documentation
```

##### Manual Migration Steps (if preferred):
```bash
# 1. Create repository
gh repo create mycompany/java-backend1-user-management \
  --public \
  --description "User Management Service - Spring Boot Microservice"

# 2. Clone and setup
git clone https://github.com/mycompany/java-backend1-user-management.git
cd java-backend1-user-management

# 3. Copy service files
cp -r ../shared-workflows-be/apps/java-backend1/* .

# 4. Update workflow references
sed -i 's|uses: \./.github/workflows/shared-deploy\.yml|uses: mycompany/shared-workflows/.github/workflows/shared-deploy.yml@main|g' .github/workflows/deploy.yml

# 5. Update build context paths
sed -i 's|build_context: apps/java-backend1|build_context: .|g' .github/workflows/deploy.yml
sed -i 's|dockerfile_path: apps/java-backend1/Dockerfile|dockerfile_path: ./Dockerfile|g' .github/workflows/deploy.yml

# 6. Update Spring Boot profiles
./scripts/update-spring-profiles.sh

# 7. Commit and push
git add .
git commit -m "Initial commit: User Management Service

- Complete Spring Boot application with REST APIs
- Kubernetes Helm charts for deployment
- GitHub Actions workflow for CI/CD
- Comprehensive deployment documentation
- Spring Boot profiles: local, dev, staging, production"
git push origin main
```

#### 3.2 Migrate Node.js Backend Services
```bash
# Similar process for Node.js services
./scripts/migrate-nodejs-service.sh nodejs-backend1 mycompany/nodejs-backend1-notification
```

### Phase 4: Update Repository Settings

#### 4.1 Configure Repository Secrets
```bash
# Copy secrets to each service repository
./scripts/setup-repository-secrets.sh mycompany/java-backend1-user-management

# Required secrets:
# - AZURE_CLIENT_ID
# - AZURE_TENANT_ID
# - AZURE_SUBSCRIPTION_ID
# - ACR_LOGIN_SERVER
# - KEYVAULT_NAME
```

#### 4.2 Set up Branch Protection
```bash
# Configure branch protection rules
./scripts/setup-branch-protection.sh mycompany/java-backend1-user-management
```

#### 4.3 Configure Team Access
```bash
# Setup team permissions
gh api repos/mycompany/java-backend1-user-management/teams/backend-team \
  --method PUT \
  --field permission=push
```

---

## ✅ Post-Migration Verification

### 1. Service Health Checks
```bash
# Verify each service independently
./scripts/verify-migration.sh mycompany/java-backend1-user-management

# Check workflow execution
gh workflow run deploy.yml -R mycompany/java-backend1-user-management -f environment=dev

# Monitor deployment
./scripts/monitor-deployment.sh java-backend1 dev
```

### 2. Integration Testing
```bash
# Test service-to-service communication
./scripts/test-service-integration.sh

# Verify API endpoints
curl https://dev-java-backend1.example.com/api/actuator/health
```

### 3. Performance Validation
```bash
# Compare performance metrics
./scripts/compare-performance-metrics.sh java-backend1 before-migration after-migration
```

---

## 🔄 Rollback Strategy

### Quick Rollback (Emergency)
```bash
# Revert to monorepo deployments
./scripts/emergency-rollback.sh java-backend1

# This will:
# 1. Stop new repository deployments
# 2. Redeploy from original monorepo
# 3. Update DNS routing if needed
```

### Gradual Rollback
```bash
# Gradually move traffic back
./scripts/gradual-rollback.sh java-backend1 --traffic-percentage=50
```

---

## 🎯 Best Practices

### 1. **Service Configuration**
- ✅ Use environment-specific Spring Boot profiles
- ✅ Externalize configuration with Azure Key Vault
- ✅ Implement proper health checks
- ✅ Configure distributed tracing

### 2. **CI/CD Pipeline**
- ✅ Use semantic versioning for each service
- ✅ Implement automated testing at multiple levels
- ✅ Use blue-green deployments for zero downtime
- ✅ Monitor deployment metrics

### 3. **Security**
- ✅ Scan dependencies for vulnerabilities
- ✅ Use least-privilege access controls
- ✅ Implement secure secret management
- ✅ Regular security audits

### 4. **Monitoring & Observability**
- ✅ Centralized logging with correlation IDs
- ✅ Prometheus metrics for each service
- ✅ Distributed tracing with Jaeger/Zipkin
- ✅ Custom business metrics

---

## 🐛 Troubleshooting

### Common Issues & Solutions

#### Issue: Workflow Not Found
```
Error: workflow not found: shared-deploy.yml
```
**Solution:**
```bash
# Check workflow reference in .github/workflows/deploy.yml
# Ensure it points to: mycompany/shared-workflows/.github/workflows/shared-deploy.yml@main
```

#### Issue: Docker Build Fails
```
Error: JAR file not found in target directory
```
**Solution:**
```bash
# Verify Maven build artifacts
./scripts/debug-maven-build.sh

# Check Dockerfile paths
./scripts/validate-dockerfile.sh
```

#### Issue: Helm Deployment Fails
```
Error: chart not found
```
**Solution:**
```bash
# Update helm chart paths in workflow
sed -i 's|helm_chart_path: helm|helm_chart_path: ./helm|g' .github/workflows/deploy.yml

# Validate Helm chart
helm lint ./helm
```

#### Issue: Spring Boot Profile Not Loading
```
Error: Could not load application-dev.yml
```
**Solution:**
```bash
# Verify profile files exist
ls -la src/main/resources/application*.yml

# Check application.yml profile configuration
./scripts/validate-spring-profiles.sh
```

#### Issue: Environment Variables Not Set
```
Error: Required environment variable DB_HOST not set
```
**Solution:**
```bash
# Update values.yaml for each environment
./scripts/update-helm-values.sh dev
./scripts/update-helm-values.sh staging
./scripts/update-helm-values.sh production
```

### Debug Scripts
```bash
# Debug workflow execution
./scripts/debug-workflow.sh mycompany/java-backend1-user-management deploy

# Debug service connectivity
./scripts/debug-service-connectivity.sh java-backend1

# Debug Kubernetes deployment
./scripts/debug-k8s-deployment.sh java-backend1 dev
```

---

## 📊 Migration Checklist

### Pre-Migration
- [ ] Backup current monorepo state
- [ ] Verify all prerequisites installed
- [ ] Test current deployment pipeline
- [ ] Document service dependencies
- [ ] Plan team communication

### During Migration
- [ ] Create shared workflows repository
- [ ] Migrate composite actions
- [ ] Create service repositories
- [ ] Update workflow references
- [ ] Configure repository settings
- [ ] Setup secrets and variables

### Post-Migration
- [ ] Verify all services deploy successfully
- [ ] Test service-to-service communication
- [ ] Validate monitoring and logging
- [ ] Update documentation
- [ ] Train team on new workflows
- [ ] Archive old monorepo (optional)

---

## 📞 Support

- **Migration Issues**: Create issue in `shared-workflows` repository
- **Service-Specific Issues**: Create issue in respective service repository
- **Emergency Support**: Contact DevOps team via Slack #devops-support

---

## 📚 Additional Resources

- [Spring Boot Migration Guide](./docs/spring-boot-migration.md)
- [Node.js Migration Guide](./docs/nodejs-migration.md)
- [Helm Chart Best Practices](./docs/helm-best-practices.md)
- [Monitoring Setup Guide](./docs/monitoring-setup.md)
- [Security Configuration Guide](./docs/security-configuration.md)

---

**Last Updated**: December 2024  
**Version**: 2.0  
**Maintained by**: DevOps Team