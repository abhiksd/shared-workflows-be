#!/bin/bash

# Azure Key Vault Secret Setup Script
# This script helps create and manage Key Vault secrets for different environments

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to generate random password
generate_password() {
    local length=${1:-16}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Function to generate random UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        python3 -c "import uuid; print(uuid.uuid4())"
    fi
}

# Function to create or update a secret
create_secret() {
    local vault_name="$1"
    local secret_name="$2"
    local secret_value="$3"
    local description="$4"
    
    if [ -z "$vault_name" ] || [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
        log_error "Missing required parameters for secret creation"
        return 1
    fi
    
    log_info "Creating secret: $secret_name in $vault_name"
    
    # Check if secret already exists
    if az keyvault secret show --vault-name "$vault_name" --name "$secret_name" &> /dev/null; then
        read -p "Secret '$secret_name' already exists. Update it? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_warning "Skipping secret: $secret_name"
            return 0
        fi
    fi
    
    # Create or update the secret
    if az keyvault secret set \
        --vault-name "$vault_name" \
        --name "$secret_name" \
        --value "$secret_value" \
        --description "$description" > /dev/null 2>&1; then
        log_success "✅ Created/Updated secret: $secret_name"
        return 0
    else
        log_error "❌ Failed to create secret: $secret_name"
        return 1
    fi
}

# Function to setup secrets for a specific application and environment
setup_application_secrets() {
    local vault_name="$1"
    local app_name="$2"
    local environment="$3"
    local app_type="$4"
    
    log_info "Setting up secrets for $app_name in $environment environment"
    
    # Common secrets for all applications
    local secrets=(
        "${app_name}-${environment}-database-url|Database connection URL for ${app_name} ${environment}|postgresql://user:pass@host:5432/dbname"
        "${app_name}-${environment}-database-password|Database password for ${app_name} ${environment}|$(generate_password 24)"
        "${app_name}-${environment}-jwt-secret|JWT signing secret for ${app_name} ${environment}|$(generate_password 32)"
        "${app_name}-${environment}-api-key|API key for ${app_name} ${environment}|$(generate_password 40)"
        "${app_name}-${environment}-redis-url|Redis connection URL for ${app_name} ${environment}|redis://localhost:6379"
        "${app_name}-${environment}-storage-connection|Storage connection string for ${app_name} ${environment}|DefaultEndpointsProtocol=https;AccountName=storage;AccountKey=$(generate_password 44)"
    )
    
    # Application-specific secrets
    case "$app_type" in
        "java-springboot")
            secrets+=(
                "${app_name}-${environment}-datasource-username|Database username for ${app_name} ${environment}|app_user"
                "${app_name}-${environment}-encryption-key|Encryption key for ${app_name} ${environment}|$(generate_password 32)"
                "${app_name}-${environment}-oauth-client-secret|OAuth client secret for ${app_name} ${environment}|$(generate_password 48)"
                "${app_name}-${environment}-keystore-password|Keystore password for ${app_name} ${environment}|$(generate_password 16)"
            )
            ;;
        "nodejs")
            secrets+=(
                "${app_name}-${environment}-session-secret|Session secret for ${app_name} ${environment}|$(generate_password 32)"
                "${app_name}-${environment}-encryption-key|Encryption key for ${app_name} ${environment}|$(generate_password 32)"
                "${app_name}-${environment}-webhook-secret|Webhook secret for ${app_name} ${environment}|$(generate_password 24)"
                "${app_name}-${environment}-auth0-secret|Auth0 client secret for ${app_name} ${environment}|$(generate_password 48)"
            )
            ;;
    esac
    
    # Environment-specific secrets
    case "$environment" in
        "dev")
            secrets+=(
                "${app_name}-${environment}-debug-token|Debug access token for ${app_name} ${environment}|debug_$(generate_password 16)"
            )
            ;;
        "staging")
            secrets+=(
                "${app_name}-${environment}-test-api-key|Test API key for ${app_name} ${environment}|test_$(generate_password 32)"
            )
            ;;
        "production")
            secrets+=(
                "${app_name}-${environment}-monitoring-token|Monitoring token for ${app_name} ${environment}|$(generate_password 40)"
                "${app_name}-${environment}-backup-key|Backup encryption key for ${app_name} ${environment}|$(generate_password 32)"
            )
            ;;
    esac
    
    # Create all secrets
    local created=0
    local failed=0
    
    for secret_info in "${secrets[@]}"; do
        IFS='|' read -r secret_name description default_value <<< "$secret_info"
        
        # Prompt for custom value or use default
        echo ""
        log_info "Setting up secret: $secret_name"
        log_info "Description: $description"
        log_info "Default value: [Generated/Hidden]"
        
        if [[ "$INTERACTIVE" == "true" ]]; then
            read -p "Enter custom value (or press Enter for default): " custom_value
            if [ -n "$custom_value" ]; then
                secret_value="$custom_value"
            else
                secret_value="$default_value"
            fi
        else
            secret_value="$default_value"
        fi
        
        if create_secret "$vault_name" "$secret_name" "$secret_value" "$description"; then
            ((created++))
        else
            ((failed++))
        fi
    done
    
    log_info "Secrets setup summary for $app_name ($environment):"
    log_success "Created/Updated: $created secrets"
    if [ $failed -gt 0 ]; then
        log_error "Failed: $failed secrets"
    fi
}

# Function to setup common secrets
setup_common_secrets() {
    local vault_name="$1"
    local environment="$2"
    
    log_info "Setting up common secrets for $environment environment"
    
    # Common secrets shared across applications
    local common_secrets=(
        "common-${environment}-monitoring-api-key|Common monitoring API key for ${environment}|$(generate_password 40)"
        "common-${environment}-logging-endpoint|Common logging endpoint for ${environment}|https://logs.${environment}.yourdomain.com"
        "common-${environment}-external-service-token|External service token for ${environment}|$(generate_password 48)"
        "common-${environment}-smtp-password|SMTP password for ${environment}|$(generate_password 24)"
        "common-${environment}-ssl-certificate|SSL certificate for ${environment}|-----BEGIN CERTIFICATE-----"
        "common-${environment}-notification-webhook|Notification webhook URL for ${environment}|https://hooks.${environment}.yourdomain.com/webhook"
    )
    
    # Environment-specific common secrets
    case "$environment" in
        "dev")
            common_secrets+=(
                "common-${environment}-debug-endpoint|Debug endpoint for ${environment}|https://debug.${environment}.yourdomain.com"
            )
            ;;
        "staging")
            common_secrets+=(
                "common-${environment}-test-data-key|Test data access key for ${environment}|test_$(generate_password 32)"
            )
            ;;
        "production")
            common_secrets+=(
                "common-${environment}-backup-storage-key|Backup storage key for ${environment}|$(generate_password 44)"
                "common-${environment}-disaster-recovery-endpoint|Disaster recovery endpoint for ${environment}|https://dr.yourdomain.com"
            )
            ;;
    esac
    
    # Create common secrets
    local created=0
    local failed=0
    
    for secret_info in "${common_secrets[@]}"; do
        IFS='|' read -r secret_name description default_value <<< "$secret_info"
        
        if [[ "$INTERACTIVE" == "true" ]]; then
            echo ""
            log_info "Setting up common secret: $secret_name"
            log_info "Description: $description"
            read -p "Enter custom value (or press Enter for default): " custom_value
            if [ -n "$custom_value" ]; then
                secret_value="$custom_value"
            else
                secret_value="$default_value"
            fi
        else
            secret_value="$default_value"
        fi
        
        if create_secret "$vault_name" "$secret_name" "$secret_value" "$description"; then
            ((created++))
        else
            ((failed++))
        fi
    done
    
    log_info "Common secrets setup summary for $environment:"
    log_success "Created/Updated: $created secrets"
    if [ $failed -gt 0 ]; then
        log_error "Failed: $failed secrets"
    fi
}

# Function to list secrets in a Key Vault
list_secrets() {
    local vault_name="$1"
    local filter="$2"
    
    log_info "Listing secrets in Key Vault: $vault_name"
    if [ -n "$filter" ]; then
        log_info "Filter: $filter"
    fi
    
    # Get secrets list
    local secrets_json=$(az keyvault secret list --vault-name "$vault_name" --query "[].{Name:name,Created:attributes.created,Updated:attributes.updated}" -o json 2>/dev/null)
    
    if [ -z "$secrets_json" ] || [ "$secrets_json" = "[]" ]; then
        log_warning "No secrets found in Key Vault: $vault_name"
        return
    fi
    
    # Filter secrets if filter is provided
    if [ -n "$filter" ]; then
        secrets_json=$(echo "$secrets_json" | jq "[.[] | select(.Name | contains(\"$filter\"))]")
    fi
    
    # Display secrets
    echo "$secrets_json" | jq -r '.[] | "\(.Name) (Created: \(.Created) | Updated: \(.Updated))"' | while read -r line; do
        log_success "📄 $line"
    done
}

# Function to backup secrets
backup_secrets() {
    local vault_name="$1"
    local backup_file="$2"
    
    if [ -z "$backup_file" ]; then
        backup_file="keyvault-backup-$(date +%Y%m%d-%H%M%S).json"
    fi
    
    log_info "Backing up secrets from Key Vault: $vault_name"
    log_info "Backup file: $backup_file"
    
    # Get all secrets (names only for security)
    local secrets_list=$(az keyvault secret list --vault-name "$vault_name" --query "[].{Name:name,ContentType:contentType,Attributes:attributes}" -o json 2>/dev/null)
    
    if [ -z "$secrets_list" ] || [ "$secrets_list" = "[]" ]; then
        log_warning "No secrets found to backup"
        return
    fi
    
    # Save backup
    echo "$secrets_list" | jq '.' > "$backup_file"
    
    local secret_count=$(echo "$secrets_list" | jq length)
    log_success "✅ Backed up $secret_count secret metadata to: $backup_file"
    log_warning "⚠️ Secret values are not included in backup for security reasons"
}

# Function to generate environment template
generate_template() {
    local app_name="$1"
    local environment="$2"
    local app_type="$3"
    local template_file="secrets-template-${app_name}-${environment}.yaml"
    
    log_info "Generating secrets template for $app_name ($environment)"
    
    cat > "$template_file" << EOF
# Secrets Template for $app_name ($environment environment)
# Generated on: $(date)

application:
  name: $app_name
  type: $app_type
  environment: $environment

secrets:
  # Database secrets
  database:
    url: "\${${app_name^^}_${environment^^}_DATABASE_URL}"
    password: "\${${app_name^^}_${environment^^}_DATABASE_PASSWORD}"
    username: "\${${app_name^^}_${environment^^}_DATASOURCE_USERNAME}"

  # Authentication secrets
  auth:
    jwt_secret: "\${${app_name^^}_${environment^^}_JWT_SECRET}"
    api_key: "\${${app_name^^}_${environment^^}_API_KEY}"
    oauth_client_secret: "\${${app_name^^}_${environment^^}_OAUTH_CLIENT_SECRET}"

  # Infrastructure secrets
  infrastructure:
    redis_url: "\${${app_name^^}_${environment^^}_REDIS_URL}"
    storage_connection: "\${${app_name^^}_${environment^^}_STORAGE_CONNECTION}"

  # Common secrets
  common:
    monitoring_api_key: "\${COMMON_${environment^^}_MONITORING_API_KEY}"
    logging_endpoint: "\${COMMON_${environment^^}_LOGGING_ENDPOINT}"
    external_service_token: "\${COMMON_${environment^^}_EXTERNAL_SERVICE_TOKEN}"

EOF

    case "$app_type" in
        "java-springboot")
            cat >> "$template_file" << EOF
  # Java Spring Boot specific secrets
  java:
    encryption_key: "\${${app_name^^}_${environment^^}_ENCRYPTION_KEY}"
    keystore_password: "\${${app_name^^}_${environment^^}_KEYSTORE_PASSWORD}"

EOF
            ;;
        "nodejs")
            cat >> "$template_file" << EOF
  # Node.js specific secrets
  nodejs:
    session_secret: "\${${app_name^^}_${environment^^}_SESSION_SECRET}"
    webhook_secret: "\${${app_name^^}_${environment^^}_WEBHOOK_SECRET}"
    auth0_secret: "\${${app_name^^}_${environment^^}_AUTH0_SECRET}"

EOF
            ;;
    esac

    case "$environment" in
        "production")
            cat >> "$template_file" << EOF
  # Production specific secrets
  production:
    monitoring_token: "\${${app_name^^}_${environment^^}_MONITORING_TOKEN}"
    backup_key: "\${${app_name^^}_${environment^^}_BACKUP_KEY}"

EOF
            ;;
    esac

    log_success "✅ Generated template: $template_file"
}

# Main execution function
main() {
    local command="$1"
    shift
    
    case "$command" in
        "setup")
            setup_secrets "$@"
            ;;
        "list")
            list_secrets "$@"
            ;;
        "backup")
            backup_secrets "$@"
            ;;
        "template")
            generate_template "$@"
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Setup secrets function
setup_secrets() {
    local vault_name=""
    local app_name=""
    local environment=""
    local app_type=""
    local setup_common=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --vault)
                vault_name="$2"
                shift 2
                ;;
            --app)
                app_name="$2"
                shift 2
                ;;
            --env)
                environment="$2"
                shift 2
                ;;
            --type)
                app_type="$2"
                shift 2
                ;;
            --common)
                setup_common=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$vault_name" ]; then
        log_error "Key Vault name is required (--vault)"
        exit 1
    fi
    
    # Verify Key Vault exists
    if ! az keyvault show --name "$vault_name" &> /dev/null; then
        log_error "Key Vault '$vault_name' not found or not accessible"
        exit 1
    fi
    
    log_info "Setting up secrets in Key Vault: $vault_name"
    
    # Setup common secrets if requested
    if [ "$setup_common" = true ]; then
        if [ -z "$environment" ]; then
            log_error "Environment is required for common secrets setup (--env)"
            exit 1
        fi
        setup_common_secrets "$vault_name" "$environment"
    fi
    
    # Setup application secrets if app details provided
    if [ -n "$app_name" ] && [ -n "$environment" ] && [ -n "$app_type" ]; then
        setup_application_secrets "$vault_name" "$app_name" "$environment" "$app_type"
    elif [ -n "$app_name" ] || [ -n "$environment" ] || [ -n "$app_type" ]; then
        log_error "For application secrets, all of --app, --env, and --type are required"
        exit 1
    fi
    
    log_success "✅ Secrets setup completed for Key Vault: $vault_name"
}

# Help function
show_help() {
    cat << EOF
Azure Key Vault Secret Setup Script

Usage: $0 COMMAND [OPTIONS]

Commands:
    setup                               Setup secrets in Key Vault
    list VAULT_NAME [FILTER]           List secrets in Key Vault
    backup VAULT_NAME [FILE]           Backup secret metadata
    template APP_NAME ENV TYPE         Generate secrets template

Setup Options:
    --vault VAULT_NAME                  Key Vault name (required)
    --app APP_NAME                      Application name
    --env ENVIRONMENT                   Environment (dev, staging, production)
    --type APP_TYPE                     Application type (java-springboot, nodejs)
    --common                           Setup common secrets for environment
    --interactive                      Interactive mode for custom values

Examples:
    # Setup application secrets
    $0 setup --vault myvault --app java-app --env dev --type java-springboot

    # Setup common secrets for an environment
    $0 setup --vault myvault --env production --common

    # Setup both application and common secrets
    $0 setup --vault myvault --app nodejs-app --env staging --type nodejs --common

    # Interactive setup
    $0 setup --vault myvault --app java-app --env dev --type java-springboot --interactive

    # List all secrets
    $0 list myvault

    # List secrets with filter
    $0 list myvault java-app-dev

    # Backup secrets metadata
    $0 backup myvault my-backup.json

    # Generate template
    $0 template java-app production java-springboot

Prerequisites:
    - Azure CLI installed and logged in
    - Appropriate Key Vault permissions (Key Vault Secrets Officer or Contributor)
    - jq installed (for JSON processing)

Secret Naming Convention:
    Application secrets: {app-name}-{environment}-{secret-type}
    Common secrets: common-{environment}-{secret-type}
EOF
}

# Check if command is provided
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Set default interactive mode
INTERACTIVE=${INTERACTIVE:-false}

# Run prerequisites check
check_prerequisites

# Execute main function with all arguments
main "$@"