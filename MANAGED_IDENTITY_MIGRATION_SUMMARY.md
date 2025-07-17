# Azure Managed Identity Migration Summary

## Overview
This document summarizes the migration from credential-based authentication to managed identity-based authentication for all Azure operations in the deployment workflows. This migration enhances security by eliminating the need to store Azure credentials as secrets and leverages Azure Workload Identity for secure, tokenless authentication.

## 🔐 Security Benefits

### **Before: Credential-Based Authentication**
- Required storing Azure Service Principal credentials as repository secrets
- Needed ACR username/password for container registry access
- Multiple secret management across environments
- Risk of credential exposure or expiration

### **After: Managed Identity Authentication**
- Uses Azure Workload Identity with OpenID Connect (OIDC)
- No stored credentials in GitHub
- Automatic token management and rotation
- Enhanced security posture with fine-grained permissions

## 🔄 Changes Made

### 1. **Workflow Permission Updates**
All workflows now include OIDC token permissions:
```yaml
permissions:
  id-token: write
  contents: read
```

### 2. **Azure Login Modernization**
Updated from `azure/login@v1` to `azure/login@v2` with managed identity:
```yaml
- name: Azure Login with Managed Identity
  uses: azure/login@v2
  with:
    client-id: ${{ vars.AZURE_CLIENT_ID }}
    tenant-id: ${{ vars.AZURE_TENANT_ID }}
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

### 3. **Container Registry Authentication**
**Docker Build & Push Action Updates:**
- Added `use_managed_identity` input parameter
- Implemented ACR token-based authentication using `az acr login --expose-token`
- Maintained backward compatibility with username/password authentication
- Enhanced with security scanning using Trivy

### 4. **AKS Authentication Enhancement**
Updated to use `azure/aks-set-context@v4` with kubelogin:
```yaml
- name: Get AKS credentials
  uses: azure/aks-set-context@v4
  with:
    resource-group: ${{ inputs.aks_resource_group }}
    cluster-name: ${{ inputs.aks_cluster_name }}
    use-kubelogin: true
```

### 5. **Workload Identity Integration**
Added Azure Workload Identity configuration to Helm deployments:
```yaml
serviceAccount:
  annotations:
    azure.workload.identity/client-id: ${{ vars.AZURE_CLIENT_ID }}

podLabels:
  azure.workload.identity/use: "true"
```

## 📁 Files Modified

### **Workflows**
- `.github/workflows/shared-deploy.yml`
  - Added OIDC permissions
  - Updated Azure login steps
  - Removed credential-based secrets
  - Added managed identity configuration

- `.github/workflows/deploy-java-app.yml`
  - Added OIDC permissions
  - Removed credential-based secrets

- `.github/workflows/deploy-nodejs-app.yml`
  - Added OIDC permissions
  - Removed credential-based secrets

### **Actions**
- `.github/actions/helm-deploy/action.yml`
  - Added `use_managed_identity` input
  - Updated AKS context setup
  - Added Workload Identity configuration
  - Enhanced verification steps

- `.github/actions/docker-build-push/action.yml`
  - Added managed identity support for ACR
  - Maintained backward compatibility
  - Added security scanning with Trivy
  - Enhanced container image verification

## 🚀 Setup Requirements

### **Azure Infrastructure Setup**

#### 1. **Create Azure AD Application Registration**
```bash
# Create App Registration
az ad app create --display-name "GitHub-Actions-OIDC-$YOUR_REPO_NAME"

# Get Application ID (Client ID)
APP_ID=$(az ad app list --display-name "GitHub-Actions-OIDC-$YOUR_REPO_NAME" --query "[0].appId" -o tsv)
```

#### 2. **Configure OIDC Federation**
```bash
# Create federated credential for main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "GitHubMain",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for develop branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "GitHubDevelop", 
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/develop",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for release branches
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "GitHubRelease",
    "issuer": "https://token.actions.githubusercontent.com", 
    "subject": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/release/*",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

#### 3. **Create Service Principal and Assign Permissions**
```bash
# Create Service Principal
az ad sp create --id $APP_ID

# Assign permissions to ACR
az role assignment create \
  --assignee $APP_ID \
  --role AcrPush \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$ACR_RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME

# Assign permissions to AKS clusters
az role assignment create \
  --assignee $APP_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$AKS_RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$AKS_CLUSTER_NAME

# Assign Key Vault permissions
az role assignment create \
  --assignee $APP_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KEYVAULT_RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME
```

#### 4. **Setup Azure Workload Identity (for AKS)**
```bash
# Enable OIDC Issuer on AKS cluster
az aks update \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --enable-oidc-issuer \
  --enable-workload-identity

# Get OIDC Issuer URL
OIDC_ISSUER=$(az aks show --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create User Assigned Managed Identity
az identity create --resource-group $AKS_RESOURCE_GROUP --name "${AKS_CLUSTER_NAME}-workload-identity"

# Get Client ID of the managed identity
WORKLOAD_IDENTITY_CLIENT_ID=$(az identity show --resource-group $AKS_RESOURCE_GROUP --name "${AKS_CLUSTER_NAME}-workload-identity" --query clientId -o tsv)

# Create federated credential for workload identity
az identity federated-credential create \
  --name kubernetes-federated-credential \
  --identity-name "${AKS_CLUSTER_NAME}-workload-identity" \
  --resource-group $AKS_RESOURCE_GROUP \
  --issuer $OIDC_ISSUER \
  --subject system:serviceaccount:NAMESPACE:SERVICE_ACCOUNT_NAME
```

### **GitHub Repository Configuration**

#### **Required Repository Variables**
```
AZURE_CLIENT_ID=<Application ID from App Registration>
AZURE_TENANT_ID=<Your Azure Tenant ID>
AZURE_SUBSCRIPTION_ID=<Your Azure Subscription ID>
AZURE_KEYVAULT_NAME=<Key Vault name for secrets (optional)>
```

#### **Required Repository Secrets (Reduced)**
```
ACR_LOGIN_SERVER=<your-registry>.azurecr.io
AKS_CLUSTER_NAME_DEV=<dev-cluster-name>
AKS_RESOURCE_GROUP_DEV=<dev-resource-group>
AKS_CLUSTER_NAME_STAGING=<staging-cluster-name>
AKS_RESOURCE_GROUP_STAGING=<staging-resource-group>
AKS_CLUSTER_NAME_PROD=<prod-cluster-name>
AKS_RESOURCE_GROUP_PROD=<prod-resource-group>
```

#### **Removed Secrets (No Longer Needed)**
```
❌ AZURE_CREDENTIALS (Service Principal credentials)
❌ ACR_USERNAME (Container registry username)
❌ ACR_PASSWORD (Container registry password)
```

## 🔍 Verification Steps

### **1. Test Azure Authentication**
```bash
# Test Azure CLI authentication
az account show

# Test ACR access
az acr repository list --name $ACR_NAME

# Test AKS access
az aks get-credentials --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME
kubectl get nodes
```

### **2. Test Workload Identity**
```bash
# Verify OIDC issuer
az aks show --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "oidcIssuerProfile.issuerUrl"

# Check federated credentials
az identity federated-credential list --identity-name "${AKS_CLUSTER_NAME}-workload-identity" --resource-group $AKS_RESOURCE_GROUP
```

### **3. Workflow Verification**
The updated workflows include enhanced verification steps:
- Azure Workload Identity configuration verification
- Container registry authentication testing
- Key Vault access validation
- Pod security context verification

## 🚨 Migration Checklist

### **Pre-Migration**
- [ ] Azure AD App Registration created
- [ ] OIDC federated credentials configured
- [ ] Service Principal permissions assigned
- [ ] Workload Identity setup completed
- [ ] Repository variables configured

### **During Migration**
- [ ] Update workflow files
- [ ] Test authentication in dev environment
- [ ] Verify container builds and pushes
- [ ] Validate Key Vault access
- [ ] Test AKS deployments

### **Post-Migration**
- [ ] Remove old credential-based secrets
- [ ] Verify all environments working
- [ ] Update documentation
- [ ] Monitor for authentication issues

## 🔧 Troubleshooting

### **Common Issues**

#### **OIDC Token Issues**
```
Error: OIDC token is not valid
```
**Solution:** Verify federated credential subjects match exactly with repository and branch patterns.

#### **ACR Authentication Failures**
```
Error: Failed to get ACR access token
```
**Solution:** Ensure Service Principal has `AcrPush` role on the container registry.

#### **AKS Access Denied**
```
Error: User does not have access to cluster
```
**Solution:** Verify Service Principal has appropriate AKS cluster roles and Workload Identity is configured.

#### **Key Vault Access Issues**
```
Error: The user, group or application does not have secrets get permission
```
**Solution:** Assign `Key Vault Secrets User` role to the Service Principal.

## 📈 Benefits Achieved

### **Security Enhancements**
- ✅ **Eliminated stored credentials** in GitHub secrets
- ✅ **Automatic token rotation** by Azure
- ✅ **Fine-grained permissions** with Azure RBAC
- ✅ **Audit trail** with Azure AD sign-in logs

### **Operational Improvements**
- ✅ **Reduced secret management** overhead
- ✅ **Enhanced security scanning** with Trivy
- ✅ **Better compliance** with security standards
- ✅ **Simplified credential lifecycle** management

### **Modern Authentication**
- ✅ **OIDC-based authentication** following industry standards
- ✅ **Azure Workload Identity** for Kubernetes workloads
- ✅ **Zero-trust security** model implementation
- ✅ **Future-proof authentication** approach

This migration significantly enhances the security posture of the deployment pipeline while simplifying credential management and adhering to modern authentication best practices.