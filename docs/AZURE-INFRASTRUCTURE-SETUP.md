# 🏗️ Azure Infrastructure Setup Guide

Complete step-by-step guide for setting up Azure infrastructure for Blue-Green deployment with Java Backend1.

## 📋 **Table of Contents**

- [Prerequisites](#prerequisites)
- [Azure Resource Group Setup](#azure-resource-group-setup)
- [Azure Container Registry (ACR) Setup](#azure-container-registry-acr-setup)
- [Azure Kubernetes Service (AKS) Setup](#azure-kubernetes-service-aks-setup)
- [Azure Key Vault Setup](#azure-key-vault-setup)
- [Service Principal & OIDC Configuration](#service-principal--oidc-configuration)
- [GitHub Secrets Configuration](#github-secrets-configuration)
- [Network Security Setup](#network-security-setup)
- [Monitoring & Logging Setup](#monitoring--logging-setup)
- [Cost Optimization](#cost-optimization)
- [Validation & Testing](#validation--testing)

## ✅ **Prerequisites**

### **Required Tools Installation**
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install jq for JSON processing
sudo apt-get update && sudo apt-get install -y jq

# Verify installations
az --version
kubectl version --client
helm version
jq --version
```

### **Azure Login**
```bash
# Login to Azure
az login

# Set default subscription (replace with your subscription ID)
az account set --subscription "your-subscription-id"

# Verify current subscription
az account show --output table
```

## 🗂️ **Azure Resource Group Setup**

### **Create Resource Groups for All Environments**
```bash
# Set variables
SUBSCRIPTION_ID="your-subscription-id"
LOCATION="East US"
PROJECT_NAME="java-backend1"

# Create resource groups for each environment
az group create --name "rg-${PROJECT_NAME}-dev" --location "$LOCATION"
az group create --name "rg-${PROJECT_NAME}-sqe" --location "$LOCATION"
az group create --name "rg-${PROJECT_NAME}-ppr" --location "$LOCATION"
az group create --name "rg-${PROJECT_NAME}-prod" --location "$LOCATION"

# Create shared services resource group
az group create --name "rg-${PROJECT_NAME}-shared" --location "$LOCATION"

# Verify resource groups
az group list --output table | grep "${PROJECT_NAME}"
```

## 🐳 **Azure Container Registry (ACR) Setup**

### **Create ACR (Shared across environments)**
```bash
# Set ACR variables
ACR_NAME="${PROJECT_NAME}registry$(date +%s | tail -c 6)"  # Ensure unique name
ACR_RG="rg-${PROJECT_NAME}-shared"

# Create ACR with Premium SKU for geo-replication
az acr create \
  --resource-group "$ACR_RG" \
  --name "$ACR_NAME" \
  --sku Premium \
  --admin-enabled true \
  --location "$LOCATION"

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$ACR_RG" --query "loginServer" --output tsv)
echo "ACR Login Server: $ACR_LOGIN_SERVER"

# Configure ACR for anonymous pull (optional for public images)
az acr update --name "$ACR_NAME" --anonymous-pull-enabled true
```

### **ACR Authentication Setup**
```bash
# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --query "username" --output tsv)
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" --output tsv)

echo "ACR Username: $ACR_USERNAME"
echo "ACR Password: [REDACTED]"

# Test ACR login
docker login "$ACR_LOGIN_SERVER" --username "$ACR_USERNAME" --password "$ACR_PASSWORD"
```

### **Setup ACR Build Tasks (CI/CD Integration)**
```bash
# Create ACR task for automated builds
az acr task create \
  --registry "$ACR_NAME" \
  --name "${PROJECT_NAME}-build-task" \
  --image "${PROJECT_NAME}:{{.Run.ID}}" \
  --context https://github.com/your-org/your-repo.git \
  --file Dockerfile \
  --git-access-token "your-github-token"
```

## ⚓ **Azure Kubernetes Service (AKS) Setup**

### **Create AKS Clusters for Each Environment**

#### **Development AKS Cluster**
```bash
# Development cluster (cost-optimized)
AKS_DEV_NAME="aks-${PROJECT_NAME}-dev"
AKS_DEV_RG="rg-${PROJECT_NAME}-dev"

az aks create \
  --resource-group "$AKS_DEV_RG" \
  --name "$AKS_DEV_NAME" \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --enable-addons monitoring,azure-keyvault-secrets-provider \
  --attach-acr "$ACR_NAME" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --generate-ssh-keys \
  --kubernetes-version 1.28.5
```

#### **SQE AKS Cluster**
```bash
# SQE cluster (similar to dev but isolated)
AKS_SQE_NAME="aks-${PROJECT_NAME}-sqe"
AKS_SQE_RG="rg-${PROJECT_NAME}-sqe"

az aks create \
  --resource-group "$AKS_SQE_RG" \
  --name "$AKS_SQE_NAME" \
  --node-count 2 \
  --node-vm-size Standard_B2ms \
  --enable-managed-identity \
  --enable-addons monitoring,azure-keyvault-secrets-provider \
  --attach-acr "$ACR_NAME" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --generate-ssh-keys \
  --kubernetes-version 1.28.5
```

#### **Pre-Production AKS Cluster**
```bash
# Pre-production cluster (production-like for Blue-Green testing)
AKS_PPR_NAME="aks-${PROJECT_NAME}-ppr"
AKS_PPR_RG="rg-${PROJECT_NAME}-ppr"

az aks create \
  --resource-group "$AKS_PPR_RG" \
  --name "$AKS_PPR_NAME" \
  --node-count 3 \
  --node-vm-size Standard_D2s_v3 \
  --enable-managed-identity \
  --enable-addons monitoring,azure-keyvault-secrets-provider \
  --attach-acr "$ACR_NAME" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 5 \
  --generate-ssh-keys \
  --kubernetes-version 1.28.5
```

#### **Production AKS Cluster**
```bash
# Production cluster (high availability, multi-zone)
AKS_PROD_NAME="aks-${PROJECT_NAME}-prod"
AKS_PROD_RG="rg-${PROJECT_NAME}-prod"

az aks create \
  --resource-group "$AKS_PROD_RG" \
  --name "$AKS_PROD_NAME" \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --zones 1 2 3 \
  --enable-managed-identity \
  --enable-addons monitoring,azure-keyvault-secrets-provider \
  --attach-acr "$ACR_NAME" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10 \
  --network-plugin azure \
  --network-policy azure \
  --generate-ssh-keys \
  --kubernetes-version 1.28.5 \
  --tier Standard
```

### **Install NGINX Ingress Controller**
```bash
# Function to install NGINX ingress on each cluster
install_nginx_ingress() {
  local AKS_NAME=$1
  local AKS_RG=$2
  
  echo "Installing NGINX Ingress on $AKS_NAME..."
  
  # Get AKS credentials
  az aks get-credentials --resource-group "$AKS_RG" --name "$AKS_NAME" --overwrite-existing
  
  # Add NGINX Helm repository
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  
  # Install NGINX Ingress Controller
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.replicaCount=2 \
    --set controller.service.type=LoadBalancer \
    --set controller.metrics.enabled=true \
    --set controller.podSecurityContext.runAsUser=101 \
    --set controller.podSecurityContext.runAsGroup=101
  
  # Wait for LoadBalancer IP
  echo "Waiting for LoadBalancer IP..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s
  
  # Get external IP
  EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo "NGINX Ingress External IP for $AKS_NAME: $EXTERNAL_IP"
}

# Install on all clusters
install_nginx_ingress "$AKS_DEV_NAME" "$AKS_DEV_RG"
install_nginx_ingress "$AKS_SQE_NAME" "$AKS_SQE_RG"
install_nginx_ingress "$AKS_PPR_NAME" "$AKS_PPR_RG"
install_nginx_ingress "$AKS_PROD_NAME" "$AKS_PROD_RG"
```

## 🔐 **Azure Key Vault Setup**

### **Create Key Vault for Each Environment**
```bash
# Function to create Key Vault
create_keyvault() {
  local ENV=$1
  local KV_NAME="${PROJECT_NAME}-kv-${ENV}-$(date +%s | tail -c 4)"
  local KV_RG="rg-${PROJECT_NAME}-${ENV}"
  
  echo "Creating Key Vault: $KV_NAME"
  
  az keyvault create \
    --name "$KV_NAME" \
    --resource-group "$KV_RG" \
    --location "$LOCATION" \
    --sku Standard \
    --enabled-for-deployment true \
    --enabled-for-template-deployment true \
    --enable-rbac-authorization true
  
  echo "Key Vault created: $KV_NAME"
  return $KV_NAME
}

# Create Key Vaults for all environments
KV_DEV=$(create_keyvault "dev")
KV_SQE=$(create_keyvault "sqe")
KV_PPR=$(create_keyvault "ppr")
KV_PROD=$(create_keyvault "prod")

echo "Key Vaults created:"
echo "  DEV: $KV_DEV"
echo "  SQE: $KV_SQE"
echo "  PPR: $KV_PPR"
echo "  PROD: $KV_PROD"
```

### **Populate Key Vault with Application Secrets**
```bash
# Function to populate Key Vault secrets
populate_keyvault_secrets() {
  local KV_NAME=$1
  local ENV=$2
  
  echo "Populating secrets for $KV_NAME ($ENV environment)"
  
  # Database connection string
  az keyvault secret set \
    --vault-name "$KV_NAME" \
    --name "database-connection-string" \
    --value "jdbc:postgresql://db-${ENV}.postgres.database.azure.com:5432/${PROJECT_NAME}_${ENV}?ssl=true"
  
  # Database username
  az keyvault secret set \
    --vault-name "$KV_NAME" \
    --name "database-username" \
    --value "${PROJECT_NAME}_user_${ENV}"
  
  # Database password (generate random password)
  DB_PASSWORD=$(openssl rand -base64 32)
  az keyvault secret set \
    --vault-name "$KV_NAME" \
    --name "database-password" \
    --value "$DB_PASSWORD"
  
  # JWT Secret Key
  JWT_SECRET=$(openssl rand -base64 64)
  az keyvault secret set \
    --vault-name "$KV_NAME" \
    --name "jwt-secret-key" \
    --value "$JWT_SECRET"
  
  # External API keys (example)
  az keyvault secret set \
    --vault-name "$KV_NAME" \
    --name "external-api-key" \
    --value "your-external-api-key-${ENV}"
  
  # Redis connection string
  az keyvault secret set \
    --vault-name "$KV_NAME" \
    --name "redis-connection-string" \
    --value "redis-${ENV}.redis.cache.windows.net:6380,password=redis-password-${ENV},ssl=True,abortConnect=False"
  
  echo "Secrets populated for $KV_NAME"
}

# Populate all Key Vaults
populate_keyvault_secrets "$KV_DEV" "dev"
populate_keyvault_secrets "$KV_SQE" "sqe"
populate_keyvault_secrets "$KV_PPR" "ppr"
populate_keyvault_secrets "$KV_PROD" "prod"
```

## 🔑 **Service Principal & OIDC Configuration**

### **Create Azure AD Application & Service Principal**
```bash
# Create Azure AD Application
APP_NAME="${PROJECT_NAME}-github-actions"

# Create the application
APP_ID=$(az ad app create \
  --display-name "$APP_NAME" \
  --query appId \
  --output tsv)

echo "Created Azure AD Application: $APP_ID"

# Create Service Principal
SP_ID=$(az ad sp create \
  --id "$APP_ID" \
  --query id \
  --output tsv)

echo "Created Service Principal: $SP_ID"

# Get tenant ID
TENANT_ID=$(az account show --query tenantId --output tsv)
echo "Tenant ID: $TENANT_ID"
```

### **Configure OIDC Federation for GitHub Actions**
```bash
# Set GitHub repository details
GITHUB_ORG="your-github-org"
GITHUB_REPO="your-repo-name"

# Create OIDC credential for main branch
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':ref:refs/heads/main",
    "description": "GitHub Actions OIDC for main branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create OIDC credential for develop branch
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-develop-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':ref:refs/heads/develop",
    "description": "GitHub Actions OIDC for develop branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create OIDC credential for release branches
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-release-branches",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':ref:refs/heads/release/*",
    "description": "GitHub Actions OIDC for release branches",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create OIDC credential for tags
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-tags",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':ref:refs/tags/*",
    "description": "GitHub Actions OIDC for tags",
    "audiences": ["api://AzureADTokenExchange"]
  }'

echo "OIDC federation configured for GitHub Actions"
```

### **Assign Azure Permissions**
```bash
# Function to assign permissions to resource group
assign_permissions() {
  local RG_NAME=$1
  local ROLE=$2
  
  echo "Assigning $ROLE permission to $RG_NAME"
  
  az role assignment create \
    --assignee "$SP_ID" \
    --role "$ROLE" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME"
}

# Assign Contributor role to all resource groups
assign_permissions "rg-${PROJECT_NAME}-dev" "Contributor"
assign_permissions "rg-${PROJECT_NAME}-sqe" "Contributor"
assign_permissions "rg-${PROJECT_NAME}-ppr" "Contributor"
assign_permissions "rg-${PROJECT_NAME}-prod" "Contributor"
assign_permissions "rg-${PROJECT_NAME}-shared" "Contributor"

# Assign AcrPush role for ACR
az role assignment create \
  --assignee "$SP_ID" \
  --role "AcrPush" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-${PROJECT_NAME}-shared/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME"

# Assign Key Vault permissions
assign_keyvault_permissions() {
  local KV_NAME=$1
  
  echo "Assigning Key Vault permissions to $KV_NAME"
  
  az role assignment create \
    --assignee "$SP_ID" \
    --role "Key Vault Secrets User" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-${PROJECT_NAME}-*/providers/Microsoft.KeyVault/vaults/$KV_NAME"
}

assign_keyvault_permissions "$KV_DEV"
assign_keyvault_permissions "$KV_SQE"
assign_keyvault_permissions "$KV_PPR"
assign_keyvault_permissions "$KV_PROD"

echo "Permissions assigned successfully"
```

## 🔧 **GitHub Secrets Configuration**

### **Configure GitHub Repository Secrets**
```bash
# Install GitHub CLI if not already installed
# gh auth login

# Set GitHub repository secrets
echo "Setting GitHub repository secrets..."

# Azure authentication secrets
gh secret set AZURE_CLIENT_ID --body "$APP_ID"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"

# ACR secrets
gh secret set ACR_LOGIN_SERVER --body "$ACR_LOGIN_SERVER"

# Key Vault names for each environment
gh secret set KEYVAULT_NAME_DEV --body "$KV_DEV"
gh secret set KEYVAULT_NAME_SQE --body "$KV_SQE"
gh secret set KEYVAULT_NAME_PPR --body "$KV_PPR"
gh secret set KEYVAULT_NAME_PROD --body "$KV_PROD"

# SonarQube token (replace with your actual token)
gh secret set SONAR_TOKEN --body "your-sonarqube-token"

# Checkmarx credentials (replace with your actual credentials)
gh secret set CHECKMARX_CLIENT_ID --body "your-checkmarx-client-id"
gh secret set CHECKMARX_CLIENT_SECRET --body "your-checkmarx-client-secret"

echo "GitHub secrets configured successfully"
```

### **Configure GitHub Variables**
```bash
# Set GitHub repository variables
echo "Setting GitHub repository variables..."

# SonarQube configuration
gh variable set SONAR_HOST_URL --body "https://your-sonarqube-server.com"
gh variable set SONAR_PROJECT_KEY --body "$PROJECT_NAME"

# Checkmarx configuration
gh variable set CHECKMARX_URL --body "https://your-checkmarx-server.com"
gh variable set CX_TENANT --body "your-checkmarx-tenant"

# Quality thresholds
gh variable set SONAR_COVERAGE_THRESHOLD --body "80"
gh variable set CHECKMARX_HIGH_THRESHOLD --body "0"
gh variable set CHECKMARX_MEDIUM_THRESHOLD --body "5"

echo "GitHub variables configured successfully"
```

## 🌐 **Network Security Setup**

### **Configure Network Security Groups**
```bash
# Function to create and configure NSG
create_nsg() {
  local ENV=$1
  local NSG_NAME="nsg-${PROJECT_NAME}-${ENV}"
  local RG_NAME="rg-${PROJECT_NAME}-${ENV}"
  
  echo "Creating NSG for $ENV environment"
  
  # Create NSG
  az network nsg create \
    --resource-group "$RG_NAME" \
    --name "$NSG_NAME" \
    --location "$LOCATION"
  
  # Allow HTTPS traffic
  az network nsg rule create \
    --resource-group "$RG_NAME" \
    --nsg-name "$NSG_NAME" \
    --name "AllowHTTPS" \
    --protocol Tcp \
    --priority 1000 \
    --destination-port-range 443 \
    --access Allow
  
  # Allow HTTP traffic (for development environments)
  if [[ "$ENV" == "dev" || "$ENV" == "sqe" ]]; then
    az network nsg rule create \
      --resource-group "$RG_NAME" \
      --nsg-name "$NSG_NAME" \
      --name "AllowHTTP" \
      --protocol Tcp \
      --priority 1100 \
      --destination-port-range 80 \
      --access Allow
  fi
  
  echo "NSG created and configured: $NSG_NAME"
}

# Create NSGs for all environments
create_nsg "dev"
create_nsg "sqe"
create_nsg "ppr"
create_nsg "prod"
```

### **Configure Azure Firewall (Production)**
```bash
# Create Azure Firewall for production environment
FIREWALL_NAME="fw-${PROJECT_NAME}-prod"
FIREWALL_RG="rg-${PROJECT_NAME}-prod"

# Create public IP for firewall
az network public-ip create \
  --resource-group "$FIREWALL_RG" \
  --name "ip-${FIREWALL_NAME}" \
  --location "$LOCATION" \
  --allocation-method Static \
  --sku Standard

# Create firewall subnet (if using custom VNet)
# az network vnet subnet create \
#   --resource-group "$FIREWALL_RG" \
#   --name "AzureFirewallSubnet" \
#   --vnet-name "vnet-${PROJECT_NAME}-prod" \
#   --address-prefix "10.0.1.0/24"

echo "Network security configured"
```

## 🌐 **Azure Application Gateway Setup (SSL Termination)**

### **Create Application Gateway for SSL Termination**
```bash
# Create public IP for Application Gateway
APP_GW_NAME="appgw-${PROJECT_NAME}-prod"
APP_GW_RG="rg-${PROJECT_NAME}-prod"

az network public-ip create \
  --resource-group "$APP_GW_RG" \
  --name "pip-${APP_GW_NAME}" \
  --location "$LOCATION" \
  --allocation-method Static \
  --sku Standard \
  --dns-name "${PROJECT_NAME}-appgw"

# Get public IP address
APP_GW_IP=$(az network public-ip show --resource-group "$APP_GW_RG" --name "pip-${APP_GW_NAME}" --query ipAddress --output tsv)
echo "Application Gateway Public IP: $APP_GW_IP"
```

### **Configure Application Gateway with NGINX Backend**
```bash
# Get NGINX ingress controller IP (LoadBalancer IP)
NGINX_INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "NGINX Ingress IP: $NGINX_INGRESS_IP"

# Create Application Gateway
az network application-gateway create \
  --resource-group "$APP_GW_RG" \
  --name "$APP_GW_NAME" \
  --location "$LOCATION" \
  --capacity 2 \
  --sku Standard_v2 \
  --public-ip-address "pip-${APP_GW_NAME}" \
  --vnet-name "vnet-${PROJECT_NAME}-prod" \
  --subnet "subnet-appgw" \
  --servers "$NGINX_INGRESS_IP" \
  --http-settings-cookie-based-affinity Disabled \
  --http-settings-port 80 \
  --http-settings-protocol Http \
  --frontend-port 443 \
  --http2 Enabled

echo "Application Gateway created successfully"
```

### **Configure SSL Certificate on Application Gateway**
```bash
# Option 1: Upload custom SSL certificate
az network application-gateway ssl-cert create \
  --resource-group "$APP_GW_RG" \
  --gateway-name "$APP_GW_NAME" \
  --name "ssl-cert-${PROJECT_NAME}" \
  --cert-file "/path/to/your/certificate.pfx" \
  --cert-password "your-certificate-password"

# Option 2: Use managed certificate (if using custom domain)
# Configure custom domain and managed certificate through Azure Portal

# Create HTTPS listener
az network application-gateway http-listener create \
  --resource-group "$APP_GW_RG" \
  --gateway-name "$APP_GW_NAME" \
  --name "https-listener" \
  --frontend-port "appGatewayFrontendPort443" \
  --ssl-cert "ssl-cert-${PROJECT_NAME}"

# Create routing rule for HTTPS
az network application-gateway rule create \
  --resource-group "$APP_GW_RG" \
  --gateway-name "$APP_GW_NAME" \
  --name "https-rule" \
  --http-listener "https-listener" \
  --rule-type Basic \
  --address-pool "appGatewayBackendPool" \
  --http-settings "appGatewayBackendHttpSettings"
```

### **Configure Health Probes**
```bash
# Create custom health probe for backend health
az network application-gateway probe create \
  --resource-group "$APP_GW_RG" \
  --gateway-name "$APP_GW_NAME" \
  --name "health-probe" \
  --protocol Http \
  --host-name-from-http-settings true \
  --path "/backend1/actuator/health" \
  --interval 30 \
  --timeout 30 \
  --threshold 3

# Update backend HTTP settings to use custom probe
az network application-gateway http-settings update \
  --resource-group "$APP_GW_RG" \
  --gateway-name "$APP_GW_NAME" \
  --name "appGatewayBackendHttpSettings" \
  --probe "health-probe"

echo "Health probes configured"
```

### **DNS Configuration**
```bash
# Update DNS to point to Application Gateway public IP
echo "Configure your DNS records:"
echo "  A Record: api.mydomain.com -> $APP_GW_IP"
echo "  A Record: preprod.mydomain.com -> $APP_GW_IP"
echo "  A Record: dev.mydomain.com -> $APP_GW_IP"
echo "  A Record: sqe.mydomain.com -> $APP_GW_IP"
```

## 📊 **Monitoring & Logging Setup**

### **Configure Azure Monitor**
```bash
# Function to setup monitoring for each environment
setup_monitoring() {
  local ENV=$1
  local RG_NAME="rg-${PROJECT_NAME}-${ENV}"
  local WORKSPACE_NAME="law-${PROJECT_NAME}-${ENV}"
  
  echo "Setting up monitoring for $ENV environment"
  
  # Create Log Analytics Workspace
  az monitor log-analytics workspace create \
    --resource-group "$RG_NAME" \
    --workspace-name "$WORKSPACE_NAME" \
    --location "$LOCATION" \
    --sku PerGB2018
  
  # Create Application Insights
  az monitor app-insights component create \
    --app "${PROJECT_NAME}-${ENV}" \
    --location "$LOCATION" \
    --resource-group "$RG_NAME" \
    --workspace "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME"
  
  echo "Monitoring setup completed for $ENV"
}

# Setup monitoring for all environments
setup_monitoring "dev"
setup_monitoring "sqe"
setup_monitoring "ppr"
setup_monitoring "prod"
```

### **Configure Alerts**
```bash
# Function to create alerts
create_alerts() {
  local ENV=$1
  local RG_NAME="rg-${PROJECT_NAME}-${ENV}"
  
  echo "Creating alerts for $ENV environment"
  
  # Create action group for notifications
  az monitor action-group create \
    --resource-group "$RG_NAME" \
    --name "ag-${PROJECT_NAME}-${ENV}" \
    --short-name "${PROJECT_NAME:0:12}" \
    --email-receiver name="DevOpsTeam" email="devops@yourcompany.com"
  
  # Create metric alert for high CPU usage
  az monitor metrics alert create \
    --name "High CPU Usage - $ENV" \
    --resource-group "$RG_NAME" \
    --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME" \
    --condition "avg Percentage CPU > 80" \
    --description "CPU usage is above 80%" \
    --evaluation-frequency PT1M \
    --window-size PT5M \
    --severity 2 \
    --action "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Insights/actionGroups/ag-${PROJECT_NAME}-${ENV}"
  
  echo "Alerts created for $ENV"
}

# Create alerts for production environments
create_alerts "ppr"
create_alerts "prod"
```

## 💰 **Cost Optimization**

### **Set up Budget Alerts**
```bash
# Create budget for each environment
create_budget() {
  local ENV=$1
  local AMOUNT=$2
  local RG_NAME="rg-${PROJECT_NAME}-${ENV}"
  
  echo "Creating budget for $ENV environment: \$$AMOUNT"
  
  az consumption budget create \
    --resource-group "$RG_NAME" \
    --budget-name "budget-${PROJECT_NAME}-${ENV}" \
    --amount "$AMOUNT" \
    --time-grain Monthly \
    --start-date "$(date -d 'first day of this month' '+%Y-%m-01')" \
    --end-date "$(date -d 'first day of next year' '+%Y-12-31')" \
    --threshold 80 \
    --contact-emails "finance@yourcompany.com"
}

# Create budgets (adjust amounts based on your needs)
create_budget "dev" 200
create_budget "sqe" 300
create_budget "ppr" 500
create_budget "prod" 2000
```

### **Configure Auto-Shutdown for Development**
```bash
# Configure auto-shutdown for development AKS cluster
az aks update \
  --resource-group "rg-${PROJECT_NAME}-dev" \
  --name "aks-${PROJECT_NAME}-dev" \
  --enable-node-pool-autoscale \
  --min-count 1 \
  --max-count 3

echo "Auto-scaling configured for development environment"
```

## ✅ **Validation & Testing**

### **Test Infrastructure Setup**
```bash
# Function to test AKS connectivity
test_aks_connectivity() {
  local AKS_NAME=$1
  local AKS_RG=$2
  local ENV=$3
  
  echo "Testing connectivity to $AKS_NAME ($ENV)"
  
  # Get credentials
  az aks get-credentials --resource-group "$AKS_RG" --name "$AKS_NAME" --overwrite-existing
  
  # Test kubectl connectivity
  kubectl get nodes
  kubectl get namespaces
  
  # Test NGINX ingress
  kubectl get svc -n ingress-nginx
  
  echo "✅ $ENV environment test completed"
}

# Test all environments
test_aks_connectivity "aks-${PROJECT_NAME}-dev" "rg-${PROJECT_NAME}-dev" "dev"
test_aks_connectivity "aks-${PROJECT_NAME}-sqe" "rg-${PROJECT_NAME}-sqe" "sqe"
test_aks_connectivity "aks-${PROJECT_NAME}-ppr" "rg-${PROJECT_NAME}-ppr" "ppr"
test_aks_connectivity "aks-${PROJECT_NAME}-prod" "rg-${PROJECT_NAME}-prod" "prod"
```

### **Test Key Vault Access**
```bash
# Function to test Key Vault access
test_keyvault_access() {
  local KV_NAME=$1
  local ENV=$2
  
  echo "Testing Key Vault access: $KV_NAME ($ENV)"
  
  # List secrets (should show secret names)
  az keyvault secret list --vault-name "$KV_NAME" --output table
  
  # Test secret retrieval
  az keyvault secret show --vault-name "$KV_NAME" --name "database-username" --query "value" --output tsv
  
  echo "✅ Key Vault test completed for $ENV"
}

# Test all Key Vaults
test_keyvault_access "$KV_DEV" "dev"
test_keyvault_access "$KV_SQE" "sqe"
test_keyvault_access "$KV_PPR" "ppr"
test_keyvault_access "$KV_PROD" "prod"
```

### **Test ACR Access**
```bash
# Test ACR access
echo "Testing ACR access: $ACR_NAME"

# List repositories
az acr repository list --name "$ACR_NAME" --output table

# Test docker pull (should work)
docker pull "$ACR_LOGIN_SERVER/hello-world:latest" || echo "No images in ACR yet (expected)"

echo "✅ ACR test completed"
```

## 📝 **Summary & Next Steps**

### **Infrastructure Created**
- ✅ **4 Resource Groups**: dev, sqe, ppr, prod, shared
- ✅ **1 Azure Container Registry**: Premium SKU with geo-replication
- ✅ **4 AKS Clusters**: Optimized for each environment
- ✅ **4 Key Vaults**: Secure secret management
- ✅ **NGINX Ingress**: Load balancer with external IPs
- ✅ **Monitoring**: Log Analytics + Application Insights
- ✅ **Security**: NSGs, RBAC, OIDC federation
- ✅ **Cost Management**: Budgets and auto-scaling

### **Important Information to Save**
```bash
echo "=== SAVE THIS INFORMATION ==="
echo "Azure Subscription ID: $SUBSCRIPTION_ID"
echo "Azure Tenant ID: $TENANT_ID"
echo "Service Principal (Client ID): $APP_ID"
echo "ACR Login Server: $ACR_LOGIN_SERVER"
echo "Key Vault Dev: $KV_DEV"
echo "Key Vault SQE: $KV_SQE"
echo "Key Vault PPR: $KV_PPR"
echo "Key Vault Prod: $KV_PROD"
echo "=========================="
```

### **Next Steps**
1. ✅ Configure Azure Application Gateway for SSL termination
2. ✅ Point Application Gateway backend pools to NGINX ingress IPs
3. ✅ Update Helm chart values with your actual domain names
4. ✅ Configure SSL certificates on Application Gateway
5. ✅ Test the complete CI/CD pipeline
6. ✅ Configure backup and disaster recovery
7. ✅ Set up monitoring dashboards

### **Cleanup Script (Use with caution!)**
```bash
# WARNING: This will delete ALL created resources
cleanup_all_resources() {
  echo "⚠️  WARNING: This will delete ALL Azure resources!"
  read -p "Are you sure? Type 'DELETE' to confirm: " confirmation
  
  if [ "$confirmation" = "DELETE" ]; then
    az group delete --name "rg-${PROJECT_NAME}-dev" --yes --no-wait
    az group delete --name "rg-${PROJECT_NAME}-sqe" --yes --no-wait
    az group delete --name "rg-${PROJECT_NAME}-ppr" --yes --no-wait
    az group delete --name "rg-${PROJECT_NAME}-prod" --yes --no-wait
    az group delete --name "rg-${PROJECT_NAME}-shared" --yes --no-wait
    echo "Deletion initiated for all resource groups"
  else
    echo "Cleanup cancelled"
  fi
}

# Uncomment to enable cleanup
# cleanup_all_resources
```

This completes the comprehensive Azure infrastructure setup. All resources are now ready for the Blue-Green deployment pipeline!