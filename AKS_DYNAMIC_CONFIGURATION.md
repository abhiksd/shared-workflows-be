# Dynamic AKS Cluster Configuration

## 🎯 **Overview**

This document outlines the implementation of dynamic AKS cluster selection based on environment, replacing hardcoded cluster names with a flexible, configurable system.

## 🚀 **Implementation Options**

### **Option 1: Repository Variables (Recommended)**

Use GitHub repository variables to store AKS cluster configurations for each environment.

#### **Repository Variables Setup**

```bash
# Set up repository variables via GitHub CLI or UI
gh variable set AKS_CLUSTER_DEV --body "aks-dev-cluster"
gh variable set AKS_RESOURCE_GROUP_DEV --body "rg-aks-dev"

gh variable set AKS_CLUSTER_SQE --body "aks-sqe-cluster"
gh variable set AKS_RESOURCE_GROUP_SQE --body "rg-aks-sqe"

gh variable set AKS_CLUSTER_PPR --body "aks-preprod-cluster"
gh variable set AKS_RESOURCE_GROUP_PPR --body "rg-aks-preprod"

gh variable set AKS_CLUSTER_PROD --body "aks-prod-cluster"
gh variable set AKS_RESOURCE_GROUP_PROD --body "rg-aks-prod"
```

#### **Workflow Implementation**

```yaml
# In shared-deploy.yml - validate-environment job
- name: Dynamic AKS Configuration
  id: aks-config
  run: |
    TARGET_ENV="${{ steps.check.outputs.target_environment }}"
    echo "🔧 Configuring AKS cluster for environment: $TARGET_ENV"
    
    case "$TARGET_ENV" in
      "dev")
        AKS_CLUSTER="${{ vars.AKS_CLUSTER_DEV }}"
        AKS_RG="${{ vars.AKS_RESOURCE_GROUP_DEV }}"
        ;;
      "sqe")
        AKS_CLUSTER="${{ vars.AKS_CLUSTER_SQE }}"
        AKS_RG="${{ vars.AKS_RESOURCE_GROUP_SQE }}"
        ;;
      "ppr")
        AKS_CLUSTER="${{ vars.AKS_CLUSTER_PPR }}"
        AKS_RG="${{ vars.AKS_RESOURCE_GROUP_PPR }}"
        ;;
      "prod")
        AKS_CLUSTER="${{ vars.AKS_CLUSTER_PROD }}"
        AKS_RG="${{ vars.AKS_RESOURCE_GROUP_PROD }}"
        ;;
      *)
        echo "❌ Unknown environment: $TARGET_ENV"
        exit 1
        ;;
    esac
    
    # Validate configuration
    if [ -z "$AKS_CLUSTER" ]; then
      echo "❌ AKS cluster not configured for environment: $TARGET_ENV"
      echo "Please set repository variable: AKS_CLUSTER_${TARGET_ENV^^}"
      exit 1
    fi
    
    if [ -z "$AKS_RG" ]; then
      echo "❌ AKS resource group not configured for environment: $TARGET_ENV"
      echo "Please set repository variable: AKS_RESOURCE_GROUP_${TARGET_ENV^^}"
      exit 1
    fi
    
    echo "✅ AKS Configuration:"
    echo "   Environment: $TARGET_ENV"
    echo "   Cluster: $AKS_CLUSTER"
    echo "   Resource Group: $AKS_RG"
    
    echo "aks_cluster=$AKS_CLUSTER" >> $GITHUB_OUTPUT
    echo "aks_resource_group=$AKS_RG" >> $GITHUB_OUTPUT
```

### **Option 2: JSON Configuration File**

Store AKS cluster configurations in a JSON file within the repository.

#### **Configuration File: `.github/config/aks-clusters.json`**

```json
{
  "clusters": {
    "dev": {
      "name": "aks-dev-cluster",
      "resourceGroup": "rg-aks-dev",
      "region": "East US",
      "nodeCount": 2
    },
    "sqe": {
      "name": "aks-sqe-cluster", 
      "resourceGroup": "rg-aks-sqe",
      "region": "East US",
      "nodeCount": 3
    },
    "ppr": {
      "name": "aks-preprod-cluster",
      "resourceGroup": "rg-aks-preprod", 
      "region": "West US 2",
      "nodeCount": 5
    },
    "prod": {
      "name": "aks-prod-cluster",
      "resourceGroup": "rg-aks-prod",
      "region": "West US 2", 
      "nodeCount": 10
    }
  }
}
```

#### **Workflow Implementation**

```yaml
- name: Load AKS Configuration
  id: aks-config
  run: |
    TARGET_ENV="${{ steps.check.outputs.target_environment }}"
    echo "🔧 Loading AKS configuration for environment: $TARGET_ENV"
    
    # Read configuration from JSON file
    CONFIG_FILE=".github/config/aks-clusters.json"
    
    if [ ! -f "$CONFIG_FILE" ]; then
      echo "❌ AKS configuration file not found: $CONFIG_FILE"
      exit 1
    fi
    
    # Extract cluster configuration using jq
    AKS_CLUSTER=$(jq -r ".clusters.${TARGET_ENV}.name" "$CONFIG_FILE")
    AKS_RG=$(jq -r ".clusters.${TARGET_ENV}.resourceGroup" "$CONFIG_FILE")
    REGION=$(jq -r ".clusters.${TARGET_ENV}.region" "$CONFIG_FILE")
    
    # Validate configuration
    if [ "$AKS_CLUSTER" = "null" ] || [ -z "$AKS_CLUSTER" ]; then
      echo "❌ AKS cluster not configured for environment: $TARGET_ENV"
      echo "Please add configuration to: $CONFIG_FILE"
      exit 1
    fi
    
    echo "✅ AKS Configuration loaded:"
    echo "   Environment: $TARGET_ENV"
    echo "   Cluster: $AKS_CLUSTER"
    echo "   Resource Group: $AKS_RG"
    echo "   Region: $REGION"
    
    echo "aks_cluster=$AKS_CLUSTER" >> $GITHUB_OUTPUT
    echo "aks_resource_group=$AKS_RG" >> $GITHUB_OUTPUT
    echo "region=$REGION" >> $GITHUB_OUTPUT
```

### **Option 3: Environment-Based Naming Convention**

Use a standardized naming convention with environment-based interpolation.

#### **Workflow Implementation**

```yaml
- name: Generate AKS Configuration
  id: aks-config
  run: |
    TARGET_ENV="${{ steps.check.outputs.target_environment }}"
    echo "🔧 Generating AKS configuration for environment: $TARGET_ENV"
    
    # Base configuration - can be customized via repository variables
    CLUSTER_PREFIX="${{ vars.AKS_CLUSTER_PREFIX || 'aks' }}"
    RG_PREFIX="${{ vars.AKS_RG_PREFIX || 'rg-aks' }}"
    
    # Environment-specific mappings
    case "$TARGET_ENV" in
      "dev")
        ENV_SUFFIX="dev"
        REGION="${{ vars.AKS_REGION_DEV || 'eastus' }}"
        ;;
      "sqe")
        ENV_SUFFIX="sqe"
        REGION="${{ vars.AKS_REGION_SQE || 'eastus' }}"
        ;;
      "ppr")
        ENV_SUFFIX="preprod"
        REGION="${{ vars.AKS_REGION_PPR || 'westus2' }}"
        ;;
      "prod")
        ENV_SUFFIX="prod"
        REGION="${{ vars.AKS_REGION_PROD || 'westus2' }}"
        ;;
      *)
        echo "❌ Unknown environment: $TARGET_ENV"
        exit 1
        ;;
    esac
    
    # Generate cluster names
    AKS_CLUSTER="${CLUSTER_PREFIX}-${ENV_SUFFIX}-cluster"
    AKS_RG="${RG_PREFIX}-${ENV_SUFFIX}"
    
    echo "✅ Generated AKS Configuration:"
    echo "   Environment: $TARGET_ENV"
    echo "   Cluster: $AKS_CLUSTER"
    echo "   Resource Group: $AKS_RG"
    echo "   Region: $REGION"
    
    echo "aks_cluster=$AKS_CLUSTER" >> $GITHUB_OUTPUT
    echo "aks_resource_group=$AKS_RG" >> $GITHUB_OUTPUT
    echo "region=$REGION" >> $GITHUB_OUTPUT
```

## 🔧 **Complete Workflow Integration**

### **Updated validate-environment Job**

```yaml
validate-environment:
  runs-on: ubuntu-latest
  outputs:
    should_deploy: ${{ steps.check.outputs.should_deploy }}
    target_environment: ${{ steps.check.outputs.target_environment }}
    aks_cluster_name: ${{ steps.aks-config.outputs.aks_cluster }}
    aks_resource_group: ${{ steps.aks-config.outputs.aks_resource_group }}
    region: ${{ steps.aks-config.outputs.region }}
  steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Validate environment and branch rules
      id: check
      run: |
        # Existing environment validation logic...
        # (This determines TARGET_ENV and SHOULD_DEPLOY)
        
    - name: Dynamic AKS Configuration
      id: aks-config
      if: steps.check.outputs.should_deploy == 'true'
      run: |
        TARGET_ENV="${{ steps.check.outputs.target_environment }}"
        echo "🔧 Configuring AKS cluster for environment: $TARGET_ENV"
        
        # Option 1: Repository Variables (Recommended)
        case "$TARGET_ENV" in
          "dev")
            AKS_CLUSTER="${{ vars.AKS_CLUSTER_DEV }}"
            AKS_RG="${{ vars.AKS_RESOURCE_GROUP_DEV }}"
            REGION="${{ vars.AKS_REGION_DEV || 'eastus' }}"
            ;;
          "sqe")
            AKS_CLUSTER="${{ vars.AKS_CLUSTER_SQE }}"
            AKS_RG="${{ vars.AKS_RESOURCE_GROUP_SQE }}"
            REGION="${{ vars.AKS_REGION_SQE || 'eastus' }}"
            ;;
          "ppr")
            AKS_CLUSTER="${{ vars.AKS_CLUSTER_PPR }}"
            AKS_RG="${{ vars.AKS_RESOURCE_GROUP_PPR }}"
            REGION="${{ vars.AKS_REGION_PPR || 'westus2' }}"
            ;;
          "prod")
            AKS_CLUSTER="${{ vars.AKS_CLUSTER_PROD }}"
            AKS_RG="${{ vars.AKS_RESOURCE_GROUP_PROD }}"
            REGION="${{ vars.AKS_REGION_PROD || 'westus2' }}"
            ;;
          *)
            echo "❌ Unknown environment: $TARGET_ENV"
            exit 1
            ;;
        esac
        
        # Fallback to naming convention if variables not set
        if [ -z "$AKS_CLUSTER" ]; then
          echo "⚠️ Repository variable not found, using naming convention"
          case "$TARGET_ENV" in
            "dev") AKS_CLUSTER="aks-dev-cluster" ;;
            "sqe") AKS_CLUSTER="aks-sqe-cluster" ;;
            "ppr") AKS_CLUSTER="aks-preprod-cluster" ;;
            "prod") AKS_CLUSTER="aks-prod-cluster" ;;
          esac
        fi
        
        if [ -z "$AKS_RG" ]; then
          echo "⚠️ Repository variable not found, using naming convention"
          case "$TARGET_ENV" in
            "dev") AKS_RG="rg-aks-dev" ;;
            "sqe") AKS_RG="rg-aks-sqe" ;;
            "ppr") AKS_RG="rg-aks-preprod" ;;
            "prod") AKS_RG="rg-aks-prod" ;;
          esac
        fi
        
        # Validate final configuration
        if [ -z "$AKS_CLUSTER" ]; then
          echo "❌ AKS cluster not configured for environment: $TARGET_ENV"
          exit 1
        fi
        
        if [ -z "$AKS_RG" ]; then
          echo "❌ AKS resource group not configured for environment: $TARGET_ENV"
          exit 1
        fi
        
        echo "✅ Final AKS Configuration:"
        echo "   Environment: $TARGET_ENV"
        echo "   Cluster: $AKS_CLUSTER"
        echo "   Resource Group: $AKS_RG"
        echo "   Region: ${REGION:-'default'}"
        
        echo "aks_cluster=$AKS_CLUSTER" >> $GITHUB_OUTPUT
        echo "aks_resource_group=$AKS_RG" >> $GITHUB_OUTPUT
        echo "region=${REGION:-'default'}" >> $GITHUB_OUTPUT
```

## 📋 **Repository Variables Setup Guide**

### **Using GitHub CLI**

```bash
# Required variables for each environment
gh variable set AKS_CLUSTER_DEV --body "aks-dev-cluster"
gh variable set AKS_RESOURCE_GROUP_DEV --body "rg-aks-dev"

gh variable set AKS_CLUSTER_SQE --body "aks-sqe-cluster"
gh variable set AKS_RESOURCE_GROUP_SQE --body "rg-aks-sqe"

gh variable set AKS_CLUSTER_PPR --body "aks-preprod-cluster"
gh variable set AKS_RESOURCE_GROUP_PPR --body "rg-aks-preprod"

gh variable set AKS_CLUSTER_PROD --body "aks-prod-cluster"
gh variable set AKS_RESOURCE_GROUP_PROD --body "rg-aks-prod"

# Optional: Region configuration
gh variable set AKS_REGION_DEV --body "eastus"
gh variable set AKS_REGION_SQE --body "eastus"
gh variable set AKS_REGION_PPR --body "westus2"
gh variable set AKS_REGION_PROD --body "westus2"

# Optional: Naming convention customization
gh variable set AKS_CLUSTER_PREFIX --body "aks"
gh variable set AKS_RG_PREFIX --body "rg-aks"
```

### **Using GitHub Web UI**

1. Navigate to **Repository → Settings → Secrets and variables → Actions**
2. Click **Variables** tab
3. Click **New repository variable**
4. Add each variable:
   - `AKS_CLUSTER_DEV` = `aks-dev-cluster`
   - `AKS_RESOURCE_GROUP_DEV` = `rg-aks-dev`
   - `AKS_CLUSTER_SQE` = `aks-sqe-cluster`
   - `AKS_RESOURCE_GROUP_SQE` = `rg-aks-sqe`
   - etc.

## 🔍 **Validation and Testing**

### **Configuration Validation Script**

```bash
#!/bin/bash
# validate-aks-config.sh

echo "🔍 Validating AKS Configuration..."

ENVIRONMENTS=("dev" "sqe" "ppr" "prod")

for env in "${ENVIRONMENTS[@]}"; do
  echo ""
  echo "Environment: $env"
  
  # Check cluster variable
  cluster_var="AKS_CLUSTER_${env^^}"
  cluster_value=$(gh variable get "$cluster_var" 2>/dev/null || echo "NOT_SET")
  echo "  Cluster Variable ($cluster_var): $cluster_value"
  
  # Check resource group variable
  rg_var="AKS_RESOURCE_GROUP_${env^^}"
  rg_value=$(gh variable get "$rg_var" 2>/dev/null || echo "NOT_SET")
  echo "  Resource Group Variable ($rg_var): $rg_value"
  
  # Validate configuration
  if [ "$cluster_value" = "NOT_SET" ] || [ "$rg_value" = "NOT_SET" ]; then
    echo "  Status: ❌ INCOMPLETE"
  else
    echo "  Status: ✅ CONFIGURED"
  fi
done

echo ""
echo "🎯 Configuration Summary:"
echo "To fix missing variables, run:"
echo "gh variable set AKS_CLUSTER_DEV --body 'your-cluster-name'"
echo "gh variable set AKS_RESOURCE_GROUP_DEV --body 'your-resource-group'"
```

### **Test Workflow**

```yaml
name: Test AKS Configuration

on:
  workflow_dispatch:
    inputs:
      test_environment:
        description: 'Environment to test'
        required: true
        type: choice
        options:
        - dev
        - sqe
        - ppr
        - prod

jobs:
  test-aks-config:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Test AKS Configuration
        run: |
          TARGET_ENV="${{ inputs.test_environment }}"
          echo "🧪 Testing AKS configuration for: $TARGET_ENV"
          
          case "$TARGET_ENV" in
            "dev")
              AKS_CLUSTER="${{ vars.AKS_CLUSTER_DEV }}"
              AKS_RG="${{ vars.AKS_RESOURCE_GROUP_DEV }}"
              ;;
            "sqe")
              AKS_CLUSTER="${{ vars.AKS_CLUSTER_SQE }}"
              AKS_RG="${{ vars.AKS_RESOURCE_GROUP_SQE }}"
              ;;
            "ppr")
              AKS_CLUSTER="${{ vars.AKS_CLUSTER_PPR }}"
              AKS_RG="${{ vars.AKS_RESOURCE_GROUP_PPR }}"
              ;;
            "prod")
              AKS_CLUSTER="${{ vars.AKS_CLUSTER_PROD }}"
              AKS_RG="${{ vars.AKS_RESOURCE_GROUP_PROD }}"
              ;;
          esac
          
          echo "Results:"
          echo "  Environment: $TARGET_ENV"
          echo "  Cluster: ${AKS_CLUSTER:-'NOT_CONFIGURED'}"
          echo "  Resource Group: ${AKS_RG:-'NOT_CONFIGURED'}"
          
          if [ -z "$AKS_CLUSTER" ] || [ -z "$AKS_RG" ]; then
            echo "❌ Configuration incomplete"
            exit 1
          else
            echo "✅ Configuration valid"
          fi
```

## 🎯 **Migration Guide**

### **Step 1: Set Repository Variables**
```bash
# Set all required variables using the commands above
gh variable set AKS_CLUSTER_DEV --body "aks-dev-cluster"
# ... etc for all environments
```

### **Step 2: Update Workflow**
- Replace hardcoded cluster assignments with dynamic configuration
- Update job outputs to include new configuration step

### **Step 3: Test Configuration**
- Run test workflow to validate all variables are set correctly
- Test with each environment

### **Step 4: Deploy Updated Workflow**
- Update shared workflow with dynamic configuration
- Monitor first few deployments to ensure smooth transition

## 📊 **Benefits**

### **✅ Advantages**
- **Flexibility**: Easy to change cluster names without code changes
- **Environment Isolation**: Clear separation of environment configurations
- **Scalability**: Easy to add new environments
- **Maintainability**: Centralized configuration management
- **Security**: Cluster names in repository variables, not hardcoded in code

### **🔧 Configuration Options**
- **Repository Variables**: Best for simple setups
- **JSON File**: Best for complex configurations with metadata
- **Naming Convention**: Best for standardized environments

### **🚀 Implementation**
- **Zero Downtime**: Backward compatible with fallback to naming convention
- **Gradual Migration**: Can implement incrementally
- **Validation**: Built-in configuration validation and error handling

---

**📝 Document Version**: 1.0  
**🗓️ Last Updated**: $(date -u)  
**👥 Maintained By**: DevOps Team  
**🔄 Review Cycle**: Quarterly