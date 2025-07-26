#!/bin/bash
# 🔐 Azure Key Vault Secrets Creation Script
# Creates secrets in Azure Key Vault for different environments

set -e

KEYVAULT_NAME=""
ENVIRONMENT=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo -e "${BLUE}🔐 Azure Key Vault Secrets Creation Script${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo ""
    echo "Usage: $0 -v <keyvault-name> -e <environment>"
    echo ""
    echo "Parameters:"
    echo "  -v: Key Vault name (e.g., kv-java-backend1-prod)"
    echo "  -e: Environment (sqe|ppr|prod)"
    echo "  -h: Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -v kv-java-backend1-sqe -e sqe"
    echo "  $0 -v kv-java-backend1-prod -e prod"
    echo ""
    exit 1
}

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to log warnings
warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

# Function to log errors
error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# Parse command line arguments
while getopts "v:e:h" opt; do
    case $opt in
        v) KEYVAULT_NAME="$OPTARG" ;;
        e) ENVIRONMENT="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [[ -z "$KEYVAULT_NAME" || -z "$ENVIRONMENT" ]]; then
    error "Missing required parameters"
    usage
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(sqe|ppr|prod)$ ]]; then
    error "Invalid environment. Must be: sqe, ppr, or prod"
    exit 1
fi

log "🔐 Creating secrets for $ENVIRONMENT environment in $KEYVAULT_NAME"
echo ""

# Check if Azure CLI is logged in
if ! az account show >/dev/null 2>&1; then
    error "Azure CLI not logged in. Please run 'az login' first."
    exit 1
fi

# Check if Key Vault exists
if ! az keyvault show --name "$KEYVAULT_NAME" >/dev/null 2>&1; then
    error "Key Vault '$KEYVAULT_NAME' does not exist or you don't have access to it."
    exit 1
fi

log "✅ Key Vault '$KEYVAULT_NAME' found and accessible"

# Function to create secret with validation
create_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="$3"
    
    if [[ -z "$secret_value" ]]; then
        warn "Empty value provided for $secret_name, skipping..."
        return
    fi
    
    log "Creating secret: $secret_name"
    if az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "$secret_name" --value "$secret_value" --description "$description" >/dev/null 2>&1; then
        log "✅ Secret '$secret_name' created successfully"
    else
        error "Failed to create secret '$secret_name'"
        exit 1
    fi
}

echo "📝 Please provide the following secrets for $ENVIRONMENT environment:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Common secrets for all environments (sqe, ppr, prod)
echo "🗄️  Database Configuration:"
read -s -p "  MongoDB connection string: " MONGODB_CONN
echo
read -s -p "  Redis password: " REDIS_PASS
echo
echo ""

echo "🔑 Application Security:"
read -s -p "  JWT secret key: " JWT_SECRET
echo
read -s -p "  API key: " API_KEY
echo
echo ""

# Environment-specific secrets
if [[ "$ENVIRONMENT" == "ppr" || "$ENVIRONMENT" == "prod" ]]; then
    echo "💾 Cache Configuration:"
    read -s -p "  Memcached servers (comma-separated): " MEMCACHED_SERVERS
    echo
    echo ""
    
    echo "📊 Monitoring & Analytics:"
    read -s -p "  Application Insights instrumentation key: " APP_INSIGHTS_KEY
    echo
    echo ""
    
    echo "🔐 OAuth2 Configuration:"
    read -s -p "  OAuth2 client secret: " OAUTH2_SECRET
    echo
    echo ""
fi

# Production-only secrets
if [[ "$ENVIRONMENT" == "prod" ]]; then
    echo "🌐 External Services:"
    read -s -p "  External service API key: " EXT_API_KEY
    echo
    echo ""
fi

echo ""
log "🚀 Starting secret creation process..."
echo ""

# Create common secrets
create_secret "mongodb-connection-string" "$MONGODB_CONN" "MongoDB database connection string for $ENVIRONMENT"
create_secret "redis-password" "$REDIS_PASS" "Redis cache password for $ENVIRONMENT"
create_secret "jwt-secret" "$JWT_SECRET" "JWT token signing secret for $ENVIRONMENT"
create_secret "api-key" "$API_KEY" "Application API key for $ENVIRONMENT"

# Create environment-specific secrets
if [[ "$ENVIRONMENT" == "ppr" || "$ENVIRONMENT" == "prod" ]]; then
    create_secret "memcached-servers" "$MEMCACHED_SERVERS" "Memcached server configuration for $ENVIRONMENT"
    create_secret "application-insights-key" "$APP_INSIGHTS_KEY" "Application Insights instrumentation key for $ENVIRONMENT"
    create_secret "oauth2-client-secret" "$OAUTH2_SECRET" "OAuth2 client secret for $ENVIRONMENT"
fi

# Create production-only secrets
if [[ "$ENVIRONMENT" == "prod" ]]; then
    create_secret "external-service-api-key" "$EXT_API_KEY" "External service API key for $ENVIRONMENT"
fi

echo ""
log "✅ All secrets created successfully in $KEYVAULT_NAME"

# List created secrets
echo ""
log "📋 Summary of created secrets:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "[].{Name:name, Enabled:attributes.enabled, Created:attributes.created}" -o table

echo ""
log "🎯 Secret creation completed for $ENVIRONMENT environment"
log "🔄 Next steps:"
echo "   1. Verify secrets in Azure Portal"
echo "   2. Update Helm values with Key Vault configuration"
echo "   3. Deploy application to test secret integration"
echo "   4. Monitor Key Vault access logs"

echo ""
warn "🔒 Security reminder:"
echo "   - These secrets are now stored securely in Azure Key Vault"
echo "   - Ensure proper RBAC permissions are configured"
echo "   - Regularly rotate secrets according to security policy"
echo "   - Monitor Key Vault access logs for unauthorized access"