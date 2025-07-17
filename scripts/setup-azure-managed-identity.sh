#!/bin/bash

# =============================================================================
# Azure Managed Identity Setup Script for GitHub Actions
# =============================================================================
# This script sets up Azure infrastructure for managed identity authentication
# including App Registration, federated credentials, and RBAC permissions.
#
# Usage: ./setup-azure-managed-identity.sh <repository> [subscription-id]
# Example: ./setup-azure-managed-identity.sh myorg/myrepo
#
# Prerequisites:
# - Azure CLI installed and authenticated
# - Appropriate permissions to create resources
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Input parameters
GITHUB_REPO="${1:-}"
SUBSCRIPTION_ID="${2:-}"
APP_NAME_PREFIX="${3:-GitHub-Actions-OIDC}"

# Default resource names (can be customized)
ACR_NAME="${ACR_NAME:-myregistry}"
ACR_RESOURCE_GROUP="${ACR_RESOURCE_GROUP:-rg-container-registry}"
KEYVAULT_PREFIX="${KEYVAULT_PREFIX:-kv-secrets}"

# Environment configurations
declare -A ENVIRONMENTS=(
    ["dev"]="development"
    ["staging"]="staging"
    ["production"]="production"
)

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage information
show_usage() {
    echo "Usage: $0 <github-repository> [subscription-id]"
    echo ""
    echo "Parameters:"
    echo "  github-repository  - GitHub repository in format 'owner/repo'"
    echo "  subscription-id    - Azure subscription ID (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 myorg/myrepo"
    echo "  $0 myorg/myrepo 12345678-1234-1234-1234-123456789012"
    echo ""
    echo "Environment Variables (optional):"
    echo "  ACR_NAME=myregistry           - Azure Container Registry name"
    echo "  ACR_RESOURCE_GROUP=rg-acr     - ACR resource group"
    echo "  KEYVAULT_PREFIX=kv-secrets    - Key Vault name prefix"
    echo "  DRY_RUN=true                  - Show what would be created"
}

# Validate inputs
validate_inputs() {
    if [[ -z "$GITHUB_REPO" ]]; then
        log_error "GitHub repository is required"
        show_usage
        exit 1
    fi
    
    if [[ ! "$GITHUB_REPO" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid GitHub repository format. Use 'owner/repo'"
        exit 1
    fi
    
    # Extract owner and repo name
    GITHUB_OWNER=$(echo "$GITHUB_REPO" | cut -d'/' -f1)
    GITHUB_REPO_NAME=$(echo "$GITHUB_REPO" | cut -d'/' -f2)
    
    # Set app name
    APP_NAME="${APP_NAME_PREFIX}-${GITHUB_REPO_NAME}"
}

# Check Azure authentication and subscription
check_azure_auth() {
    log_info "Checking Azure authentication..."
    
    if ! az account show &> /dev/null; then
        log_error "Not authenticated to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Get current subscription if not provided
    if [[ -z "$SUBSCRIPTION_ID" ]]; then
        SUBSCRIPTION_ID=$(az account show --query id -o tsv)
        log_info "Using current subscription: $SUBSCRIPTION_ID"
    else
        log_info "Setting subscription: $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi
    
    # Get tenant ID
    TENANT_ID=$(az account show --query tenantId -o tsv)
    log_info "Tenant ID: $TENANT_ID"
    
    log_success "Azure authentication verified"
}

# Create Azure AD App Registration
create_app_registration() {
    log_info "Creating Azure AD App Registration: $APP_NAME"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create App Registration: $APP_NAME"
        return 0
    fi
    
    # Check if app already exists
    if APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null) && [[ -n "$APP_ID" && "$APP_ID" != "null" ]]; then
        log_warning "App Registration '$APP_NAME' already exists with ID: $APP_ID"
        read -p "Do you want to continue with existing app? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled"
            exit 0
        fi
    else
        # Create new app registration
        log_info "Creating new App Registration..."
        APP_ID=$(az ad app create \
            --display-name "$APP_NAME" \
            --query appId -o tsv)
        
        if [[ -n "$APP_ID" ]]; then
            log_success "Created App Registration with ID: $APP_ID"
        else
            log_error "Failed to create App Registration"
            exit 1
        fi
    fi
    
    # Create service principal
    log_info "Creating Service Principal..."
    if az ad sp create --id "$APP_ID" &> /dev/null; then
        log_success "Service Principal created successfully"
    else
        log_warning "Service Principal may already exist"
    fi
    
    echo "APP_ID=$APP_ID" >> setup-outputs.env
}

# Create federated credentials for GitHub Actions
create_federated_credentials() {
    log_info "Creating federated credentials for GitHub Actions..."
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create federated credentials for $GITHUB_REPO"
        return 0
    fi
    
    # Federated credential configurations
    declare -a CREDENTIALS=(
        "main:repo:${GITHUB_REPO}:ref:refs/heads/main"
        "develop:repo:${GITHUB_REPO}:ref:refs/heads/develop"
        "release:repo:${GITHUB_REPO}:ref:refs/heads/release/*"
        "tags:repo:${GITHUB_REPO}:ref:refs/tags/*"
        "pr:repo:${GITHUB_REPO}:pull_request"
    )
    
    for credential in "${CREDENTIALS[@]}"; do
        IFS=':' read -ra CRED_PARTS <<< "$credential"
        NAME="${CRED_PARTS[0]}"
        SUBJECT="${CRED_PARTS[1]}:${CRED_PARTS[2]}:${CRED_PARTS[3]}:${CRED_PARTS[4]}"
        
        log_info "Creating federated credential: $NAME"
        
        # Check if credential already exists
        if az ad app federated-credential list --id "$APP_ID" --query "[?name=='$NAME']" -o tsv | grep -q "$NAME"; then
            log_warning "Federated credential '$NAME' already exists"
            continue
        fi
        
        # Create federated credential
        if az ad app federated-credential create \
            --id "$APP_ID" \
            --parameters "{
                \"name\": \"$NAME\",
                \"issuer\": \"https://token.actions.githubusercontent.com\",
                \"subject\": \"$SUBJECT\",
                \"audiences\": [\"api://AzureADTokenExchange\"]
            }" &> /dev/null; then
            log_success "Created federated credential: $NAME"
        else
            log_error "Failed to create federated credential: $NAME"
        fi
    done
}

# Setup RBAC permissions
setup_rbac_permissions() {
    log_info "Setting up RBAC permissions..."
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would set up RBAC permissions"
        return 0
    fi
    
    # ACR permissions
    log_info "Setting up Azure Container Registry permissions..."
    ACR_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$ACR_RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME"
    
    if az role assignment create \
        --assignee "$APP_ID" \
        --role "AcrPush" \
        --scope "$ACR_SCOPE" &> /dev/null; then
        log_success "Assigned AcrPush role to ACR: $ACR_NAME"
    else
        log_warning "Failed to assign ACR permissions (may already exist)"
    fi
    
    # AKS permissions for each environment
    for env in "${!ENVIRONMENTS[@]}"; do
        log_info "Setting up AKS permissions for $env environment..."
        
        # You'll need to customize these based on your actual resource groups and clusters
        AKS_CLUSTER_VAR="AKS_CLUSTER_NAME_${env^^}"
        AKS_RG_VAR="AKS_RESOURCE_GROUP_${env^^}"
        
        # Example AKS cluster names (customize as needed)
        AKS_CLUSTER_NAME="aks-${env}"
        AKS_RESOURCE_GROUP="rg-${env}"
        
        AKS_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$AKS_RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$AKS_CLUSTER_NAME"
        
        # Assign cluster user role
        if az role assignment create \
            --assignee "$APP_ID" \
            --role "Azure Kubernetes Service Cluster User Role" \
            --scope "$AKS_SCOPE" &> /dev/null; then
            log_success "Assigned AKS permissions for $env: $AKS_CLUSTER_NAME"
        else
            log_warning "Failed to assign AKS permissions for $env (cluster may not exist)"
        fi
    done
    
    # Key Vault permissions for each environment
    log_info "Setting up Key Vault permissions..."
    for env in "${!ENVIRONMENTS[@]}"; do
        KEYVAULT_NAME="$KEYVAULT_PREFIX-$env"
        
        # Check if Key Vault exists
        if az keyvault show --name "$KEYVAULT_NAME" &> /dev/null; then
            if az role assignment create \
                --assignee "$APP_ID" \
                --role "Key Vault Secrets User" \
                --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-$env/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME" &> /dev/null; then
                log_success "Assigned Key Vault permissions for $env: $KEYVAULT_NAME"
            else
                log_warning "Failed to assign Key Vault permissions for $env"
            fi
        else
            log_warning "Key Vault does not exist: $KEYVAULT_NAME"
        fi
    done
}

# Generate GitHub repository configuration
generate_github_config() {
    log_info "Generating GitHub repository configuration..."
    
    local config_file="github-repository-config.sh"
    
    cat > "$config_file" << EOF
#!/bin/bash
# GitHub Repository Configuration Script
# Generated for repository: $GITHUB_REPO
# Azure App Registration: $APP_NAME

echo "Setting up GitHub repository variables and secrets..."

# Repository Variables (these can be public)
gh variable set AZURE_CLIENT_ID --body "$APP_ID"
gh variable set AZURE_TENANT_ID --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"

# Optional: Set Key Vault names
for env in dev staging production; do
    gh variable set AZURE_KEYVAULT_NAME_\${env^^} --body "$KEYVAULT_PREFIX-\$env"
done

# Repository Secrets (these are encrypted)
gh secret set ACR_LOGIN_SERVER --body "$ACR_NAME.azurecr.io"

# AKS cluster information for each environment
gh secret set AKS_CLUSTER_NAME_DEV --body "aks-dev"
gh secret set AKS_RESOURCE_GROUP_DEV --body "rg-dev"
gh secret set AKS_CLUSTER_NAME_STAGING --body "aks-staging"
gh secret set AKS_RESOURCE_GROUP_STAGING --body "rg-staging"
gh secret set AKS_CLUSTER_NAME_PROD --body "aks-production"
gh secret set AKS_RESOURCE_GROUP_PROD --body "rg-production"

echo "GitHub repository configuration completed!"
echo ""
echo "Note: Please update the AKS cluster names and resource groups"
echo "      with your actual values before running this script."
EOF
    
    chmod +x "$config_file"
    log_success "GitHub configuration script created: $config_file"
}

# Generate summary report
generate_summary() {
    log_info "Generating setup summary..."
    
    local summary_file="azure-setup-summary.txt"
    
    cat > "$summary_file" << EOF
Azure Managed Identity Setup Summary
===================================
Date: $(date)
GitHub Repository: $GITHUB_REPO
Azure Subscription: $SUBSCRIPTION_ID
Azure Tenant: $TENANT_ID

App Registration:
- Name: $APP_NAME
- Client ID: $APP_ID

Federated Credentials Created:
- main (refs/heads/main)
- develop (refs/heads/develop)
- release (refs/heads/release/*)
- tags (refs/tags/*)
- pr (pull_request)

RBAC Permissions Assigned:
- AcrPush on $ACR_NAME
- AKS Cluster User Role on environment clusters
- Key Vault Secrets User on environment vaults

Next Steps:
1. Run the GitHub configuration script: ./github-repository-config.sh
2. Update AKS cluster names and resource groups in the script
3. Create Key Vaults using: ./setup-keyvault-secrets.sh
4. Test authentication using: ./test-azure-authentication.sh

Files Generated:
- github-repository-config.sh - Script to set GitHub secrets/variables
- setup-outputs.env - Environment variables for CI/CD
- azure-setup-summary.txt - This summary file
EOF
    
    log_success "Setup summary created: $summary_file"
}

# Main execution
main() {
    echo "=================================================="
    echo "Azure Managed Identity Setup for GitHub Actions"
    echo "Repository: $GITHUB_REPO"
    echo "=================================================="
    echo
    
    validate_inputs
    check_azure_auth
    
    # Confirmation prompt
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        echo "This script will create the following Azure resources:"
        echo "- App Registration: $APP_NAME"
        echo "- Service Principal with federated credentials"
        echo "- RBAC role assignments for ACR, AKS, and Key Vault"
        echo ""
        read -p "Do you want to continue? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled by user"
            exit 0
        fi
    fi
    
    echo
    
    # Execute setup steps
    create_app_registration
    echo
    
    create_federated_credentials
    echo
    
    setup_rbac_permissions
    echo
    
    generate_github_config
    echo
    
    generate_summary
    
    echo
    log_success "Azure managed identity setup completed!"
    echo
    
    echo "=================================================="
    echo "Setup Complete!"
    echo ""
    echo "App Registration ID: $APP_ID"
    echo "Tenant ID: $TENANT_ID"
    echo "Subscription ID: $SUBSCRIPTION_ID"
    echo ""
    echo "Next steps:"
    echo "1. Review and run: ./github-repository-config.sh"
    echo "2. Set up secrets: ./setup-keyvault-secrets.sh"
    echo "3. Test setup: ./test-azure-authentication.sh"
    echo "=================================================="
}

# Check for help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_usage
    exit 0
fi

# Run the script
main "$@"