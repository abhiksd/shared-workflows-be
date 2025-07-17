# Azure Deployment Helper Scripts

This directory contains shell scripts to help set up, test, and manage Azure resources for the deployment pipeline using managed identity authentication.

## 📋 Prerequisites

Before using these scripts, ensure you have:

- **Azure CLI** installed and configured
- **kubectl** installed for Kubernetes operations
- **jq** installed for JSON parsing
- **GitHub CLI** (optional, for automatic repository configuration)
- **Appropriate Azure permissions** to create and manage resources

## 🚀 Quick Start

### 1. Set Up Azure Managed Identity Infrastructure

```bash
# Set up Azure AD App Registration and federated credentials
./setup-azure-managed-identity.sh myorg/myrepo

# Follow the prompts and review the generated configuration
```

### 2. Create Key Vault Secrets

```bash
# Create secrets for all applications in development environment
./setup-keyvault-secrets.sh dev my-keyvault-dev

# Create secrets for specific application in production
./setup-keyvault-secrets.sh production my-keyvault-prod java-app
```

### 3. Test Your Setup

```bash
# Test authentication and connectivity for development environment
./test-azure-authentication.sh dev

# Test staging environment
./test-azure-authentication.sh staging
```

## 📁 Script Overview

### 🔧 `setup-azure-managed-identity.sh`

**Purpose**: Sets up Azure infrastructure for managed identity authentication with GitHub Actions.

**Usage**:
```bash
./setup-azure-managed-identity.sh <github-repo> [subscription-id]
```

**Examples**:
```bash
# Basic setup
./setup-azure-managed-identity.sh myorg/myrepo

# With specific subscription
./setup-azure-managed-identity.sh myorg/myrepo 12345678-1234-1234-1234-123456789012

# Dry run to see what would be created
DRY_RUN=true ./setup-azure-managed-identity.sh myorg/myrepo
```

**What it creates**:
- Azure AD App Registration
- Service Principal
- Federated credentials for GitHub Actions (main, develop, release/*, tags/*, pull_request)
- RBAC permissions for ACR, AKS clusters, and Key Vaults
- GitHub repository configuration script

**Environment Variables**:
```bash
ACR_NAME=myregistry                    # Azure Container Registry name
ACR_RESOURCE_GROUP=rg-container        # ACR resource group
KEYVAULT_PREFIX=kv-secrets            # Key Vault name prefix
DRY_RUN=true                          # Show what would be created
```

### 🔐 `setup-keyvault-secrets.sh`

**Purpose**: Creates and manages secrets in Azure Key Vault for different environments and applications.

**Usage**:
```bash
./setup-keyvault-secrets.sh <environment> <keyvault-name> [application]
```

**Examples**:
```bash
# Create secrets for all applications in dev environment
./setup-keyvault-secrets.sh dev my-keyvault-dev

# Create secrets for specific application in staging
./setup-keyvault-secrets.sh staging my-keyvault-staging java-app

# Dry run to see what would be created
DRY_RUN=true ./setup-keyvault-secrets.sh production my-keyvault-prod

# Skip confirmation prompts (for automation)
SKIP_CONFIRMATION=true ./setup-keyvault-secrets.sh dev my-keyvault-dev
```

**Secret Types Created**:
- **Database**: connection string, password
- **Authentication**: JWT secret, API key
- **External Services**: Redis URL, storage connection
- **Application-specific**: Spring Boot actuator password, Node.js session secrets
- **Common**: monitoring API key, logging endpoint, external service tokens

**Environment Variables**:
```bash
SKIP_CONFIRMATION=true    # Skip confirmation prompts
DRY_RUN=true             # Show what would be created without creating
```

### 🧪 `test-azure-authentication.sh`

**Purpose**: Tests Azure authentication, ACR access, AKS connectivity, and Key Vault permissions.

**Usage**:
```bash
./test-azure-authentication.sh [environment]
```

**Examples**:
```bash
# Test development environment
./test-azure-authentication.sh dev

# Test staging environment
./test-azure-authentication.sh staging

# Test production environment
./test-azure-authentication.sh production
```

**What it tests**:
- ✅ Azure CLI authentication
- ✅ Access token acquisition
- ✅ Azure Container Registry login and repository listing
- ✅ AKS cluster credentials and connectivity
- ✅ Key Vault access and secret listing
- ✅ RBAC permissions verification

**Required Environment Variables**:
```bash
AZURE_SUBSCRIPTION_ID     # Azure subscription ID
AZURE_TENANT_ID          # Azure tenant ID  
AZURE_CLIENT_ID          # App registration client ID
ACR_LOGIN_SERVER         # Container registry login server
AZURE_KEYVAULT_NAME      # Key Vault name (optional)

# Environment-specific AKS configuration
AKS_CLUSTER_NAME_DEV     # Dev cluster name
AKS_RESOURCE_GROUP_DEV   # Dev resource group
AKS_CLUSTER_NAME_STAGING # Staging cluster name
AKS_RESOURCE_GROUP_STAGING # Staging resource group
AKS_CLUSTER_NAME_PROD    # Production cluster name
AKS_RESOURCE_GROUP_PROD  # Production resource group
```

## 🔄 Typical Workflow

### Initial Setup (One-time)

1. **Set up Azure infrastructure**:
   ```bash
   ./setup-azure-managed-identity.sh myorg/myrepo
   ```

2. **Configure GitHub repository** (run the generated script):
   ```bash
   ./github-repository-config.sh
   ```

3. **Create Key Vaults and secrets** for each environment:
   ```bash
   ./setup-keyvault-secrets.sh dev my-keyvault-dev
   ./setup-keyvault-secrets.sh staging my-keyvault-staging  
   ./setup-keyvault-secrets.sh production my-keyvault-prod
   ```

### Regular Testing and Validation

1. **Test authentication** before deployments:
   ```bash
   ./test-azure-authentication.sh dev
   ```

2. **Add new secrets** as needed:
   ```bash
   ./setup-keyvault-secrets.sh dev my-keyvault-dev java-app
   ```

3. **Verify configuration** after changes:
   ```bash
   ./test-azure-authentication.sh staging
   ```

## 🛠️ Customization

### Azure Resource Names

Customize resource names using environment variables:

```bash
# Container registry configuration
export ACR_NAME="mycompany-registry"
export ACR_RESOURCE_GROUP="rg-shared-registry"

# Key Vault naming
export KEYVAULT_PREFIX="mycompany-kv"

# Run setup with custom names
./setup-azure-managed-identity.sh myorg/myrepo
```

### Secret Types

Modify the secret types in `setup-keyvault-secrets.sh` by editing the script or using the composite action with custom secret types:

```yaml
- name: Fetch custom secrets
  uses: ./.github/actions/fetch-keyvault-secrets
  with:
    secret_types: 'custom-api-key,custom-database-url,custom-token'
```

## 🚨 Troubleshooting

### Common Issues

#### Permission Errors
```bash
# Error: Insufficient privileges to complete the operation
```
**Solution**: Ensure you have the following Azure permissions:
- Application Administrator (to create App Registrations)
- User Access Administrator (to assign RBAC roles)
- Key Vault Administrator (to manage Key Vault permissions)

#### Authentication Failures
```bash
# Error: AADSTS70002: The request is missing the client_id parameter
```
**Solution**: Verify federated credentials are correctly configured:
```bash
az ad app federated-credential list --id $CLIENT_ID
```

#### Key Vault Access Issues
```bash
# Error: The user, group or application does not have secrets get permission
```
**Solution**: Verify RBAC permissions:
```bash
az role assignment list --assignee $CLIENT_ID --scope $KEYVAULT_SCOPE
```

### Debug Mode

Run scripts with debug output:
```bash
# Enable verbose logging
set -x
./test-azure-authentication.sh dev

# Dry run mode
DRY_RUN=true ./setup-keyvault-secrets.sh dev my-keyvault-dev
```

### Manual Verification

Verify setup manually:
```bash
# Check App Registration
az ad app show --id $CLIENT_ID

# Check federated credentials  
az ad app federated-credential list --id $CLIENT_ID

# Check RBAC assignments
az role assignment list --assignee $CLIENT_ID

# Test Key Vault access
az keyvault secret list --vault-name $KEYVAULT_NAME
```

## 📄 Generated Files

The scripts generate several files to help with configuration and documentation:

| File | Purpose | Generated By |
|------|---------|--------------|
| `github-repository-config.sh` | Sets GitHub secrets and variables | `setup-azure-managed-identity.sh` |
| `github-secrets-{env}.sh` | Environment-specific GitHub configuration | `setup-keyvault-secrets.sh` |
| `azure-setup-summary.txt` | Summary of created Azure resources | `setup-azure-managed-identity.sh` |
| `setup-outputs.env` | Environment variables for CI/CD | `setup-azure-managed-identity.sh` |
| `azure-auth-test-results-{env}-{timestamp}.txt` | Test results and diagnostics | `test-azure-authentication.sh` |

## 🔒 Security Best Practices

1. **Use separate Key Vaults** for each environment
2. **Rotate secrets regularly** using the setup scripts
3. **Test authentication** before important deployments
4. **Monitor RBAC permissions** and apply principle of least privilege
5. **Use federated credentials** instead of storing secrets in GitHub
6. **Enable Key Vault logging** and monitoring
7. **Review generated scripts** before execution

## 💡 Tips

- **Run dry runs first** to preview changes: `DRY_RUN=true ./script.sh`
- **Use environment variables** to customize resource names
- **Keep scripts updated** with your actual Azure resource names
- **Test in development** before applying to production
- **Document any customizations** you make to the scripts
- **Use version control** for your customized scripts

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Verify all prerequisites are installed
3. Ensure you have the required Azure permissions
4. Review the generated summary and configuration files
5. Test with dry run mode to isolate issues