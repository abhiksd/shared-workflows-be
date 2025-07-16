#!/bin/bash

# Azure Key Vault Secret Management Script
# This script helps manage application secrets in Azure Key Vault

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to show usage
show_usage() {
    cat << EOF
Azure Key Vault Secret Management Script

Usage: $0 <command> [options]

Commands:
    add-app-secrets     Add secrets for an application environment
    list-app-secrets    List secrets for an application environment
    update-secret       Update a specific secret
    delete-secret       Delete a specific secret
    generate-secrets    Generate random secrets for an application
    export-secrets      Export secrets to environment file
    verify-access       Verify Key Vault access

Options:
    -k, --keyvault      Key Vault name (required)
    -a, --app-name      Application name (required for app commands)
    -e, --environment   Environment (dev, staging, production)
    -s, --secret-name   Secret name (for update/delete commands)
    -v, --secret-value  Secret value (for update command)
    -f, --file          File path (for export command)
    -h, --help          Show this help message

Examples:
    $0 add-app-secrets -k mykeyvault -a java-app -e dev
    $0 list-app-secrets -k mykeyvault -a java-app -e dev
    $0 update-secret -k mykeyvault -s java-app-dev-db-password -v newpassword
    $0 generate-secrets -k mykeyvault -a nodejs-app -e staging
    $0 export-secrets -k mykeyvault -a java-app -e dev -f .env.dev

Environment Variables (optional):
    KEYVAULT_NAME       Default Key Vault name
    APPLICATION_NAME    Default application name
    ENVIRONMENT         Default environment

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if Azure CLI is available
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install Azure CLI first."
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to verify Key Vault access
verify_keyvault_access() {
    local keyvault_name=$1
    
    print_info "Verifying access to Key Vault: $keyvault_name"
    
    if az keyvault secret list --vault-name "$keyvault_name" --query "[0].name" -o tsv &> /dev/null; then
        print_success "Successfully accessed Key Vault: $keyvault_name"
        return 0
    else
        print_error "Failed to access Key Vault: $keyvault_name"
        print_error "Required permission: Key Vault Secrets User role"
        return 1
    fi
}

# Function to generate random password
generate_random_password() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Function to add application secrets
add_app_secrets() {
    local keyvault_name=$1
    local app_name=$2
    local environment=$3
    
    print_info "Adding secrets for $app_name in $environment environment"
    
    # Database secrets
    print_info "Adding database secrets..."
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-db-username" --value "${app_name}_user" > /dev/null
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-db-password" --value "$(generate_random_password 16)" > /dev/null
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-db-host" --value "${environment}-postgres.database.azure.com" > /dev/null
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-db-port" --value "5432" > /dev/null
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-db-name" --value "${app_name}_${environment}" > /dev/null
    
    # Application secrets
    print_info "Adding application secrets..."
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-jwt-secret" --value "$(generate_random_password 64)" > /dev/null
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-encryption-key" --value "$(generate_random_password 32)" > /dev/null
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-api-key" --value "$(generate_random_password 32)" > /dev/null
    
    # External API secrets (placeholders)
    print_info "Adding external API secrets (placeholders)..."
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-external-api-url" --value "https://api.example.com" > /dev/null
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-external-api-token" --value "placeholder-token-$(generate_random_password 16)" > /dev/null
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-webhook-secret" --value "$(generate_random_password 32)" > /dev/null
    
    # Storage secrets (placeholders)
    print_info "Adding storage secrets (placeholders)..."
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-storage-account-key" --value "placeholder-storage-key-$(generate_random_password 24)" > /dev/null
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-storage-connection-string" --value "DefaultEndpointsProtocol=https;AccountName=${app_name}${environment}storage;AccountKey=placeholder" > /dev/null
    
    # Messaging secrets (placeholders)
    print_info "Adding messaging secrets (placeholders)..."
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-redis-connection-string" --value "${environment}-redis.redis.cache.windows.net:6380,password=placeholder,ssl=True,abortConnect=False" > /dev/null
    
    # Monitoring secrets (placeholders)
    print_info "Adding monitoring secrets (placeholders)..."
    az keyvault secret set --vault-name "$keyvault_name" --name "${app_name}-${environment}-appinsights-key" --value "placeholder-appinsights-key-$(generate_random_password 24)" > /dev/null
    
    print_success "Successfully added secrets for $app_name in $environment environment"
    print_warning "Remember to update placeholder values with actual credentials!"
}

# Function to list application secrets
list_app_secrets() {
    local keyvault_name=$1
    local app_name=$2
    local environment=$3
    
    print_info "Listing secrets for $app_name in $environment environment"
    
    local prefix="${app_name}-${environment}-"
    local secrets=$(az keyvault secret list --vault-name "$keyvault_name" --query "[?starts_with(name, '${prefix}')].{Name:name, Updated:attributes.updated, Enabled:attributes.enabled}" -o table)
    
    if [ -n "$secrets" ]; then
        echo "$secrets"
    else
        print_warning "No secrets found for $app_name in $environment environment"
    fi
}

# Function to update a secret
update_secret() {
    local keyvault_name=$1
    local secret_name=$2
    local secret_value=$3
    
    print_info "Updating secret: $secret_name"
    
    if az keyvault secret set --vault-name "$keyvault_name" --name "$secret_name" --value "$secret_value" > /dev/null; then
        print_success "Successfully updated secret: $secret_name"
    else
        print_error "Failed to update secret: $secret_name"
        return 1
    fi
}

# Function to delete a secret
delete_secret() {
    local keyvault_name=$1
    local secret_name=$2
    
    print_warning "Deleting secret: $secret_name"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if az keyvault secret delete --vault-name "$keyvault_name" --name "$secret_name" > /dev/null; then
            print_success "Successfully deleted secret: $secret_name"
        else
            print_error "Failed to delete secret: $secret_name"
            return 1
        fi
    else
        print_info "Secret deletion cancelled"
    fi
}

# Function to generate secrets with random values
generate_secrets() {
    local keyvault_name=$1
    local app_name=$2
    local environment=$3
    
    print_info "Generating random secrets for $app_name in $environment environment"
    
    # List of secrets that should have random values
    declare -a secret_types=(
        "db-password"
        "jwt-secret"
        "encryption-key"
        "api-key"
        "webhook-secret"
    )
    
    for secret_type in "${secret_types[@]}"; do
        local secret_name="${app_name}-${environment}-${secret_type}"
        local secret_value
        
        case $secret_type in
            "jwt-secret")
                secret_value=$(generate_random_password 64)
                ;;
            "db-password")
                secret_value=$(generate_random_password 16)
                ;;
            *)
                secret_value=$(generate_random_password 32)
                ;;
        esac
        
        if az keyvault secret set --vault-name "$keyvault_name" --name "$secret_name" --value "$secret_value" > /dev/null; then
            print_success "Generated: $secret_name"
        else
            print_error "Failed to generate: $secret_name"
        fi
    done
}

# Function to export secrets to environment file
export_secrets() {
    local keyvault_name=$1
    local app_name=$2
    local environment=$3
    local output_file=$4
    
    print_info "Exporting secrets for $app_name in $environment environment to $output_file"
    
    local prefix="${app_name}-${environment}-"
    local secret_names=$(az keyvault secret list --vault-name "$keyvault_name" --query "[?starts_with(name, '${prefix}')].name" -o tsv)
    
    if [ -z "$secret_names" ]; then
        print_warning "No secrets found for $app_name in $environment environment"
        return 1
    fi
    
    # Create output file
    > "$output_file"
    echo "# Secrets for $app_name in $environment environment" >> "$output_file"
    echo "# Generated on $(date)" >> "$output_file"
    echo "" >> "$output_file"
    
    while read -r secret_name; do
        if [ -n "$secret_name" ]; then
            local env_var_name=$(echo "$secret_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
            local secret_value=$(az keyvault secret show --vault-name "$keyvault_name" --name "$secret_name" --query "value" -o tsv)
            
            if [ -n "$secret_value" ] && [ "$secret_value" != "null" ]; then
                echo "${env_var_name}=${secret_value}" >> "$output_file"
                print_success "Exported: $secret_name -> $env_var_name"
            else
                print_warning "Empty or null value for: $secret_name"
            fi
        fi
    done <<< "$secret_names"
    
    print_success "Secrets exported to: $output_file"
    print_warning "Ensure this file is not committed to version control!"
}

# Parse command line arguments
COMMAND=""
KEYVAULT_NAME="${KEYVAULT_NAME:-}"
APP_NAME="${APPLICATION_NAME:-}"
ENVIRONMENT="${ENVIRONMENT:-}"
SECRET_NAME=""
SECRET_VALUE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        add-app-secrets|list-app-secrets|update-secret|delete-secret|generate-secrets|export-secrets|verify-access)
            COMMAND=$1
            shift
            ;;
        -k|--keyvault)
            KEYVAULT_NAME="$2"
            shift 2
            ;;
        -a|--app-name)
            APP_NAME="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -s|--secret-name)
            SECRET_NAME="$2"
            shift 2
            ;;
        -v|--secret-value)
            SECRET_VALUE="$2"
            shift 2
            ;;
        -f|--file)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$COMMAND" ]; then
    print_error "Command is required"
    show_usage
    exit 1
fi

if [ -z "$KEYVAULT_NAME" ]; then
    print_error "Key Vault name is required (-k or KEYVAULT_NAME environment variable)"
    exit 1
fi

# Check prerequisites
check_prerequisites

# Verify Key Vault access
if ! verify_keyvault_access "$KEYVAULT_NAME"; then
    exit 1
fi

# Execute command
case $COMMAND in
    add-app-secrets)
        if [ -z "$APP_NAME" ] || [ -z "$ENVIRONMENT" ]; then
            print_error "Application name and environment are required for this command"
            exit 1
        fi
        add_app_secrets "$KEYVAULT_NAME" "$APP_NAME" "$ENVIRONMENT"
        ;;
    list-app-secrets)
        if [ -z "$APP_NAME" ] || [ -z "$ENVIRONMENT" ]; then
            print_error "Application name and environment are required for this command"
            exit 1
        fi
        list_app_secrets "$KEYVAULT_NAME" "$APP_NAME" "$ENVIRONMENT"
        ;;
    update-secret)
        if [ -z "$SECRET_NAME" ] || [ -z "$SECRET_VALUE" ]; then
            print_error "Secret name and value are required for this command"
            exit 1
        fi
        update_secret "$KEYVAULT_NAME" "$SECRET_NAME" "$SECRET_VALUE"
        ;;
    delete-secret)
        if [ -z "$SECRET_NAME" ]; then
            print_error "Secret name is required for this command"
            exit 1
        fi
        delete_secret "$KEYVAULT_NAME" "$SECRET_NAME"
        ;;
    generate-secrets)
        if [ -z "$APP_NAME" ] || [ -z "$ENVIRONMENT" ]; then
            print_error "Application name and environment are required for this command"
            exit 1
        fi
        generate_secrets "$KEYVAULT_NAME" "$APP_NAME" "$ENVIRONMENT"
        ;;
    export-secrets)
        if [ -z "$APP_NAME" ] || [ -z "$ENVIRONMENT" ] || [ -z "$OUTPUT_FILE" ]; then
            print_error "Application name, environment, and output file are required for this command"
            exit 1
        fi
        export_secrets "$KEYVAULT_NAME" "$APP_NAME" "$ENVIRONMENT" "$OUTPUT_FILE"
        ;;
    verify-access)
        print_success "Key Vault access verified successfully"
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac