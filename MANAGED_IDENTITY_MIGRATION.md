# Azure Managed Identity Migration

## Overview

This document describes the migration from credential-based Azure authentication to managed identity authentication for the CI/CD pipelines.

## Changes Made

### 1. Workflow Files Updated

#### `.github/workflows/shared-deploy.yml`
- **Removed**: `AZURE_CREDENTIALS`, `ACR_USERNAME`, and `ACR_PASSWORD` secret requirements
- **Updated**: Azure login step to use `auth-type: IDENTITY` instead of credentials
- **Added**: Azure login step to the build job for ACR authentication

#### `.github/workflows/deploy-java-app.yml`
- **Removed**: Credential secrets from the secrets section
- **Kept**: Only `ACR_LOGIN_SERVER` and AKS cluster configuration secrets

#### `.github/workflows/deploy-nodejs-app.yml`
- **Removed**: Credential secrets from the secrets section
- **Kept**: Only `ACR_LOGIN_SERVER` and AKS cluster configuration secrets

### 2. Custom Actions Updated

#### `.github/actions/docker-build-push/action.yml`
- **Removed**: `registry_username` and `registry_password` inputs
- **Replaced**: Docker login action with `az acr login` using managed identity
- **Simplified**: Authentication flow to use Azure CLI with managed identity

## Required Setup

### 1. GitHub Runner Configuration

Your GitHub runners (self-hosted or GitHub-hosted with additional configuration) must be configured with a managed identity that has the following permissions:

#### Azure Container Registry (ACR) Permissions
- `AcrPush` role on the ACR resource
- `AcrPull` role on the ACR resource (for pulling base images)

#### Azure Kubernetes Service (AKS) Permissions
- `Azure Kubernetes Service Cluster User Role` on AKS clusters
- `Azure Kubernetes Service RBAC Cluster Admin` for deployment operations

#### Resource Group Permissions
- `Reader` role on the resource groups containing ACR and AKS resources

### 2. Managed Identity Setup

#### For Self-Hosted Runners on Azure VMs
1. Create a user-assigned managed identity or use system-assigned managed identity
2. Assign the managed identity to your runner VMs
3. Grant the required permissions listed above

#### For GitHub-Hosted Runners (using OIDC)
If using GitHub-hosted runners, you'll need to configure OpenID Connect (OIDC) instead:

1. Create a user-assigned managed identity
2. Configure federated identity credentials for your GitHub repository
3. Use the `azure/login@v1` action with `auth-type: IDENTITY` and additional OIDC configuration

### 3. Repository Secrets to Remove

The following secrets are no longer needed and can be removed from your repository:
- `AZURE_CREDENTIALS`
- `ACR_USERNAME` 
- `ACR_PASSWORD`

### 4. Repository Secrets to Keep

The following secrets are still required:
- `ACR_LOGIN_SERVER` - Your ACR login server URL
- Environment-specific AKS secrets:
  - `AKS_CLUSTER_NAME_DEV`
  - `AKS_RESOURCE_GROUP_DEV`
  - `AKS_CLUSTER_NAME_STAGING`
  - `AKS_RESOURCE_GROUP_STAGING`
  - `AKS_CLUSTER_NAME_PROD`
  - `AKS_RESOURCE_GROUP_PROD`

## Benefits

### Security Improvements
- **No stored credentials**: Eliminates the need to store and rotate service principal credentials
- **Reduced secret management**: Fewer secrets to manage and secure
- **Audit trail**: Better audit trail through Azure Activity Log for managed identity operations

### Operational Benefits
- **Automatic credential rotation**: Managed identities handle credential rotation automatically
- **Simplified setup**: No need to create and manage service principals
- **Better integration**: Native Azure integration with improved reliability

## Verification

### Testing the Migration
1. Ensure your GitHub runners have the configured managed identity
2. Verify the managed identity has the required permissions
3. Run a test deployment to verify authentication works
4. Monitor Azure Activity Logs to confirm operations are performed using managed identity

### Troubleshooting
If authentication fails:
1. Verify the runner has access to the managed identity
2. Check that the managed identity has the required role assignments
3. Ensure the ACR login server URL is correct
4. Review Azure Activity Logs for authentication attempts

## Rollback Plan

If you need to rollback to credential-based authentication:
1. Restore the removed secrets in your repository
2. Revert the workflow files to use `creds: ${{ secrets.AZURE_CREDENTIALS }}`
3. Restore the ACR username/password authentication in the docker-build-push action

## Security Considerations

- Managed identities are scoped to specific Azure resources
- Role assignments should follow the principle of least privilege
- Regular review of permissions is recommended
- Consider using separate managed identities for different environments

## Next Steps

1. Configure your GitHub runners with managed identity
2. Assign the required Azure role permissions
3. Remove the obsolete credential secrets
4. Test the pipeline with a sample deployment
5. Monitor the first few deployments to ensure everything works correctly