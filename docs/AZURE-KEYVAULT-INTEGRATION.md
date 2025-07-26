# 🔐 Azure Key Vault Integration Guide

This guide covers the complete setup and configuration of Azure Key Vault integration for the Java Backend application across all environments.

## 🎯 Overview

Azure Key Vault provides secure storage for secrets, keys, and certificates. This application integrates with Key Vault using:
- **CSI Secret Store Driver** for mounting secrets as volumes
- **Azure Pod Identity** or **Workload Identity** for authentication
- **Environment-specific Key Vaults** for proper secret isolation

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Development   │    │       SQE       │    │  Pre-Production │
│                 │    │                 │    │                 │
│ Key Vault: OFF  │    │ Key Vault: ON   │    │ Key Vault: ON   │
│ Local secrets   │    │ Basic secrets   │    │ Full secrets    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                               ┌─────────────────┐
                                               │   Production    │
                                               │                 │
                                               │ Key Vault: ON   │
                                               │ All secrets     │
                                               └─────────────────┘
```

## 🔧 Environment Configuration

### Development (`dev`)
- **Key Vault**: Disabled
- **Secret Management**: Local configuration files
- **Purpose**: Fast development without external dependencies

### SQE (`sqe`)
- **Key Vault**: `kv-java-backend1-sqe`
- **Secrets**: Basic database and API keys
- **Purpose**: Integration testing with realistic secret management

### Pre-Production (`ppr`)
- **Key Vault**: `kv-java-backend1-ppr`
- **Secrets**: Full production-like secret set
- **Purpose**: Final validation before production

### Production (`prod`)
- **Key Vault**: `kv-java-backend1-prod`
- **Secrets**: Complete production secret set
- **Purpose**: Live production workloads

## 📋 Required Secrets by Environment

### SQE Environment
```
kv-java-backend1-sqe/
├── mongodb-connection-string
├── redis-password
├── jwt-secret
└── api-key
```

### PPR Environment
```
kv-java-backend1-ppr/
├── mongodb-connection-string
├── redis-password
├── memcached-servers
├── jwt-secret
├── api-key
├── application-insights-key
└── oauth2-client-secret
```

### Production Environment
```
kv-java-backend1-prod/
├── mongodb-connection-string
├── redis-password
├── memcached-servers
├── jwt-secret
├── api-key
├── application-insights-key
├── oauth2-client-secret
└── external-service-api-key
```

## 🛠️ Azure Infrastructure Setup

### 1. Create Key Vaults

```bash
#!/bin/bash
# Create Key Vaults for each environment

SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="rg-java-backend1"
LOCATION="East US"

# Set subscription
az account set --subscription $SUBSCRIPTION_ID

# Create Key Vaults
environments=("sqe" "ppr" "prod")

for env in "${environments[@]}"; do
    echo "Creating Key Vault for $env environment..."
    
    az keyvault create \
        --name "kv-java-backend1-$env" \
        --resource-group $RESOURCE_GROUP \
        --location "$LOCATION" \
        --sku standard \
        --enable-rbac-authorization true \
        --retention-days 90 \
        --tags Environment=$env Application=java-backend1
    
    echo "✅ Key Vault kv-java-backend1-$env created"
done
```

### 2. Configure Access Policies

```bash
#!/bin/bash
# Configure Key Vault access policies

SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="rg-java-backend1"
AKS_CLUSTER_NAME="aks-java-backend1-prod"
SERVICE_PRINCIPAL_ID="your-sp-object-id"

environments=("sqe" "ppr" "prod")

for env in "${environments[@]}"; do
    KEYVAULT_NAME="kv-java-backend1-$env"
    
    echo "Configuring access for $KEYVAULT_NAME..."
    
    # Grant access to AKS cluster managed identity
    AKS_IDENTITY=$(az aks show \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_CLUSTER_NAME \
        --query "identity.principalId" -o tsv)
    
    az role assignment create \
        --assignee $AKS_IDENTITY \
        --role "Key Vault Secrets User" \
        --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME"
    
    # Grant access to deployment service principal
    az role assignment create \
        --assignee $SERVICE_PRINCIPAL_ID \
        --role "Key Vault Secrets Officer" \
        --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME"
    
    echo "✅ Access configured for $KEYVAULT_NAME"
done
```

### 3. Install CSI Secret Store Driver

```bash
#!/bin/bash
# Install Azure Key Vault CSI Secret Store Driver

AKS_CLUSTER_NAME="aks-java-backend1-prod"
RESOURCE_GROUP="rg-java-backend1"

# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Install CSI Secret Store Driver
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update

helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
    --namespace kube-system \
    --set syncSecret.enabled=true \
    --set enableSecretRotation=true

# Install Azure Key Vault Provider
kubectl apply -f https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/deployment/provider-azure-installer.yaml

echo "✅ CSI Secret Store Driver installed"
```

## 🔑 Secret Management Scripts

### Create Secrets Script

```bash
#!/bin/bash
# scripts/create-keyvault-secrets.sh

set -e

KEYVAULT_NAME=""
ENVIRONMENT=""

# Function to display usage
usage() {
    echo "Usage: $0 -v <keyvault-name> -e <environment>"
    echo "  -v: Key Vault name (e.g., kv-java-backend1-prod)"
    echo "  -e: Environment (sqe|ppr|prod)"
    exit 1
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
    usage
fi

echo "🔐 Creating secrets for $ENVIRONMENT environment in $KEYVAULT_NAME"

# Common secrets
read -s -p "Enter MongoDB connection string: " MONGODB_CONN
echo
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "mongodb-connection-string" --value "$MONGODB_CONN"

read -s -p "Enter Redis password: " REDIS_PASS
echo
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "redis-password" --value "$REDIS_PASS"

read -s -p "Enter JWT secret: " JWT_SECRET
echo
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "jwt-secret" --value "$JWT_SECRET"

read -s -p "Enter API key: " API_KEY
echo
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "api-key" --value "$API_KEY"

# Environment-specific secrets
if [[ "$ENVIRONMENT" == "ppr" || "$ENVIRONMENT" == "prod" ]]; then
    read -s -p "Enter Memcached servers: " MEMCACHED_SERVERS
    echo
    az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "memcached-servers" --value "$MEMCACHED_SERVERS"
    
    read -s -p "Enter Application Insights key: " APP_INSIGHTS_KEY
    echo
    az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "application-insights-key" --value "$APP_INSIGHTS_KEY"
    
    read -s -p "Enter OAuth2 client secret: " OAUTH2_SECRET
    echo
    az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "oauth2-client-secret" --value "$OAUTH2_SECRET"
fi

# Production-only secrets
if [[ "$ENVIRONMENT" == "prod" ]]; then
    read -s -p "Enter external service API key: " EXT_API_KEY
    echo
    az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "external-service-api-key" --value "$EXT_API_KEY"
fi

echo "✅ All secrets created successfully in $KEYVAULT_NAME"
```

### Rotate Secrets Script

```bash
#!/bin/bash
# scripts/rotate-keyvault-secrets.sh

set -e

KEYVAULT_NAME=""
SECRET_NAME=""
NEW_VALUE=""

usage() {
    echo "Usage: $0 -v <keyvault-name> -s <secret-name> [-n <new-value>]"
    echo "  -v: Key Vault name"
    echo "  -s: Secret name to rotate"
    echo "  -n: New value (optional, will prompt if not provided)"
    exit 1
}

while getopts "v:s:n:h" opt; do
    case $opt in
        v) KEYVAULT_NAME="$OPTARG" ;;
        s) SECRET_NAME="$OPTARG" ;;
        n) NEW_VALUE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [[ -z "$KEYVAULT_NAME" || -z "$SECRET_NAME" ]]; then
    usage
fi

echo "🔄 Rotating secret '$SECRET_NAME' in $KEYVAULT_NAME"

# Get current value for backup
CURRENT_VALUE=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$SECRET_NAME" --query "value" -o tsv 2>/dev/null || echo "")

if [[ -n "$CURRENT_VALUE" ]]; then
    echo "✅ Current secret value backed up"
    # Store previous version with timestamp
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "${SECRET_NAME}-backup-${TIMESTAMP}" --value "$CURRENT_VALUE" >/dev/null
    echo "📁 Backup stored as ${SECRET_NAME}-backup-${TIMESTAMP}"
fi

# Get new value if not provided
if [[ -z "$NEW_VALUE" ]]; then
    read -s -p "Enter new value for '$SECRET_NAME': " NEW_VALUE
    echo
fi

# Set new value
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "$SECRET_NAME" --value "$NEW_VALUE" >/dev/null

echo "✅ Secret '$SECRET_NAME' rotated successfully"
echo "🔄 Consider restarting applications to pick up the new value"
```

## 🔍 Validation and Troubleshooting

### Verify Key Vault Integration

```bash
#!/bin/bash
# scripts/verify-keyvault-integration.sh

NAMESPACE=""
APP_NAME="java-backend1"

usage() {
    echo "Usage: $0 -n <namespace>"
    echo "  -n: Kubernetes namespace (e.g., sqe-java-backend1)"
    exit 1
}

while getopts "n:h" opt; do
    case $opt in
        n) NAMESPACE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [[ -z "$NAMESPACE" ]]; then
    usage
fi

echo "🔍 Verifying Key Vault integration in namespace: $NAMESPACE"
echo "============================================================"

# Check SecretProviderClass
echo "📋 Checking SecretProviderClass..."
if kubectl get secretproviderclass -n "$NAMESPACE" "${APP_NAME}-keyvault" >/dev/null 2>&1; then
    echo "✅ SecretProviderClass exists"
    kubectl describe secretproviderclass -n "$NAMESPACE" "${APP_NAME}-keyvault"
else
    echo "❌ SecretProviderClass not found"
fi

echo ""

# Check mounted secrets
echo "📋 Checking mounted secrets..."
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$POD_NAME" ]]; then
    echo "✅ Found pod: $POD_NAME"
    
    echo "🔍 Checking secret mount:"
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- ls -la /mnt/secrets-store/ 2>/dev/null || echo "❌ Secret mount not accessible"
    
    echo "🔍 Checking environment variables:"
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- env | grep -E "(MONGODB|REDIS|JWT)" || echo "❌ Secret environment variables not found"
else
    echo "❌ No running pods found"
fi

echo ""

# Check Kubernetes secrets
echo "📋 Checking Kubernetes secrets..."
if kubectl get secret -n "$NAMESPACE" "app-secrets" >/dev/null 2>&1; then
    echo "✅ Kubernetes secret 'app-secrets' exists"
    kubectl describe secret -n "$NAMESPACE" "app-secrets"
else
    echo "❌ Kubernetes secret 'app-secrets' not found"
fi

echo ""
echo "🎯 Verification complete"
```

### Common Issues and Solutions

#### Issue: SecretProviderClass not syncing
**Solution:**
```bash
# Check CSI driver status
kubectl get pods -n kube-system | grep secrets-store

# Check SecretProviderClass events
kubectl describe secretproviderclass -n <namespace> <name>

# Restart CSI driver if needed
kubectl rollout restart daemonset/secrets-store-csi-driver -n kube-system
```

#### Issue: Pod cannot access Key Vault
**Solution:**
```bash
# Check pod identity
kubectl describe pod -n <namespace> <pod-name>

# Verify RBAC permissions
az role assignment list --assignee <managed-identity-id> --scope <keyvault-resource-id>

# Check network connectivity
kubectl exec -n <namespace> <pod-name> -- nslookup <keyvault-name>.vault.azure.net
```

#### Issue: Secrets not appearing in pod
**Solution:**
```bash
# Check volume mounts
kubectl describe pod -n <namespace> <pod-name>

# Verify SecretProviderClass configuration
kubectl get secretproviderclass -n <namespace> -o yaml

# Check CSI driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver
```

## 🔄 Best Practices

### 1. Secret Rotation
- Implement automated secret rotation
- Use backup strategy before rotation
- Test secret changes in lower environments first

### 2. Access Control
- Use least privilege principle
- Separate Key Vaults per environment
- Regular access review and cleanup

### 3. Monitoring
- Monitor Key Vault access logs
- Set up alerts for secret access failures
- Track secret usage and rotation schedules

### 4. Disaster Recovery
- Regular backup of Key Vault secrets
- Document recovery procedures
- Test recovery in non-production environments

## 📚 Additional Resources

- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)
- [CSI Secret Store Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [Azure Key Vault Provider](https://azure.github.io/secrets-store-csi-driver-provider-azure/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)