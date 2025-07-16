#!/bin/bash

# Azure Managed Identity Verification Script
# This script helps verify that managed identity authentication is properly configured

set -e

echo "🔍 Azure Managed Identity Verification"
echo "======================================"

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install Azure CLI first."
    exit 1
fi

echo "✅ Azure CLI is available"

# Check if already logged in with managed identity
echo ""
echo "🔐 Checking Azure authentication..."
if az account show &> /dev/null; then
    ACCOUNT_INFO=$(az account show --query "{subscriptionId:id, subscriptionName:name, user:user.name, type:user.type}" -o table)
    echo "✅ Already authenticated with Azure:"
    echo "$ACCOUNT_INFO"
    
    # Check if using managed identity
    USER_TYPE=$(az account show --query "user.type" -o tsv)
    if [ "$USER_TYPE" = "servicePrincipal" ]; then
        echo "✅ Using Service Principal authentication"
        
        # Try to determine if it's managed identity
        USER_NAME=$(az account show --query "user.name" -o tsv)
        if [[ "$USER_NAME" == *"msi"* ]] || [[ "$USER_NAME" == *"managedIdentity"* ]]; then
            echo "✅ Detected Managed Identity authentication"
        else
            echo "⚠️  Service Principal detected - this might be managed identity"
        fi
    else
        echo "⚠️  Not using Service Principal/Managed Identity authentication"
        echo "    Current auth type: $USER_TYPE"
    fi
else
    echo "❌ Not authenticated with Azure. Attempting managed identity login..."
    
    # Try to login with managed identity
    if az login --identity &> /dev/null; then
        echo "✅ Successfully logged in with managed identity"
        ACCOUNT_INFO=$(az account show --query "{subscriptionId:id, subscriptionName:name, user:user.name, type:user.type}" -o table)
        echo "$ACCOUNT_INFO"
    else
        echo "❌ Failed to login with managed identity"
        echo "    Make sure this script is running on a resource with managed identity configured"
        exit 1
    fi
fi

# Function to check ACR permissions
check_acr_permissions() {
    local ACR_NAME=$1
    
    echo ""
    echo "🏗️  Checking ACR permissions for: $ACR_NAME"
    
    # Test ACR login
    if az acr login --name "$ACR_NAME" &> /dev/null; then
        echo "✅ Successfully authenticated to ACR: $ACR_NAME"
        
        # Test ACR operations
        if az acr repository list --name "$ACR_NAME" &> /dev/null; then
            echo "✅ Can list repositories in ACR"
        else
            echo "⚠️  Cannot list repositories (might be empty or insufficient permissions)"
        fi
        
        # Check if we can push (this is a read-only check)
        ACR_SERVER=$(az acr show --name "$ACR_NAME" --query "loginServer" -o tsv)
        echo "✅ ACR server: $ACR_SERVER"
        
    else
        echo "❌ Failed to authenticate to ACR: $ACR_NAME"
        echo "    Required role: AcrPush, AcrPull"
    fi
}

# Function to check AKS permissions
check_aks_permissions() {
    local CLUSTER_NAME=$1
    local RESOURCE_GROUP=$2
    
    echo ""
    echo "☸️  Checking AKS permissions for: $CLUSTER_NAME in $RESOURCE_GROUP"
    
    # Test AKS credentials
    if az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --admin --overwrite-existing &> /dev/null; then
        echo "✅ Successfully retrieved AKS credentials"
        
        # Test kubectl access
        if kubectl cluster-info &> /dev/null; then
            echo "✅ Can access Kubernetes cluster"
            
            # Test namespace operations
            if kubectl get namespaces &> /dev/null; then
                echo "✅ Can list namespaces"
            else
                echo "⚠️  Cannot list namespaces"
            fi
            
        else
            echo "❌ Cannot access Kubernetes cluster"
        fi
        
    else
        echo "❌ Failed to get AKS credentials for: $CLUSTER_NAME"
        echo "    Required roles: Azure Kubernetes Service Cluster User Role, Azure Kubernetes Service RBAC Cluster Admin"
    fi
}

# Function to check Key Vault permissions
check_keyvault_permissions() {
    local KEYVAULT_NAME=$1
    
    echo ""
    echo "🔑 Checking Key Vault permissions for: $KEYVAULT_NAME"
    
    # Test Key Vault access
    if az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "[0].name" -o tsv &> /dev/null; then
        echo "✅ Successfully accessed Key Vault: $KEYVAULT_NAME"
        
        # Test secret operations
        if az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "length(@)" -o tsv &> /dev/null; then
            SECRET_COUNT=$(az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "length(@)" -o tsv)
            echo "✅ Can list secrets in Key Vault (found $SECRET_COUNT secrets)"
        else
            echo "⚠️  Cannot list secrets (might be empty or insufficient permissions)"
        fi
        
        # Test secret read (try to read a test secret)
        TEST_SECRET_NAME="test-access-verification-$(date +%s)"
        if az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "$TEST_SECRET_NAME" --value "test-value" &> /dev/null; then
            echo "✅ Can create secrets in Key Vault"
            
            # Read the test secret
            if TEST_VALUE=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$TEST_SECRET_NAME" --query "value" -o tsv 2>/dev/null); then
                if [ "$TEST_VALUE" = "test-value" ]; then
                    echo "✅ Can read secrets from Key Vault"
                else
                    echo "⚠️  Can create but cannot read secrets properly"
                fi
            else
                echo "⚠️  Can create but cannot read secrets"
            fi
            
            # Clean up test secret
            az keyvault secret delete --vault-name "$KEYVAULT_NAME" --name "$TEST_SECRET_NAME" &> /dev/null || true
            echo "✅ Cleaned up test secret"
        else
            echo "⚠️  Cannot create secrets (read-only access)"
            echo "    This is acceptable if using a pre-populated Key Vault"
        fi
        
    else
        echo "❌ Failed to access Key Vault: $KEYVAULT_NAME"
        echo "    Required role: Key Vault Secrets User"
    fi
}

# Get environment variables or prompt for input
if [ -z "$ACR_LOGIN_SERVER" ]; then
    echo ""
    read -p "Enter ACR name (without .azurecr.io): " ACR_NAME
else
    ACR_NAME=$(echo "$ACR_LOGIN_SERVER" | sed 's/.azurecr.io//')
fi

if [ -n "$ACR_NAME" ]; then
    check_acr_permissions "$ACR_NAME"
fi

# Check Key Vault access
if [ -z "$KEYVAULT_NAME" ]; then
    echo ""
    read -p "Enter Key Vault name (or press Enter to skip): " KEYVAULT_NAME
fi

if [ -n "$KEYVAULT_NAME" ]; then
    check_keyvault_permissions "$KEYVAULT_NAME"
fi

# Check AKS clusters
echo ""
echo "🔍 Checking AKS clusters..."

# Development environment
if [ -n "$AKS_CLUSTER_NAME_DEV" ] && [ -n "$AKS_RESOURCE_GROUP_DEV" ]; then
    check_aks_permissions "$AKS_CLUSTER_NAME_DEV" "$AKS_RESOURCE_GROUP_DEV"
elif [ -z "$AKS_CLUSTER_NAME_DEV" ]; then
    echo ""
    read -p "Enter DEV AKS cluster name (or press Enter to skip): " DEV_CLUSTER
    if [ -n "$DEV_CLUSTER" ]; then
        read -p "Enter DEV resource group: " DEV_RG
        check_aks_permissions "$DEV_CLUSTER" "$DEV_RG"
    fi
fi

# Staging environment
if [ -n "$AKS_CLUSTER_NAME_STAGING" ] && [ -n "$AKS_RESOURCE_GROUP_STAGING" ]; then
    check_aks_permissions "$AKS_CLUSTER_NAME_STAGING" "$AKS_RESOURCE_GROUP_STAGING"
elif [ -z "$AKS_CLUSTER_NAME_STAGING" ]; then
    echo ""
    read -p "Enter STAGING AKS cluster name (or press Enter to skip): " STAGING_CLUSTER
    if [ -n "$STAGING_CLUSTER" ]; then
        read -p "Enter STAGING resource group: " STAGING_RG
        check_aks_permissions "$STAGING_CLUSTER" "$STAGING_RG"
    fi
fi

# Production environment
if [ -n "$AKS_CLUSTER_NAME_PROD" ] && [ -n "$AKS_RESOURCE_GROUP_PROD" ]; then
    check_aks_permissions "$AKS_CLUSTER_NAME_PROD" "$AKS_RESOURCE_GROUP_PROD"
elif [ -z "$AKS_CLUSTER_NAME_PROD" ]; then
    echo ""
    read -p "Enter PROD AKS cluster name (or press Enter to skip): " PROD_CLUSTER
    if [ -n "$PROD_CLUSTER" ]; then
        read -p "Enter PROD resource group: " PROD_RG
        check_aks_permissions "$PROD_CLUSTER" "$PROD_RG"
    fi
fi

echo ""
echo "🎉 Verification completed!"
echo ""
echo "📋 Summary:"
echo "- Ensure all ✅ checks passed"
echo "- Address any ❌ failures before running CI/CD"
echo "- ⚠️  warnings may be acceptable depending on your setup"
echo ""
echo "For more information, see:"
echo "  - MANAGED_IDENTITY_MIGRATION.md"
echo "  - AZURE_KEYVAULT_INTEGRATION.md"