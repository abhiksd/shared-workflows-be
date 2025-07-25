# Java Backend 1 - User Management Service Deployment

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
      - 'apps/java-backend1/**'        # Source code changes
      - 'helm/**'        # Helm chart changes
      - '.github/workflows/deploy.yml' # Workflow changes
```

### 2. **Manual Deployment (Workflow Dispatch)**

Trigger manual deployments through GitHub Actions:

```bash
# Using GitHub CLI
gh workflow run deploy.yml -f environment=dev
gh workflow run deploy.yml -f environment=staging
gh workflow run deploy.yml -f environment=production

# Or through GitHub UI:
# Actions → Deploy Java Backend 1 - User Management Service → Run workflow
```

**Manual deployment options:**
- **Environment**: `dev`, `staging`, or `production`
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
      dockerfile_path: apps/java-backend1/Dockerfile
      helm_chart_path: helm
```

## 🌍 **Environment-Specific Deployments**

### Development Environment
- **Branch**: `develop`, `feature/**`
- **URL**: `https://dev.mydomain.com/backend1`
- **Namespace**: `dev`
- **Auto-deploy**: ✅ On push

### Staging Environment
- **Branch**: `release/**`
- **URL**: `https://staging.mydomain.com/backend1`
- **Namespace**: `staging`
- **Auto-deploy**: ✅ On push

### Production Environment
- **Branch**: `main`
- **URL**: `https://production.mydomain.com/backend1`
- **Namespace**: `production`
- **Auto-deploy**: ✅ On push

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

## 🔐 **Authentication & Secrets**

The deployment workflow requires these secrets:
- `ACR_LOGIN_SERVER` - Azure Container Registry
- `KEYVAULT_NAME` - Azure Key Vault for secrets
- `AZURE_TENANT_ID` - Azure tenant
- `AZURE_CLIENT_ID` - Azure service principal
- `AZURE_SUBSCRIPTION_ID` - Azure subscription

## 📋 **Deployment Checklist**

Before deploying to production:

- [ ] Code reviewed and approved
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Security scan completed
- [ ] Performance testing completed
- [ ] Helm chart values updated
- [ ] Environment variables configured
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

## 📞 **Support**

For deployment issues:
1. Check GitHub Actions logs
2. Review Kubernetes pod logs
3. Check Azure Container Registry access
4. Verify Azure Key Vault permissions
5. Contact DevOps team if issues persist

---

**🏗️ Service**: User Management Service  
**🔗 Repository**: `/apps/java-backend1/`  
**📊 Monitoring**: Prometheus + Grafana  
**🚀 Deployment**: GitHub Actions + Helm