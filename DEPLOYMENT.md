# Java Backend1 Deployment Guide

This service is deployed from the `no-keyvault-my-app` branch using shared workflows from the `no-keyvault-shared-github-actions` branch with Spring Boot profile-based configuration management.


This document describes how to deploy the User Management Service using the integrated GitHub Actions workflow.

## 🏗️ **Service Overview**

**Java Backend 1** is a Spring Boot application that handles:
- User authentication and authorization
- User profile management
- Account management operations

## 🚀 **Deployment Methods**

### 1. **Automatic Deployment (Push-based)**

The deployment workflow automatically triggers when:

```yaml
# Automatic triggers
on:
  push:
    branches:
      - main          # Production deployments
      - develop       # Development deployments
      - 'release/**'  # Release candidate deployments
      - 'feature/**'  # Feature branch deployments
    paths:
      - '**'        # Source code changes
      - 'helm/**'        # Helm chart changes
      - '.github/workflows/deploy.yml' # Workflow changes
```

### 2. **Manual Deployment (Workflow Dispatch)**

Trigger manual deployments through GitHub Actions:

```bash
# Using GitHub CLI
gh workflow run deploy.yml -f environment=dev
gh workflow run deploy.yml -f environment=sqe
gh workflow run deploy.yml -f environment=ppr
gh workflow run deploy.yml -f environment=prod

# Or through GitHub UI:
# Actions → Deploy Java Backend 1 - User Management Service → Run workflow
```

**Manual deployment options:**
- **Environment**: `dev`, `sqe`, `ppr`, or `prod`
- **Force Deploy**: Deploy even if no changes detected

### 3. **Pull Request Validation**

Deployment validation runs on pull requests to:
- `main` branch (production readiness)
- `develop` branch (integration testing)

## 🔧 **Workflow Configuration**

The deployment workflow uses the shared deployment infrastructure:

```yaml
jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml
    with:
      application_name: java-backend1
      application_type: java-springboot
      build_context: apps/java-backend1
      dockerfile_path: Dockerfile
      helm_chart_path: helm
```

## 🌍 **Environment-Specific Deployments**

### Development Environment
- **Branch**: `dev` (also supports `develop`)
- **URL**: `https://dev.mydomain.com/backend1`
- **Namespace**: `dev`
- **Auto-deploy**: ✅ On push to dev branch

### SQE Environment  
- **Branch**: `sqe`
- **URL**: `https://sqe.mydomain.com/backend1`
- **Namespace**: `sqe`
- **Auto-deploy**: ✅ On push to sqe branch

### Pre-Production Environment
- **Branch**: `release/**` (also supports `ppr` branch)
- **URL**: `https://ppr.mydomain.com/backend1`
- **Namespace**: `ppr`
- **Auto-deploy**: ✅ On push to release/** branches

### Production Environment
- **Branch**: **Tags** (preserves existing tagging logic)
- **URL**: `https://production.mydomain.com/backend1`
- **Namespace**: `prod`
- **Auto-deploy**: ✅ On tag creation (with approval gate)

## 📊 **Monitoring & Health Checks**

### Health Endpoints
```bash
# Application health
curl https://dev.mydomain.com/backend1/actuator/health

# Application status
curl https://dev.mydomain.com/backend1/api/status

# Metrics (Prometheus)
curl https://dev.mydomain.com/backend1/actuator/prometheus
```

### Kubernetes Resources
```bash
# Check deployment status
kubectl get deployment java-backend1-dev -n dev

# Check pod logs
kubectl logs -f deployment/java-backend1-dev -n dev

# Check service status
kubectl get service java-backend1-dev -n dev
```

## 🎯 **Service Endpoints**

### User Management API
```bash
# Get users
curl https://dev.mydomain.com/backend1/api/users

# Health check
curl https://dev.mydomain.com/backend1/actuator/health

# Service status
curl https://dev.mydomain.com/backend1/api/status
```

## 🔐 **Configuration & Secrets Management**

### Spring Boot Profile-Based Configuration
The application uses environment-specific Spring Boot profiles:
- **Dev**: Development profile with PostgreSQL, debug logging, permissive CORS
- **SQE**: System Quality Engineering - production-like settings with enhanced monitoring and validation
- **PPR**: Pre-Production - final validation environment with production configuration
- **Production**: Optimized for performance, security, and minimal resource usage
- **Local**: H2 in-memory database for local development

### Secret Management Strategy
- **Kubernetes Secrets**: Database passwords, JWT secrets, API keys
- **ConfigMaps**: Non-sensitive configuration like URLs, timeouts, feature flags
- **Spring Profiles**: Environment-specific application behavior

### Required Deployment Secrets
The deployment workflow requires these secrets:
- `ACR_LOGIN_SERVER` - Azure Container Registry
- `AZURE_TENANT_ID` - Azure tenant
- `AZURE_CLIENT_ID` - Azure service principal  
- `AZURE_SUBSCRIPTION_ID` - Azure subscription

### Application Runtime Secrets (Kubernetes)
These are automatically injected into the application container:
- `DB_PASSWORD` - Database connection password
- `REDIS_PASSWORD` - Redis authentication password
- `JWT_SECRET` - JWT token signing secret
- `API_KEY` - External service API authentication key

## 🚀 **Manual Deployment Guide**

### Branch Validation Rules

The deployment workflow enforces strict branch validation:

| Environment | Required Branch/Tag | Manual Deployment |
|-------------|-------------------|-------------------|
| **DEV** | `dev`, `develop` | Override required for other branches |
| **SQE** | `sqe` | Override required for other branches |
| **PPR** | `release/*` | Override required for other branches |
| **PROD** | `refs/tags/*` | Override required for other branches |

### Using Override Branch Validation

When you need to deploy from an unauthorized branch:

#### **Via GitHub UI**
1. Go to **Actions** → **Deploy Java Backend 1** → **Run workflow**
2. Select target environment
3. ✅ **Check "Override branch validation"**
4. **Add deployment notes** (required for audit)
5. Click **Run workflow**

#### **Via GitHub CLI**
```bash
# Deploy to DEV from feature branch
gh workflow run deploy.yml \
  -f environment=dev \
  -f override_branch_validation=true \
  -f deploy_notes="Testing feature branch changes"

# Emergency PROD deployment
gh workflow run deploy.yml \
  -f environment=prod \
  -f override_branch_validation=true \
  -f deploy_notes="Critical hotfix - approved by incident commander"
```

### When to Use Override
- ✅ **Emergency hotfixes** requiring immediate deployment
- ✅ **Testing deployments** from feature branches
- ✅ **Rollback scenarios** requiring specific commit deployment
- ❌ **Not for regular development** - use proper branches instead

### Security & Audit
- All override usage is **logged with user attribution**
- Deployment notes are **required for production overrides**
- Override activities are **tracked for compliance**

## 📋 **Deployment Checklist**

Before deploying to production:

- [ ] Code reviewed and approved
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Security scan completed (SonarQube, Checkmarx)
- [ ] Performance testing completed
- [ ] **Branch validation**: Using correct branch OR override justified
- [ ] **Deployment notes**: Provided if using override
- [ ] Helm chart values updated
- [ ] Spring Boot profiles configured for target environment
- [ ] Kubernetes secrets created with required values
- [ ] ConfigMaps updated with environment-specific settings
- [ ] Database migrations ready (if applicable)
- [ ] Monitoring alerts configured

## 🚨 **Rollback Procedure**

If deployment fails or issues are detected:

```bash
# Quick rollback using Helm
helm rollback java-backend1-production --namespace production

# Or use the centralized rollback workflow
gh workflow run rollback-deployment.yml \
  -f application_name=java-backend1 \
  -f environment=production \
  -f revision=previous
```

## 🔍 **Troubleshooting**

### Common Issues

1. **Build Failures**
   ```bash
   # Check build logs in GitHub Actions
   # Verify Dockerfile and dependencies
   ```

2. **Deployment Issues**
   ```bash
   # Check Helm release status
   helm status java-backend1-dev -n dev
   
   # Check pod events
   kubectl describe pod -l app=java-backend1 -n dev
   ```

3. **Service Unavailable**
   ```bash
   # Check ingress configuration
   kubectl get ingress -n dev
   
   # Verify service endpoints
   kubectl get endpoints java-backend1-dev -n dev
   ```

4. **Configuration Issues**
   ```bash
   # Check active Spring profiles
   curl http://localhost:8080/actuator/env | jq '.activeProfiles'
   
   # View configuration properties
   curl http://localhost:8080/actuator/configprops
   
   # Check ConfigMap
   kubectl get configmap java-backend1-dev-config -n dev -o yaml
   
   # Check secrets (without exposing values)
   kubectl get secret app-secrets -n dev
   ```

## 📞 **Support**

For deployment issues:
1. Check GitHub Actions logs
2. Review Kubernetes pod logs
3. Check Azure Container Registry access
4. Verify Kubernetes secrets and ConfigMaps are properly configured
5. Validate Spring Boot profile configuration
6. Contact DevOps team if issues persist

---

**🏗️ Service**: User Management Service  
**🔗 Repository**: `/`  
**📊 Monitoring**: Prometheus + Grafana  
**🚀 Deployment**: GitHub Actions + Helm