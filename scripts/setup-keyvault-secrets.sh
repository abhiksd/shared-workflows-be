#!/bin/bash

# =============================================================================
# Azure Key Vault Secrets Setup Script
# =============================================================================
# This script helps create and manage secrets in Azure Key Vault for
# different environments and applications.
#
# Usage: ./setup-keyvault-secrets.sh <environment> <keyvault-name> [application]
# Example: ./setup-keyvault-secrets.sh dev my-keyvault-dev java-app
#
# Prerequisites:
# - Azure CLI installed and authenticated
# - Appropriate permissions on the Key Vault
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Input parameters
ENVIRONMENT="${1:-}"
KEYVAULT_NAME="${2:-}"
APPLICATION="${3:-}"

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
    echo "Usage: $0 <environment> <keyvault-name> [application]"
    echo ""
    echo "Parameters:"
    echo "  environment    - Target environment (dev, staging, production)"
    echo "  keyvault-name  - Azure Key Vault name"
    echo "  application    - Optional: specific application (java-app, nodejs-app)"
    echo ""
    echo "Examples:"
    echo "  $0 dev my-keyvault-dev"
    echo "  $0 staging my-keyvault-staging java-app"
    echo "  $0 production my-keyvault-prod nodejs-app"
    echo ""
    echo "Environment Variables (optional):"
    echo "  SKIP_CONFIRMATION=true  - Skip confirmation prompts"
    echo "  DRY_RUN=true           - Show what would be created without creating"
}

# Validate inputs
validate_inputs() {
    if [ -z "$ENVIRONMENT" ] || [ -z "$KEYVAULT_NAME" ]; then
        log_error "Missing required parameters"
        show_usage
        exit 1
    fi
    
    case "$ENVIRONMENT" in
        "dev"|"staging"|"production")
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT"
            echo "Valid environments: dev, staging, production"
            exit 1
            ;;
    esac
}

# Check if Azure CLI is authenticated
check_azure_auth() {
    log_info "Checking Azure authentication..."
    
    if ! az account show &> /dev/null; then
        log_error "Not authenticated to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check Key Vault access
    if ! az keyvault show --name "$KEYVAULT_NAME" &> /dev/null; then
        log_error "Cannot access Key Vault: $KEYVAULT_NAME"
        echo "Please ensure:"
        echo "1. The Key Vault exists"
        echo "2. You have appropriate permissions"
        echo "3. The Key Vault name is correct"
        exit 1
    fi
    
    log_success "Azure authentication and Key Vault access verified"
}

# Generate a secure random value
generate_secure_value() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Create or update a secret
create_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="$3"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY RUN] Would create secret: $secret_name"
        return 0
    fi
    
    # Check if secret already exists
    if az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$secret_name" &> /dev/null; then
        log_warning "Secret '$secret_name' already exists"
        
        if [ "${SKIP_CONFIRMATION:-false}" != "true" ]; then
            read -p "Do you want to update it? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Skipping secret: $secret_name"
                return 0
            fi
        fi
    fi
    
    log_info "Creating secret: $secret_name"
    
    if az keyvault secret set \
        --vault-name "$KEYVAULT_NAME" \
        --name "$secret_name" \
        --value "$secret_value" \
        --description "$description" \
        --output none; then
        log_success "Created secret: $secret_name"
    else
        log_error "Failed to create secret: $secret_name"
        return 1
    fi
}

# Create application-specific secrets
create_application_secrets() {
    local app_name="$1"
    
    log_info "Creating secrets for application: $app_name"
    
    # Database secrets
    create_secret \
        "${app_name}-${ENVIRONMENT}-database-url" \
        "Server=tcp:${app_name}-${ENVIRONMENT}-db.database.windows.net,1433;Database=${app_name}${ENVIRONMENT}db;User ID=${app_name}admin;Password=REPLACE_WITH_ACTUAL_PASSWORD;Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;" \
        "Database connection string for ${app_name} in ${ENVIRONMENT}"
    
    create_secret \
        "${app_name}-${ENVIRONMENT}-database-password" \
        "$(generate_secure_value 24)" \
        "Database password for ${app_name} in ${ENVIRONMENT}"
    
    # JWT secret
    create_secret \
        "${app_name}-${ENVIRONMENT}-jwt-secret" \
        "$(generate_secure_value 64)" \
        "JWT signing secret for ${app_name} in ${ENVIRONMENT}"
    
    # API key
    create_secret \
        "${app_name}-${ENVIRONMENT}-api-key" \
        "$(generate_secure_value 32)" \
        "API key for ${app_name} in ${ENVIRONMENT}"
    
    # Redis connection
    create_secret \
        "${app_name}-${ENVIRONMENT}-redis-url" \
        "${app_name}-${ENVIRONMENT}-redis.redis.cache.windows.net:6380,password=REPLACE_WITH_ACTUAL_PASSWORD,ssl=True,abortConnect=False" \
        "Redis connection string for ${app_name} in ${ENVIRONMENT}"
    
    # Storage connection
    create_secret \
        "${app_name}-${ENVIRONMENT}-storage-connection" \
        "DefaultEndpointsProtocol=https;AccountName=${app_name}${ENVIRONMENT}storage;AccountKey=REPLACE_WITH_ACTUAL_KEY;EndpointSuffix=core.windows.net" \
        "Storage account connection string for ${app_name} in ${ENVIRONMENT}"
    
    # Application-specific secrets based on type
    if [[ "$app_name" == "java-app" ]]; then
        create_secret \
            "${app_name}-${ENVIRONMENT}-spring-datasource-password" \
            "$(generate_secure_value 24)" \
            "Spring datasource password for ${app_name} in ${ENVIRONMENT}"
        
        create_secret \
            "${app_name}-${ENVIRONMENT}-actuator-password" \
            "$(generate_secure_value 16)" \
            "Spring Actuator password for ${app_name} in ${ENVIRONMENT}"
    fi
    
    if [[ "$app_name" == "nodejs-app" ]]; then
        create_secret \
            "${app_name}-${ENVIRONMENT}-session-secret" \
            "$(generate_secure_value 32)" \
            "Session secret for ${app_name} in ${ENVIRONMENT}"
        
        create_secret \
            "${app_name}-${ENVIRONMENT}-cookie-secret" \
            "$(generate_secure_value 32)" \
            "Cookie signing secret for ${app_name} in ${ENVIRONMENT}"
    fi
}

# Create common secrets shared across applications
create_common_secrets() {
    log_info "Creating common secrets for environment: $ENVIRONMENT"
    
    # Monitoring
    create_secret \
        "common-${ENVIRONMENT}-monitoring-api-key" \
        "$(generate_secure_value 32)" \
        "Monitoring service API key for ${ENVIRONMENT}"
    
    # Logging
    create_secret \
        "common-${ENVIRONMENT}-logging-endpoint" \
        "https://logs-${ENVIRONMENT}.yourdomain.com/api/v1/logs" \
        "Centralized logging endpoint for ${ENVIRONMENT}"
    
    # External service token
    create_secret \
        "common-${ENVIRONMENT}-external-service-token" \
        "$(generate_secure_value 48)" \
        "External service authentication token for ${ENVIRONMENT}"
    
    # Notification service
    create_secret \
        "common-${ENVIRONMENT}-notification-webhook" \
        "https://hooks.slack.com/services/REPLACE/WITH/ACTUAL/WEBHOOK" \
        "Notification webhook URL for ${ENVIRONMENT}"
    
    # Certificate passwords (if needed)
    create_secret \
        "common-${ENVIRONMENT}-cert-password" \
        "$(generate_secure_value 24)" \
        "Certificate password for ${ENVIRONMENT}"
}

# List created secrets
list_created_secrets() {
    log_info "Listing secrets in Key Vault: $KEYVAULT_NAME"
    
    local pattern=""
    if [ -n "$APPLICATION" ]; then
        pattern="${APPLICATION}-${ENVIRONMENT}-"
    else
        pattern="${ENVIRONMENT}-"
    fi
    
    # Get all secrets and filter by pattern
    local secrets
    if secrets=$(az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "[?contains(name, '${pattern}')].{Name:name,Created:attributes.created}" -o table 2>/dev/null); then
        echo "$secrets"
    else
        log_warning "Could not list secrets (may have limited permissions)"
    fi
}

# Generate script for GitHub Actions secrets
generate_github_secrets_script() {
    local script_file="github-secrets-${ENVIRONMENT}.sh"
    
    log_info "Generating GitHub Actions secrets script: $script_file"
    
    cat > "$script_file" << EOF
#!/bin/bash
# GitHub Actions Secrets Setup Script
# Generated for environment: $ENVIRONMENT
# Key Vault: $KEYVAULT_NAME

# Set these as GitHub repository secrets:
echo "Setting GitHub repository secrets for $ENVIRONMENT environment..."

# Required for all applications
gh secret set ACR_LOGIN_SERVER --body "your-registry.azurecr.io"
gh secret set AKS_CLUSTER_NAME_${ENVIRONMENT^^} --body "your-aks-cluster-${ENVIRONMENT}"
gh secret set AKS_RESOURCE_GROUP_${ENVIRONMENT^^} --body "your-resource-group-${ENVIRONMENT}"

# Set these as GitHub repository variables:
echo "Setting GitHub repository variables..."
gh variable set AZURE_CLIENT_ID --body "your-app-registration-client-id"
gh variable set AZURE_TENANT_ID --body "your-tenant-id"
gh variable set AZURE_SUBSCRIPTION_ID --body "your-subscription-id"
gh variable set AZURE_KEYVAULT_NAME --body "$KEYVAULT_NAME"

echo "GitHub secrets and variables setup completed!"
echo "Note: Replace placeholder values with actual values from your Azure resources."
EOF
    
    chmod +x "$script_file"
    log_success "GitHub secrets script created: $script_file"
}

# Main execution
main() {
    echo "=================================================="
    echo "Azure Key Vault Secrets Setup"
    echo "Environment: $ENVIRONMENT"
    echo "Key Vault: $KEYVAULT_NAME"
    [ -n "$APPLICATION" ] && echo "Application: $APPLICATION"
    echo "=================================================="
    echo
    
    validate_inputs
    check_azure_auth
    
    # Confirmation prompt
    if [ "${SKIP_CONFIRMATION:-false}" != "true" ] && [ "${DRY_RUN:-false}" != "true" ]; then
        echo "This script will create secrets in Key Vault: $KEYVAULT_NAME"
        echo "Environment: $ENVIRONMENT"
        [ -n "$APPLICATION" ] && echo "Application: $APPLICATION"
        echo
        read -p "Do you want to continue? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled by user"
            exit 0
        fi
    fi
    
    echo
    
    # Create secrets
    if [ -n "$APPLICATION" ]; then
        create_application_secrets "$APPLICATION"
    else
        # Create secrets for all known applications
        for app in "java-app" "nodejs-app"; do
            create_application_secrets "$app"
            echo
        done
        
        # Create common secrets
        create_common_secrets
    fi
    
    echo
    log_success "Secret creation completed!"
    echo
    
    # List created secrets
    list_created_secrets
    echo
    
    # Generate GitHub secrets script
    generate_github_secrets_script
    
    echo
    echo "=================================================="
    echo "Next Steps:"
    echo "1. Review and update placeholder values in the secrets"
    echo "2. Run the generated GitHub secrets script"
    echo "3. Test the deployment workflows"
    echo "=================================================="
}

# Check for help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_usage
    exit 0
fi

# Run the script
main "$@"