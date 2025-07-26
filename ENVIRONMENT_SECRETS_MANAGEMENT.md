# Environment-Specific Secrets Management Strategy

## 🎯 **Overview**

This document outlines a comprehensive secrets management strategy that separates environment-specific secrets (Azure credentials, ACR endpoints) from common secrets (SonarQube, Checkmarx) using GitHub environments.

## 🔑 **Secrets Classification**

### **🌍 Environment-Specific Secrets** (Set in GitHub Environments)

These secrets vary per environment and should be configured in each GitHub environment:

| Secret Name | Description | Example Values | Required |
|-------------|-------------|----------------|----------|
| `AZURE_TENANT_ID` | Azure AD tenant ID | `12345678-1234-1234-1234-123456789012` | ✅ Yes |
| `AZURE_CLIENT_ID` | Service Principal client ID | `87654321-4321-4321-4321-210987654321` | ✅ Yes |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `abcdefgh-1234-5678-9012-ijklmnopqrst` | ✅ Yes |
| `ACR_LOGIN_SERVER` | Container registry endpoint | `acrdev.azurecr.io`, `acrprod.azurecr.io` | ✅ Yes |
| `ACR_USERNAME` | ACR service principal username | Environment-specific SP | ⚠️ Optional |
| `ACR_PASSWORD` | ACR service principal password | Environment-specific password | ⚠️ Optional |

### **🌐 Common/Shared Secrets** (Set at Repository Level)

These secrets are the same across all environments and should be configured at repository level:

| Secret Name | Description | Scope | Required |
|-------------|-------------|-------|----------|
| `SONAR_TOKEN` | SonarQube authentication token | All environments | ✅ Yes |
| `SONAR_HOST_URL` | SonarQube server URL | All environments | ✅ Yes |
| `CHECKMARX_CLIENT_ID` | Checkmarx client ID | All environments | ✅ Yes |
| `CHECKMARX_CLIENT_SECRET` | Checkmarx client secret | All environments | ✅ Yes |
| `CHECKMARX_URL` | Checkmarx server URL | All environments | ✅ Yes |
| `CHECKMARX_USERNAME` | Checkmarx username | All environments | ⚠️ Optional |
| `CHECKMARX_PASSWORD` | Checkmarx password | All environments | ⚠️ Optional |
| `GITHUB_TOKEN` | GitHub API token | All environments | ✅ Auto |

## 🏗️ **Environment-Specific Configuration Structure**

### **DEV Environment Secrets**
```
AZURE_TENANT_ID = "dev-tenant-12345678-1234-1234-1234-123456789012"
AZURE_CLIENT_ID = "dev-sp-87654321-4321-4321-4321-210987654321"
AZURE_SUBSCRIPTION_ID = "dev-sub-abcdefgh-1234-5678-9012-ijklmnopqrst"
ACR_LOGIN_SERVER = "acrdev.azurecr.io"
ACR_USERNAME = "dev-acr-service-principal"
ACR_PASSWORD = "dev-acr-password-123"
```

### **SQE Environment Secrets**
```
AZURE_TENANT_ID = "sqe-tenant-12345678-1234-1234-1234-123456789012"
AZURE_CLIENT_ID = "sqe-sp-87654321-4321-4321-4321-210987654321"
AZURE_SUBSCRIPTION_ID = "sqe-sub-abcdefgh-1234-5678-9012-ijklmnopqrst"
ACR_LOGIN_SERVER = "acrsqe.azurecr.io"
ACR_USERNAME = "sqe-acr-service-principal"
ACR_PASSWORD = "sqe-acr-password-456"
```

### **PPR Environment Secrets**
```
AZURE_TENANT_ID = "ppr-tenant-12345678-1234-1234-1234-123456789012"
AZURE_CLIENT_ID = "ppr-sp-87654321-4321-4321-4321-210987654321"
AZURE_SUBSCRIPTION_ID = "ppr-sub-abcdefgh-1234-5678-9012-ijklmnopqrst"
ACR_LOGIN_SERVER = "acrpreprod.azurecr.io"
ACR_USERNAME = "ppr-acr-service-principal"
ACR_PASSWORD = "ppr-acr-password-789"
```

### **PROD Environment Secrets**
```
AZURE_TENANT_ID = "prod-tenant-12345678-1234-1234-1234-123456789012"
AZURE_CLIENT_ID = "prod-sp-87654321-4321-4321-4321-210987654321"
AZURE_SUBSCRIPTION_ID = "prod-sub-abcdefgh-1234-5678-9012-ijklmnopqrst"
ACR_LOGIN_SERVER = "acrprod.azurecr.io"
ACR_USERNAME = "prod-acr-service-principal"
ACR_PASSWORD = "prod-acr-password-012"
```

## 🔧 **Implementation Strategy**

### **Updated Workflow Configuration**

```yaml
# In shared-deploy.yml
jobs:
  build:
    runs-on: ubuntu-latest
    environment: ${{ needs.validate-environment.outputs.target_environment }}
    steps:
      - name: Build and push Docker image
        uses: ./.github/actions/docker-build-push
        with:
          # Environment-specific secrets (from GitHub environment)
          azure_tenant_id: ${{ secrets.AZURE_TENANT_ID }}
          azure_client_id: ${{ secrets.AZURE_CLIENT_ID }}
          azure_subscription_id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          registry: ${{ secrets.ACR_LOGIN_SERVER }}

  deploy:
    runs-on: ubuntu-latest
    environment: ${{ needs.validate-environment.outputs.target_environment }}
    steps:
      - name: Deploy to AKS
        uses: ./.github/actions/helm-deploy
        with:
          # Environment-specific secrets (from GitHub environment)
          azure_tenant_id: ${{ secrets.AZURE_TENANT_ID }}
          azure_client_id: ${{ secrets.AZURE_CLIENT_ID }}
          azure_subscription_id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          registry: ${{ secrets.ACR_LOGIN_SERVER }}

  sonar-scan:
    runs-on: ubuntu-latest
    # No environment context needed - uses repository secrets
    steps:
      - name: SonarQube Scan
        uses: ./.github/actions/sonar-scan
        with:
          # Common secrets (from repository level)
          sonar_host_url: ${{ secrets.SONAR_HOST_URL }}
          sonar_token: ${{ secrets.SONAR_TOKEN }}

  checkmarx-scan:
    runs-on: ubuntu-latest
    # No environment context needed - uses repository secrets
    steps:
      - name: Checkmarx Scan
        uses: ./.github/actions/checkmarx-scan
        with:
          # Common secrets (from repository level)
          checkmarx_url: ${{ secrets.CHECKMARX_URL }}
          checkmarx_client_id: ${{ secrets.CHECKMARX_CLIENT_ID }}
          checkmarx_client_secret: ${{ secrets.CHECKMARX_CLIENT_SECRET }}
```

## 📋 **Setup Instructions**

### **Step 1: Configure Repository-Level Secrets**

Navigate to **Repository → Settings → Secrets and variables → Actions → Secrets**

```bash
# Common secrets (same for all environments)
SONAR_TOKEN = "your-sonar-token"
SONAR_HOST_URL = "https://sonarqube.company.com"
CHECKMARX_CLIENT_ID = "your-checkmarx-client-id"
CHECKMARX_CLIENT_SECRET = "your-checkmarx-secret"
CHECKMARX_URL = "https://checkmarx.company.com"
```

### **Step 2: Configure Environment-Level Secrets**

For **each environment** (dev, sqe, ppr, prod):

1. Navigate to **Repository → Settings → Environments**
2. Click on environment name (e.g., "dev")
3. Scroll to **Environment secrets**
4. Add environment-specific secrets:

#### **For DEV Environment:**
```bash
AZURE_TENANT_ID = "your-dev-tenant-id"
AZURE_CLIENT_ID = "your-dev-client-id"
AZURE_SUBSCRIPTION_ID = "your-dev-subscription-id"
ACR_LOGIN_SERVER = "acrdev.azurecr.io"
ACR_USERNAME = "dev-acr-sp"
ACR_PASSWORD = "dev-acr-password"
```

#### **For SQE Environment:**
```bash
AZURE_TENANT_ID = "your-sqe-tenant-id"
AZURE_CLIENT_ID = "your-sqe-client-id"
AZURE_SUBSCRIPTION_ID = "your-sqe-subscription-id"
ACR_LOGIN_SERVER = "acrsqe.azurecr.io"
ACR_USERNAME = "sqe-acr-sp"
ACR_PASSWORD = "sqe-acr-password"
```

#### **For PPR Environment:**
```bash
AZURE_TENANT_ID = "your-ppr-tenant-id"
AZURE_CLIENT_ID = "your-ppr-client-id"
AZURE_SUBSCRIPTION_ID = "your-ppr-subscription-id"
ACR_LOGIN_SERVER = "acrpreprod.azurecr.io"
ACR_USERNAME = "ppr-acr-sp"
ACR_PASSWORD = "ppr-acr-password"
```

#### **For PROD Environment:**
```bash
AZURE_TENANT_ID = "your-prod-tenant-id"
AZURE_CLIENT_ID = "your-prod-client-id"
AZURE_SUBSCRIPTION_ID = "your-prod-subscription-id"
ACR_LOGIN_SERVER = "acrprod.azurecr.io"
ACR_USERNAME = "prod-acr-sp"
ACR_PASSWORD = "prod-acr-password"
```

## 🔄 **Workflow Integration**

### **Environment Context Usage**

```yaml
# Jobs that need environment-specific secrets
build:
  environment: ${{ needs.validate-environment.outputs.target_environment }}
  # Has access to environment secrets

deploy:
  environment: ${{ needs.validate-environment.outputs.target_environment }}
  # Has access to environment secrets

# Jobs that use common secrets
sonar-scan:
  # No environment context - uses repository secrets

checkmarx-scan:
  # No environment context - uses repository secrets
```

### **Dynamic Registry Configuration**

Update the workflow to use environment-specific ACR:

```yaml
env:
  # Remove hardcoded registry, use environment-specific
  # REGISTRY: ${{ secrets.ACR_LOGIN_SERVER }}  # This will be environment-specific now

jobs:
  validate-environment:
    # ... existing logic ...
    outputs:
      registry_server: ${{ steps.aks-config.outputs.registry_server }}

  setup:
    environment: ${{ needs.validate-environment.outputs.target_environment }}
    steps:
      - name: Configure Environment-Specific Settings
        id: env-config
        run: |
          echo "registry_server=${{ secrets.ACR_LOGIN_SERVER }}" >> $GITHUB_OUTPUT
```

## 🧪 **Testing and Validation**

### **Test Workflow for Secrets Validation**

```yaml
name: Test Environment Secrets

on:
  workflow_dispatch:
    inputs:
      test_environment:
        description: 'Environment to test'
        required: true
        type: choice
        options: [dev, sqe, ppr, prod]

jobs:
  test-repository-secrets:
    runs-on: ubuntu-latest
    steps:
      - name: Test Common Secrets
        run: |
          echo "🧪 Testing repository-level secrets..."
          
          # Test SonarQube secrets
          if [ -z "${{ secrets.SONAR_TOKEN }}" ]; then
            echo "❌ SONAR_TOKEN not set"
            exit 1
          fi
          
          if [ -z "${{ secrets.SONAR_HOST_URL }}" ]; then
            echo "❌ SONAR_HOST_URL not set"
            exit 1
          fi
          
          # Test Checkmarx secrets
          if [ -z "${{ secrets.CHECKMARX_CLIENT_ID }}" ]; then
            echo "❌ CHECKMARX_CLIENT_ID not set"
            exit 1
          fi
          
          echo "✅ All repository secrets are configured"

  test-environment-secrets:
    runs-on: ubuntu-latest
    environment: ${{ inputs.test_environment }}
    steps:
      - name: Test Environment-Specific Secrets
        run: |
          echo "🧪 Testing environment secrets for: ${{ inputs.test_environment }}"
          
          ERRORS=0
          
          # Test Azure secrets
          if [ -z "${{ secrets.AZURE_TENANT_ID }}" ]; then
            echo "❌ AZURE_TENANT_ID not set"
            ERRORS=$((ERRORS + 1))
          fi
          
          if [ -z "${{ secrets.AZURE_CLIENT_ID }}" ]; then
            echo "❌ AZURE_CLIENT_ID not set"
            ERRORS=$((ERRORS + 1))
          fi
          
          if [ -z "${{ secrets.AZURE_SUBSCRIPTION_ID }}" ]; then
            echo "❌ AZURE_SUBSCRIPTION_ID not set"
            ERRORS=$((ERRORS + 1))
          fi
          
          if [ -z "${{ secrets.ACR_LOGIN_SERVER }}" ]; then
            echo "❌ ACR_LOGIN_SERVER not set"
            ERRORS=$((ERRORS + 1))
          fi
          
          if [ $ERRORS -eq 0 ]; then
            echo "✅ All environment secrets configured for ${{ inputs.test_environment }}"
          else
            echo "❌ $ERRORS missing secrets in ${{ inputs.test_environment }}"
            exit 1
          fi

  test-secrets-integration:
    runs-on: ubuntu-latest
    environment: ${{ inputs.test_environment }}
    needs: [test-repository-secrets, test-environment-secrets]
    steps:
      - name: Test Secret Integration
        run: |
          echo "🔄 Testing secrets integration..."
          echo "Environment: ${{ inputs.test_environment }}"
          echo "ACR Server: ${{ secrets.ACR_LOGIN_SERVER }}"
          echo "Azure Tenant: ${{ secrets.AZURE_TENANT_ID }}"
          echo "SonarQube URL: ${{ secrets.SONAR_HOST_URL }}"
          echo "✅ Secrets integration test completed"
```

## 🚨 **Security Considerations**

### **Environment Protection Rules**

Configure protection rules for sensitive environments:

```yaml
# Example protection configuration
dev:
  - No protection (development environment)

sqe:
  - No protection (testing environment)

ppr:
  - Required reviewers: [DevOps team]
  - Deployment branches: release/* only

prod:
  - Required reviewers: [Senior DevOps, Security team]
  - Wait timer: 5 minutes
  - Deployment branches: tags only
```

### **Service Principal Best Practices**

1. **Separate Service Principals per Environment**
   - Each environment should have its own Azure Service Principal
   - Principle of least privilege - only access needed resources

2. **Regular Rotation**
   - Rotate secrets regularly (quarterly recommended)
   - Use Azure Key Vault for automatic rotation if available

3. **Monitoring and Auditing**
   - Monitor secret usage and access
   - Regular audit of environment access

## 📊 **Migration Strategy**

### **Phase 1: Preparation**
1. Create environment-specific Azure Service Principals
2. Set up environment-specific ACR instances (if needed)
3. Document current secret mapping

### **Phase 2: Environment Setup**
1. Create GitHub environments
2. Configure environment-specific secrets
3. Test with validation workflow

### **Phase 3: Workflow Migration**
1. Update workflow to use environment context for Azure secrets
2. Keep common secrets at repository level
3. Test each environment thoroughly

### **Phase 4: Cleanup**
1. Remove old repository-level Azure secrets
2. Update documentation
3. Train team on new secret management

## 🎯 **Benefits**

### **✅ Security Benefits**
- **Environment Isolation**: Separate credentials per environment
- **Least Privilege**: Each environment only accesses its resources
- **Blast Radius Limitation**: Compromised credentials only affect one environment

### **✅ Operational Benefits**
- **Clear Separation**: Common vs environment-specific secrets
- **Easy Management**: Environment-specific changes don't affect others
- **Scalability**: Easy to add new environments with their own secrets

### **✅ Compliance Benefits**
- **Audit Trail**: Environment-specific access logging
- **Access Control**: Environment-based approval workflows
- **Segregation of Duties**: Different teams can manage different environments

## 🔗 **Related Documentation**

- [GitHub Environment Variables Setup](./GITHUB_ENVIRONMENT_VARIABLES_SETUP.md)
- [Dynamic AKS Configuration](./AKS_DYNAMIC_CONFIGURATION.md)
- [Docker Cleanup Strategy](./DOCKER_CLEANUP_STRATEGY.md)

---

**📝 Document Version**: 1.0  
**🗓️ Last Updated**: $(date -u)  
**👥 Maintained By**: DevOps Team  
**🔄 Review Cycle**: Monthly