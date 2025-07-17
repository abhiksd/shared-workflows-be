#!/bin/bash

# =============================================================================
# Azure Authentication Test Script
# =============================================================================
# This script tests Azure authentication, ACR access, AKS connectivity,
# and Key Vault permissions for the managed identity setup.
#
# Usage: ./test-azure-authentication.sh [environment]
# Example: ./test-azure-authentication.sh dev
#
# Prerequisites:
# - Azure CLI installed and configured
# - kubectl installed
# - jq installed for JSON parsing
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values (can be overridden by environment variables)
ENVIRONMENT="${1:-dev}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
TENANT_ID="${AZURE_TENANT_ID:-}"
CLIENT_ID="${AZURE_CLIENT_ID:-}"
ACR_NAME="${ACR_LOGIN_SERVER:-}"
KEYVAULT_NAME="${AZURE_KEYVAULT_NAME:-}"

# Environment-specific variables
case "$ENVIRONMENT" in
    "dev")
        AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME_DEV:-}"
        AKS_RESOURCE_GROUP="${AKS_RESOURCE_GROUP_DEV:-}"
        ;;
    "staging")
        AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME_STAGING:-}"
        AKS_RESOURCE_GROUP="${AKS_RESOURCE_GROUP_STAGING:-}"
        ;;
    "production"|"prod")
        AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME_PROD:-}"
        AKS_RESOURCE_GROUP="${AKS_RESOURCE_GROUP_PROD:-}"
        ENVIRONMENT="production"
        ;;
    *)
        echo -e "${RED}Error: Invalid environment. Use 'dev', 'staging', or 'production'${NC}"
        exit 1
        ;;
esac

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
    
    local missing_tools=()
    
    if ! command -v az &> /dev/null; then
        missing_tools+=("azure-cli")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

# Test Azure CLI authentication
test_azure_login() {
    log_info "Testing Azure CLI authentication..."
    
    if az account show &> /dev/null; then
        log_success "Already authenticated to Azure"
        
        current_subscription=$(az account show --query id -o tsv)
        if [ "$current_subscription" = "$SUBSCRIPTION_ID" ]; then
            log_success "Correct subscription is active: $SUBSCRIPTION_ID"
        else
            log_warning "Different subscription is active: $current_subscription"
            log_info "Setting subscription to: $SUBSCRIPTION_ID"
            az account set --subscription "$SUBSCRIPTION_ID"
        fi
    else
        log_error "Not authenticated to Azure. Please run 'az login' first."
        return 1
    fi
    
    log_info "Testing access token acquisition..."
    if token=$(az account get-access-token --query accessToken -o tsv 2>/dev/null); then
        log_success "Successfully acquired access token"
    else
        log_error "Failed to acquire access token"
        return 1
    fi
}

# Test ACR authentication and access
test_acr_access() {
    if [ -z "$ACR_NAME" ]; then
        log_warning "ACR_LOGIN_SERVER not set, skipping ACR tests"
        return 0
    fi
    
    log_info "Testing Azure Container Registry access..."
    
    local acr_registry_name
    acr_registry_name=$(echo "$ACR_NAME" | cut -d'.' -f1)
    
    log_info "Testing ACR login for: $acr_registry_name"
    if az acr login --name "$acr_registry_name" &> /dev/null; then
        log_success "Successfully logged into ACR: $acr_registry_name"
    else
        log_error "Failed to login to ACR: $acr_registry_name"
        return 1
    fi
    
    log_info "Testing repository listing..."
    if repositories=$(az acr repository list --name "$acr_registry_name" -o tsv 2>/dev/null); then
        log_success "Successfully listed repositories"
        if [ -n "$repositories" ]; then
            echo "Available repositories:"
            echo "$repositories" | head -5 | sed 's/^/  - /'
            [ $(echo "$repositories" | wc -l) -gt 5 ] && echo "  ... and more"
        else
            log_info "No repositories found in registry"
        fi
    else
        log_error "Failed to list repositories"
        return 1
    fi
}

# Test AKS authentication and access
test_aks_access() {
    if [ -z "$AKS_CLUSTER_NAME" ] || [ -z "$AKS_RESOURCE_GROUP" ]; then
        log_warning "AKS cluster name or resource group not set for $ENVIRONMENT, skipping AKS tests"
        return 0
    fi
    
    log_info "Testing AKS cluster access for environment: $ENVIRONMENT"
    log_info "Cluster: $AKS_CLUSTER_NAME in resource group: $AKS_RESOURCE_GROUP"
    
    log_info "Getting AKS cluster credentials..."
    if az aks get-credentials --resource-group "$AKS_RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" --overwrite-existing &> /dev/null; then
        log_success "Successfully acquired AKS cluster credentials"
    else
        log_error "Failed to acquire AKS cluster credentials"
        return 1
    fi
    
    log_info "Testing cluster connectivity..."
    if kubectl cluster-info &> /dev/null; then
        log_success "Successfully connected to AKS cluster"
    else
        log_error "Failed to connect to AKS cluster"
        return 1
    fi
}

# Test Key Vault access
test_keyvault_access() {
    if [ -z "$KEYVAULT_NAME" ]; then
        log_warning "AZURE_KEYVAULT_NAME not set, skipping Key Vault tests"
        return 0
    fi
    
    log_info "Testing Azure Key Vault access: $KEYVAULT_NAME"
    
    if kv_info=$(az keyvault show --name "$KEYVAULT_NAME" --query "{name:name,location:location}" -o json 2>/dev/null); then
        log_success "Successfully accessed Key Vault: $KEYVAULT_NAME"
    else
        log_error "Failed to access Key Vault: $KEYVAULT_NAME"
        return 1
    fi
    
    log_info "Testing secret listing permissions..."
    if secrets=$(az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "[].name" -o tsv 2>/dev/null); then
        log_success "Successfully listed secrets"
        if [ -n "$secrets" ]; then
            local secret_count=$(echo "$secrets" | wc -l)
            echo "  Found $secret_count secret(s)"
        else
            log_info "No secrets found in Key Vault"
        fi
    else
        log_error "Failed to list secrets"
        return 1
    fi
}

# Main execution
main() {
    echo "=================================================="
    echo "Azure Authentication Test Script"
    echo "Environment: $ENVIRONMENT"
    echo "=================================================="
    echo
    
    check_prerequisites
    test_azure_login
    echo
    test_acr_access
    echo
    test_aks_access
    echo
    test_keyvault_access
    echo
    
    log_success "All tests completed!"
}

# Run the script
main "$@"