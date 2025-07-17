#!/bin/bash

# Azure Infrastructure Setup Script for GitHub Actions with Managed Identity
# This script sets up Azure AD App Registration, OIDC federation, and required permissions

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if required tools are installed
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Configuration variables
setup_config() {
    log_info "Setting up configuration..."
    
    # Prompt for required variables if not set
    if [ -z "$REPO_NAME" ]; then
        read -p "Enter your GitHub repository name (org/repo): " REPO_NAME
    fi
    
    if [ -z "$APP_NAME" ]; then
        APP_NAME="GitHub-Actions-OIDC-${REPO_NAME//\//-}"
    fi
    
    if [ -z "$SUBSCRIPTION_ID" ]; then
        SUBSCRIPTION_ID=$(az account show --query id -o tsv)
        log_info "Using current subscription: $SUBSCRIPTION_ID"
    fi
    
    if [ -z "$TENANT_ID" ]; then
        TENANT_ID=$(az account show --query tenantId -o tsv)
    fi
    
    # Resource names
    ACR_NAME=${ACR_NAME:-""}
    AKS_CLUSTER_NAME_DEV=${AKS_CLUSTER_NAME_DEV:-""}
    AKS_CLUSTER_NAME_STAGING=${AKS_CLUSTER_NAME_STAGING:-""}
    AKS_CLUSTER_NAME_PROD=${AKS_CLUSTER_NAME_PROD:-""}
    KEYVAULT_NAME_DEV=${KEYVAULT_NAME_DEV:-""}
    KEYVAULT_NAME_STAGING=${KEYVAULT_NAME_STAGING:-""}
    KEYVAULT_NAME_PROD=${KEYVAULT_NAME_PROD:-""}
    
    log_success "Configuration setup complete"
    log_info "Repository: $REPO_NAME"
    log_info "App Name: $APP_NAME"
    log_info "Subscription: $SUBSCRIPTION_ID"
    log_info "Tenant: $TENANT_ID"
}

# Create Azure AD App Registration
create_app_registration() {
    log_info "Creating Azure AD App Registration..."
    
    # Check if app already exists
    if az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv | grep -q "."; then
        APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
        log_warning "App Registration already exists with ID: $APP_ID"
    else
        # Create new app registration
        APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
        log_success "Created App Registration with ID: $APP_ID"
    fi
    
    # Create Service Principal if it doesn't exist
    if ! az ad sp show --id "$APP_ID" &> /dev/null; then
        az ad sp create --id "$APP_ID" > /dev/null
        log_success "Created Service Principal for App ID: $APP_ID"
    else
        log_warning "Service Principal already exists for App ID: $APP_ID"
    fi
    
    export APP_ID
}

# Configure OIDC Federated Credentials
configure_oidc_federation() {
    log_info "Configuring OIDC Federated Credentials..."
    
    # Define federated credentials
    declare -A FEDERATED_CREDS=(
        ["GitHubMain"]="repo:${REPO_NAME}:ref:refs/heads/main"
        ["GitHubDevelop"]="repo:${REPO_NAME}:ref:refs/heads/develop"
        ["GitHubRelease"]="repo:${REPO_NAME}:ref:refs/heads/release/*"
        ["GitHubPullRequest"]="repo:${REPO_NAME}:pull_request"
    )
    
    for cred_name in "${!FEDERATED_CREDS[@]}"; do
        subject="${FEDERATED_CREDS[$cred_name]}"
        
        # Check if federated credential already exists
        if az ad app federated-credential list --id "$APP_ID" --query "[?name=='$cred_name']" -o tsv | grep -q "."; then
            log_warning "Federated credential '$cred_name' already exists"
        else
            # Create federated credential
            az ad app federated-credential create \
                --id "$APP_ID" \
                --parameters "{
                    \"name\": \"$cred_name\",
                    \"issuer\": \"https://token.actions.githubusercontent.com\",
                    \"subject\": \"$subject\",
                    \"audiences\": [\"api://AzureADTokenExchange\"]
                }" > /dev/null
            log_success "Created federated credential: $cred_name"
        fi
    done
}

# Assign Azure Container Registry permissions
configure_acr_permissions() {
    if [ -z "$ACR_NAME" ]; then
        log_warning "ACR_NAME not provided, skipping ACR permissions"
        return
    fi
    
    log_info "Configuring ACR permissions for: $ACR_NAME"
    
    # Get ACR resource ID
    ACR_RESOURCE_ID=$(az acr show --name "$ACR_NAME" --query id -o tsv 2>/dev/null)
    if [ -z "$ACR_RESOURCE_ID" ]; then
        log_error "ACR '$ACR_NAME' not found"
        return
    fi
    
    # Assign AcrPush role
    if az role assignment create \
        --assignee "$APP_ID" \
        --role "AcrPush" \
        --scope "$ACR_RESOURCE_ID" > /dev/null 2>&1; then
        log_success "Assigned AcrPush role to ACR: $ACR_NAME"
    else
        log_warning "AcrPush role assignment may already exist for ACR: $ACR_NAME"
    fi
}

# Assign AKS permissions
configure_aks_permissions() {
    log_info "Configuring AKS permissions..."
    
    # Function to assign AKS permissions for a specific cluster
    assign_aks_permissions() {
        local cluster_name=$1
        local env_name=$2
        
        if [ -z "$cluster_name" ]; then
            log_warning "AKS cluster name for $env_name not provided, skipping"
            return
        fi
        
        log_info "Configuring permissions for AKS cluster: $cluster_name ($env_name)"
        
        # Get AKS resource ID
        AKS_RESOURCE_ID=$(az aks show --name "$cluster_name" --resource-group "${cluster_name}-rg" --query id -o tsv 2>/dev/null)
        if [ -z "$AKS_RESOURCE_ID" ]; then
            # Try with different resource group patterns
            for rg_pattern in "${cluster_name}-rg" "rg-${cluster_name}" "aks-${env_name}" "${env_name}-aks"; do
                AKS_RESOURCE_ID=$(az aks show --name "$cluster_name" --resource-group "$rg_pattern" --query id -o tsv 2>/dev/null)
                if [ -n "$AKS_RESOURCE_ID" ]; then
                    break
                fi
            done
        fi
        
        if [ -z "$AKS_RESOURCE_ID" ]; then
            log_error "AKS cluster '$cluster_name' not found in any common resource group"
            return
        fi
        
        # Assign roles
        for role in "Azure Kubernetes Service Cluster User Role" "Azure Kubernetes Service RBAC Writer"; do
            if az role assignment create \
                --assignee "$APP_ID" \
                --role "$role" \
                --scope "$AKS_RESOURCE_ID" > /dev/null 2>&1; then
                log_success "Assigned '$role' to AKS: $cluster_name"
            else
                log_warning "Role assignment may already exist for AKS: $cluster_name"
            fi
        done
    }
    
    # Assign permissions for all environments
    assign_aks_permissions "$AKS_CLUSTER_NAME_DEV" "dev"
    assign_aks_permissions "$AKS_CLUSTER_NAME_STAGING" "staging"
    assign_aks_permissions "$AKS_CLUSTER_NAME_PROD" "prod"
}

# Assign Key Vault permissions
configure_keyvault_permissions() {
    log_info "Configuring Key Vault permissions..."
    
    # Function to assign Key Vault permissions
    assign_keyvault_permissions() {
        local keyvault_name=$1
        local env_name=$2
        
        if [ -z "$keyvault_name" ]; then
            log_warning "Key Vault name for $env_name not provided, skipping"
            return
        fi
        
        log_info "Configuring permissions for Key Vault: $keyvault_name ($env_name)"
        
        # Get Key Vault resource ID
        KV_RESOURCE_ID=$(az keyvault show --name "$keyvault_name" --query id -o tsv 2>/dev/null)
        if [ -z "$KV_RESOURCE_ID" ]; then
            log_error "Key Vault '$keyvault_name' not found"
            return
        fi
        
        # Assign Key Vault Secrets User role
        if az role assignment create \
            --assignee "$APP_ID" \
            --role "Key Vault Secrets User" \
            --scope "$KV_RESOURCE_ID" > /dev/null 2>&1; then
            log_success "Assigned Key Vault Secrets User role to: $keyvault_name"
        else
            log_warning "Key Vault role assignment may already exist for: $keyvault_name"
        fi
    }
    
    # Assign permissions for all environments
    assign_keyvault_permissions "$KEYVAULT_NAME_DEV" "dev"
    assign_keyvault_permissions "$KEYVAULT_NAME_STAGING" "staging"
    assign_keyvault_permissions "$KEYVAULT_NAME_PROD" "prod"
}

# Setup Azure Workload Identity for AKS
setup_workload_identity() {
    log_info "Setting up Azure Workload Identity..."
    
    setup_workload_identity_for_cluster() {
        local cluster_name=$1
        local env_name=$2
        
        if [ -z "$cluster_name" ]; then
            log_warning "AKS cluster name for $env_name not provided, skipping Workload Identity setup"
            return
        fi
        
        log_info "Setting up Workload Identity for: $cluster_name ($env_name)"
        
        # Find resource group for AKS cluster
        local resource_group=""
        for rg_pattern in "${cluster_name}-rg" "rg-${cluster_name}" "aks-${env_name}" "${env_name}-aks"; do
            if az aks show --name "$cluster_name" --resource-group "$rg_pattern" &> /dev/null; then
                resource_group="$rg_pattern"
                break
            fi
        done
        
        if [ -z "$resource_group" ]; then
            log_error "Could not find resource group for AKS cluster: $cluster_name"
            return
        fi
        
        # Enable OIDC Issuer and Workload Identity
        if az aks update \
            --resource-group "$resource_group" \
            --name "$cluster_name" \
            --enable-oidc-issuer \
            --enable-workload-identity > /dev/null 2>&1; then
            log_success "Enabled OIDC Issuer and Workload Identity for: $cluster_name"
        else
            log_warning "OIDC Issuer and Workload Identity may already be enabled for: $cluster_name"
        fi
        
        # Get OIDC Issuer URL
        OIDC_ISSUER=$(az aks show --resource-group "$resource_group" --name "$cluster_name" --query "oidcIssuerProfile.issuerUrl" -o tsv)
        if [ -n "$OIDC_ISSUER" ]; then
            log_success "OIDC Issuer URL for $cluster_name: $OIDC_ISSUER"
        fi
    }
    
    # Setup for all environments
    setup_workload_identity_for_cluster "$AKS_CLUSTER_NAME_DEV" "dev"
    setup_workload_identity_for_cluster "$AKS_CLUSTER_NAME_STAGING" "staging"
    setup_workload_identity_for_cluster "$AKS_CLUSTER_NAME_PROD" "prod"
}

# Generate GitHub repository configuration
generate_github_config() {
    log_info "Generating GitHub repository configuration..."
    
    cat > github-config.md << EOF
# GitHub Repository Configuration

## Repository Variables
Add these variables to your GitHub repository settings:

\`\`\`
AZURE_CLIENT_ID=$APP_ID
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AZURE_KEYVAULT_NAME_DEV=$KEYVAULT_NAME_DEV
AZURE_KEYVAULT_NAME_STAGING=$KEYVAULT_NAME_STAGING
AZURE_KEYVAULT_NAME_PROD=$KEYVAULT_NAME_PROD
\`\`\`

## Repository Secrets
Add these secrets to your GitHub repository settings:

\`\`\`
ACR_LOGIN_SERVER=${ACR_NAME}.azurecr.io
AKS_CLUSTER_NAME_DEV=$AKS_CLUSTER_NAME_DEV
AKS_RESOURCE_GROUP_DEV=${AKS_CLUSTER_NAME_DEV}-rg
AKS_CLUSTER_NAME_STAGING=$AKS_CLUSTER_NAME_STAGING
AKS_RESOURCE_GROUP_STAGING=${AKS_CLUSTER_NAME_STAGING}-rg
AKS_CLUSTER_NAME_PROD=$AKS_CLUSTER_NAME_PROD
AKS_RESOURCE_GROUP_PROD=${AKS_CLUSTER_NAME_PROD}-rg
\`\`\`

## Azure AD App Registration Details
- **Application ID (Client ID):** $APP_ID
- **Tenant ID:** $TENANT_ID
- **App Registration Name:** $APP_NAME

## Federated Credentials Configured
- Main branch: repo:${REPO_NAME}:ref:refs/heads/main
- Develop branch: repo:${REPO_NAME}:ref:refs/heads/develop
- Release branches: repo:${REPO_NAME}:ref:refs/heads/release/*
- Pull requests: repo:${REPO_NAME}:pull_request

EOF
    
    log_success "GitHub configuration saved to: github-config.md"
}

# Main execution
main() {
    log_info "Starting Azure Infrastructure Setup for GitHub Actions"
    echo "=================================================="
    
    check_prerequisites
    setup_config
    create_app_registration
    configure_oidc_federation
    configure_acr_permissions
    configure_aks_permissions
    configure_keyvault_permissions
    setup_workload_identity
    generate_github_config
    
    echo "=================================================="
    log_success "Azure Infrastructure Setup Complete!"
    log_info "Next steps:"
    log_info "1. Review and apply the GitHub configuration from: github-config.md"
    log_info "2. Test the setup using: ./scripts/azure-test.sh"
    log_info "3. Create Key Vault secrets using: ./scripts/keyvault-setup.sh"
}

# Help function
show_help() {
    cat << EOF
Azure Infrastructure Setup Script

Usage: $0 [OPTIONS]

Options:
    -h, --help                          Show this help message
    --repo-name REPO_NAME              GitHub repository (org/repo)
    --app-name APP_NAME                 Azure AD App name (default: GitHub-Actions-OIDC-REPO_NAME)
    --acr-name ACR_NAME                 Azure Container Registry name
    --aks-dev AKS_NAME                  AKS cluster name for dev
    --aks-staging AKS_NAME              AKS cluster name for staging
    --aks-prod AKS_NAME                 AKS cluster name for prod
    --kv-dev KV_NAME                    Key Vault name for dev
    --kv-staging KV_NAME                Key Vault name for staging
    --kv-prod KV_NAME                   Key Vault name for prod

Environment Variables:
    REPO_NAME                           GitHub repository (org/repo)
    ACR_NAME                            Azure Container Registry name
    AKS_CLUSTER_NAME_DEV               AKS cluster name for dev
    AKS_CLUSTER_NAME_STAGING           AKS cluster name for staging
    AKS_CLUSTER_NAME_PROD              AKS cluster name for prod
    KEYVAULT_NAME_DEV                  Key Vault name for dev
    KEYVAULT_NAME_STAGING              Key Vault name for staging
    KEYVAULT_NAME_PROD                 Key Vault name for prod

Examples:
    $0 --repo-name myorg/myrepo --acr-name myregistry --aks-dev dev-cluster
    REPO_NAME=myorg/myrepo ACR_NAME=myregistry $0
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --repo-name)
            REPO_NAME="$2"
            shift 2
            ;;
        --app-name)
            APP_NAME="$2"
            shift 2
            ;;
        --acr-name)
            ACR_NAME="$2"
            shift 2
            ;;
        --aks-dev)
            AKS_CLUSTER_NAME_DEV="$2"
            shift 2
            ;;
        --aks-staging)
            AKS_CLUSTER_NAME_STAGING="$2"
            shift 2
            ;;
        --aks-prod)
            AKS_CLUSTER_NAME_PROD="$2"
            shift 2
            ;;
        --kv-dev)
            KEYVAULT_NAME_DEV="$2"
            shift 2
            ;;
        --kv-staging)
            KEYVAULT_NAME_STAGING="$2"
            shift 2
            ;;
        --kv-prod)
            KEYVAULT_NAME_PROD="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main