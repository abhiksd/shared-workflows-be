# AKS Configuration Refactoring Guide

## 🎯 Overview

This document explains the refactoring of AKS cluster and resource group configuration from environment-specific variables to a unified, cleaner approach. The change improves maintainability and reduces configuration complexity while maintaining the same functionality.

## 🔄 What Changed

### **Before: Environment-Specific Variables**

Previously, the shared workflow used separate environment variables for each environment:

```yaml
env:
  REGISTRY: ${{ secrets.ACR_LOGIN_SERVER }}
  # AKS Cluster Configuration - Update these values to change cluster settings
  AKS_CLUSTER_NAME_DEV: "aks-dev-cluster"
  AKS_RESOURCE_GROUP_DEV: "rg-aks-dev"
  AKS_CLUSTER_NAME_SQE: "aks-sqe-cluster"
  AKS_RESOURCE_GROUP_SQE: "rg-aks-sqe"
  AKS_CLUSTER_NAME_PPR: "aks-preprod-cluster"
  AKS_RESOURCE_GROUP_PPR: "rg-aks-preprod"
  AKS_CLUSTER_NAME_PROD: "aks-prod-cluster"
  AKS_RESOURCE_GROUP_PROD: "rg-aks-prod"
```

### **After: Dynamic Environment-Based Configuration**

Now, the configuration is set dynamically based on the target environment:

```yaml
env:
  REGISTRY: ${{ secrets.ACR_LOGIN_SERVER }}
```

The AKS cluster and resource group values are set directly in the environment validation logic:

```bash
case "$TARGET_ENV" in
  "dev")
    AKS_CLUSTER="aks-dev-cluster"
    AKS_RG="rg-aks-dev"
    ;;
  "sqe")
    AKS_CLUSTER="aks-sqe-cluster"
    AKS_RG="rg-aks-sqe"
    ;;
  "ppr")
    AKS_CLUSTER="aks-preprod-cluster"
    AKS_RG="rg-aks-preprod"
    ;;
  "prod")
    AKS_CLUSTER="aks-prod-cluster"
    AKS_RG="rg-aks-prod"
    ;;
esac
```

## 📊 Benefits of the Refactoring

### **1. Cleaner Environment Variables Section**
- ✅ Reduced from 8 environment variables to 1
- ✅ Simplified workflow file structure
- ✅ Easier to understand at a glance

### **2. Better Maintainability**
- ✅ AKS configuration co-located with environment logic
- ✅ Single source of truth for each environment
- ✅ Easier to add new environments

### **3. Improved Consistency**
- ✅ Unified variable naming (`aks_cluster_name`, `aks_resource_group`)
- ✅ Consistent approach across all environments
- ✅ Removed the `_1` suffix from output variable names

### **4. Enhanced Flexibility**
- ✅ Environment-specific logic can be extended easily
- ✅ Validation and configuration in the same place
- ✅ Better separation of concerns

## 🔧 Current AKS Configuration

### **Environment Mapping**

| Environment | AKS Cluster Name | Resource Group |
|-------------|------------------|----------------|
| **DEV** | `aks-dev-cluster` | `rg-aks-dev` |
| **SQE** | `aks-sqe-cluster` | `rg-aks-sqe` |
| **PPR** | `aks-preprod-cluster` | `rg-aks-preprod` |
| **PROD** | `aks-prod-cluster` | `rg-aks-prod` |

### **Job Outputs (Updated)**

The workflow now exposes cleaner output variable names:

```yaml
outputs:
  should_deploy: ${{ steps.check.outputs.should_deploy }}
  target_environment: ${{ steps.check.outputs.target_environment }}
  aks_cluster_name: ${{ steps.check.outputs.aks_cluster_name }}    # ✅ Cleaned up
  aks_resource_group: ${{ steps.check.outputs.aks_resource_group }} # ✅ Cleaned up
```

**Previously:** `aks_cluster_name_1`, `aks_resource_group_1`  
**Now:** `aks_cluster_name`, `aks_resource_group`

## 🔍 Technical Implementation Details

### **Environment Validation Logic**

Each environment case now sets the AKS configuration directly:

```bash
"dev")
  if [[ "$GITHUB_REF" == "refs/heads/develop" ]] || [[ "$GITHUB_REF" == "refs/heads/dev" ]] || [[ "$EVENT_NAME" == "workflow_dispatch" ]]; then
    SHOULD_DEPLOY="true"
    AKS_CLUSTER="aks-dev-cluster"           # ✅ Set directly
    AKS_RG="rg-aks-dev"                    # ✅ Set directly
    # ... validation logic
  fi
  ;;
```

### **Output Generation**

The validation step outputs the dynamically set values:

```bash
echo "aks_cluster_name=$AKS_CLUSTER" >> $GITHUB_OUTPUT
echo "aks_resource_group=$AKS_RG" >> $GITHUB_OUTPUT
```

### **Deploy Job Integration**

The deploy job uses the cleaned-up output variable names:

```yaml
- name: Deploy to AKS
  uses: ./.github/actions/helm-deploy
  with:
    environment: ${{ needs.validate-environment.outputs.target_environment }}
    aks_cluster_name: ${{ needs.validate-environment.outputs.aks_cluster_name }}
    aks_resource_group: ${{ needs.validate-environment.outputs.aks_resource_group }}
    # ... other parameters
```

## 🛠️ Configuration Management

### **How to Update AKS Configuration**

To change the AKS cluster or resource group for any environment:

1. **Navigate to**: `.github/workflows/shared-deploy.yml`
2. **Find the environment validation section** (around line 210)
3. **Update the values** in the appropriate case statement:

```bash
"your-environment")
  # ... validation logic
  AKS_CLUSTER="your-new-cluster-name"
  AKS_RG="your-new-resource-group"
  # ... rest of logic
  ;;
```

### **Adding New Environments**

To add a new environment (e.g., `staging`):

1. **Add the case** in the environment validation:
```bash
"staging")
  if [[ "$GITHUB_REF" == "refs/heads/staging" ]] || [[ "$EVENT_NAME" == "workflow_dispatch" ]]; then
    SHOULD_DEPLOY="true"
    AKS_CLUSTER="aks-staging-cluster"
    AKS_RG="rg-aks-staging"
    echo "✅ Staging deployment approved"
  fi
  ;;
```

2. **Update environment auto-detection** if needed
3. **Add Helm values file** (`helm/values-staging.yaml`)
4. **Update documentation**

## 📋 Migration Impact

### **Backward Compatibility**
- ✅ **No breaking changes** for calling workflows
- ✅ **Same input parameters** required
- ✅ **Same deployment behavior** maintained
- ✅ **Same security controls** preserved

### **Output Variable Changes**
| Old Variable Name | New Variable Name | Status |
|-------------------|-------------------|--------|
| `aks_cluster_name_1` | `aks_cluster_name` | ✅ Updated |
| `aks_resource_group_1` | `aks_resource_group` | ✅ Updated |

### **No Changes Required For**
- ✅ Calling workflows (application `deploy.yml`)
- ✅ Helm chart configurations
- ✅ Environment-specific values files
- ✅ Security controls and authorization
- ✅ Branch validation logic
- ✅ Manual deployment capabilities

## 🔍 Testing and Validation

### **Pre-Deployment Checks**

The workflow includes comprehensive validation:

```bash
echo "🔍 What deploy job received from validate-environment:"
echo "aks_cluster_name: '${{ needs.validate-environment.outputs.aks_cluster_name }}'"
echo "aks_resource_group: '${{ needs.validate-environment.outputs.aks_resource_group }}'"

if [ -z "${{ needs.validate-environment.outputs.aks_cluster_name }}" ]; then
  echo "❌ aks_cluster_name is NULL/EMPTY in deploy job"
  exit 1
fi

if [ -z "${{ needs.validate-environment.outputs.aks_resource_group }}" ]; then
  echo "❌ aks_resource_group is NULL/EMPTY in deploy job"
  exit 1
fi
```

### **Verification Steps**

To verify the refactoring is working correctly:

1. **Check workflow logs** for AKS configuration output
2. **Verify environment-specific values** are set correctly
3. **Confirm deployment targets** the correct cluster
4. **Test manual deployments** across all environments

## 🎯 Best Practices

### **Configuration Management**
1. **Centralized Configuration**: All AKS settings in one place
2. **Environment Consistency**: Use consistent naming patterns
3. **Documentation Updates**: Keep documentation in sync with changes
4. **Testing**: Test changes across all environments

### **Naming Conventions**
- **Cluster Names**: `aks-{environment}-cluster`
- **Resource Groups**: `rg-aks-{environment}`
- **Variables**: Use clear, descriptive names
- **Consistency**: Maintain patterns across environments

## 📚 Related Documentation

- [Deployment Security Guide](DEPLOYMENT_SECURITY_GUIDE.md)
- [Final Deployment Strategy](FINAL_DEPLOYMENT_STRATEGY.md)
- [Spring Boot Profiling Guide](SPRING_BOOT_PROFILING_GUIDE.md)
- [Emergency Bypass Guide](EMERGENCY_BYPASS_GUIDE.md)

## 🎉 Summary

The AKS configuration refactoring provides:

### **✅ Achievements**
- **Simplified Configuration**: Reduced complexity and improved readability
- **Better Maintainability**: Easier to understand and modify
- **Cleaner Code**: Removed redundant environment variables
- **Improved Consistency**: Unified approach across environments
- **Enhanced Flexibility**: Easier to add new environments
- **No Breaking Changes**: Maintains full backward compatibility

### **🔧 Technical Benefits**
- **Single Source of Truth**: Environment-specific configuration co-located
- **Dynamic Assignment**: Values set based on environment logic
- **Cleaner Outputs**: Simplified variable names without suffixes
- **Better Validation**: Enhanced error checking and debugging
- **Improved Debugging**: Clearer output variable names

### **📈 Business Benefits**
- **Faster Development**: Easier configuration management
- **Reduced Errors**: Less complex configuration reduces mistakes
- **Better Scalability**: Easy to add new environments
- **Improved Maintenance**: Simpler troubleshooting and updates

The refactoring maintains all existing functionality while providing a cleaner, more maintainable foundation for AKS configuration management across all deployment environments.