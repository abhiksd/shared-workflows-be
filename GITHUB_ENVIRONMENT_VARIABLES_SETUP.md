# GitHub Environment Variables Setup for Dynamic AKS Configuration

## 🎯 **Overview**

This guide explains how to configure GitHub environment variables to enable dynamic AKS cluster selection based on the deployment environment. Each GitHub environment (dev, sqe, ppr, prod) will have the same variable names but different values specific to that environment.

## 🏗️ **Environment Variable Structure**

Each environment should have these **same variable names** with **environment-specific values**:

| Variable Name | Description | Required | Example Values |
|---------------|-------------|----------|----------------|
| `AKS_CLUSTER_NAME` | Name of the AKS cluster | ✅ Yes | `aks-dev-cluster`, `aks-prod-cluster` |
| `AKS_RESOURCE_GROUP` | Resource group containing the cluster | ✅ Yes | `rg-aks-dev`, `rg-aks-prod` |
| `AKS_REGION` | Azure region for the cluster | ⚠️ Optional | `eastus`, `westus2` |

## 🔧 **Setup Instructions**

### **Step 1: Create GitHub Environments**

1. Navigate to your repository on GitHub
2. Go to **Settings** → **Environments**
3. Create four environments:
   - `dev`
   - `sqe` 
   - `ppr`
   - `prod`

### **Step 2: Configure Environment Variables**

For **each environment**, add the same variable names with environment-specific values:

#### **DEV Environment Variables**
```
Variable Name: AKS_CLUSTER_NAME
Value: aks-dev-cluster

Variable Name: AKS_RESOURCE_GROUP  
Value: rg-aks-dev

Variable Name: AKS_REGION
Value: eastus
```

#### **SQE Environment Variables**
```
Variable Name: AKS_CLUSTER_NAME
Value: aks-sqe-cluster

Variable Name: AKS_RESOURCE_GROUP
Value: rg-aks-sqe

Variable Name: AKS_REGION
Value: eastus
```

#### **PPR Environment Variables**
```
Variable Name: AKS_CLUSTER_NAME
Value: aks-preprod-cluster

Variable Name: AKS_RESOURCE_GROUP
Value: rg-aks-preprod

Variable Name: AKS_REGION
Value: westus2
```

#### **PROD Environment Variables**
```
Variable Name: AKS_CLUSTER_NAME
Value: aks-prod-cluster

Variable Name: AKS_RESOURCE_GROUP
Value: rg-aks-prod

Variable Name: AKS_REGION
Value: westus2
```

### **Step 3: Detailed Setup Process**

#### **For Each Environment (dev, sqe, ppr, prod):**

1. **Click on the environment name** (e.g., "dev")
2. **Scroll down to "Environment variables"**
3. **Click "Add variable"**
4. **Add the three variables**:

   **Variable 1:**
   - Name: `AKS_CLUSTER_NAME`
   - Value: `[environment-specific cluster name]`
   - Click "Add variable"

   **Variable 2:**
   - Name: `AKS_RESOURCE_GROUP`
   - Value: `[environment-specific resource group]`
   - Click "Add variable"

   **Variable 3:**
   - Name: `AKS_REGION`
   - Value: `[environment-specific region]`
   - Click "Add variable"

5. **Repeat for all four environments** with their respective values

## 📊 **Configuration Examples**

### **Example 1: Standard Naming Convention**
```yaml
dev:
  AKS_CLUSTER_NAME: "aks-dev-cluster"
  AKS_RESOURCE_GROUP: "rg-aks-dev"
  AKS_REGION: "eastus"

sqe:
  AKS_CLUSTER_NAME: "aks-sqe-cluster"
  AKS_RESOURCE_GROUP: "rg-aks-sqe"
  AKS_REGION: "eastus"

ppr:
  AKS_CLUSTER_NAME: "aks-preprod-cluster"
  AKS_RESOURCE_GROUP: "rg-aks-preprod"
  AKS_REGION: "westus2"

prod:
  AKS_CLUSTER_NAME: "aks-prod-cluster"
  AKS_RESOURCE_GROUP: "rg-aks-prod"
  AKS_REGION: "westus2"
```

### **Example 2: Organization-Specific Naming**
```yaml
dev:
  AKS_CLUSTER_NAME: "mycompany-k8s-development"
  AKS_RESOURCE_GROUP: "mycompany-rg-k8s-dev"
  AKS_REGION: "centralus"

sqe:
  AKS_CLUSTER_NAME: "mycompany-k8s-testing"
  AKS_RESOURCE_GROUP: "mycompany-rg-k8s-test"
  AKS_REGION: "centralus"

ppr:
  AKS_CLUSTER_NAME: "mycompany-k8s-staging"
  AKS_RESOURCE_GROUP: "mycompany-rg-k8s-staging"
  AKS_REGION: "eastus2"

prod:
  AKS_CLUSTER_NAME: "mycompany-k8s-production"
  AKS_RESOURCE_GROUP: "mycompany-rg-k8s-prod"
  AKS_REGION: "eastus2"
```

## 🔍 **Validation and Testing**

### **Step 1: Verify Configuration**

Create a test workflow to validate your environment variable setup:

```yaml
name: Test AKS Environment Variables

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
  test-config:
    runs-on: ubuntu-latest
    environment: ${{ inputs.test_environment }}
    steps:
      - name: Test Environment Variables
        run: |
          echo "🧪 Testing environment: ${{ inputs.test_environment }}"
          echo ""
          echo "📋 Environment Variables:"
          echo "   AKS_CLUSTER_NAME: ${{ vars.AKS_CLUSTER_NAME }}"
          echo "   AKS_RESOURCE_GROUP: ${{ vars.AKS_RESOURCE_GROUP }}"
          echo "   AKS_REGION: ${{ vars.AKS_REGION }}"
          echo ""
          
          # Validation
          if [ -z "${{ vars.AKS_CLUSTER_NAME }}" ]; then
            echo "❌ AKS_CLUSTER_NAME is not set"
            exit 1
          fi
          
          if [ -z "${{ vars.AKS_RESOURCE_GROUP }}" ]; then
            echo "❌ AKS_RESOURCE_GROUP is not set"
            exit 1
          fi
          
          echo "✅ Configuration is valid for ${{ inputs.test_environment }}"
```

### **Step 2: Run Validation**

1. Go to **Actions** tab in your repository
2. Find "Test AKS Environment Variables" workflow
3. Click **Run workflow**
4. Select each environment and run the test
5. Verify all variables are correctly set

## 🚨 **Troubleshooting**

### **Common Issues**

#### **Issue 1: Variables Not Found**
```
Error: AKS_CLUSTER_NAME environment variable not set, using naming convention
```

**Solution:**
- Verify the environment name matches exactly (case-sensitive)
- Check that variables are set in the correct environment
- Ensure variable names are exactly: `AKS_CLUSTER_NAME`, `AKS_RESOURCE_GROUP`, `AKS_REGION`

#### **Issue 2: Wrong Environment Selected**
```
Error: Deployment using wrong cluster for environment
```

**Solution:**
- Verify the workflow is using the correct `environment:` context
- Check that the environment name matches the GitHub environment configuration

#### **Issue 3: Fallback Values Being Used**
```
Warning: AKS_CLUSTER_NAME environment variable not set, using naming convention
```

**Solution:**
- This is expected behavior if environment variables are not configured
- The workflow will use fallback naming convention values
- Set up environment variables to use custom cluster names

### **Verification Commands**

```bash
# Check if environment exists
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/owner/repo/environments

# Check environment variables (requires admin access)
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/owner/repo/environments/dev/variables
```

## 🔒 **Security Considerations**

### **Environment Protection Rules**

You can add protection rules to environments for additional security:

1. **Go to Environment Settings**
2. **Configure Protection Rules:**
   - Required reviewers
   - Wait timer
   - Deployment branches

### **Example Protection Setup**

```yaml
dev:
  - No protection (allow automatic deployments)

sqe:
  - No protection (allow automatic deployments)
  
ppr:
  - Required reviewers: DevOps team
  - Deployment branches: release/* only
  
prod:
  - Required reviewers: Senior DevOps + Security team
  - Wait timer: 5 minutes
  - Deployment branches: tags only
```

## 📝 **Best Practices**

### **✅ DO**
- **Use consistent variable names** across all environments
- **Document your cluster naming convention** 
- **Test configuration** before deploying to production
- **Use environment protection rules** for sensitive environments
- **Keep cluster names descriptive** but not too long

### **❌ DON'T**
- **Don't use different variable names** per environment
- **Don't hardcode sensitive information** in variable values
- **Don't forget to set up all required environments**
- **Don't use spaces or special characters** in cluster names

## 🎯 **Migration from Hardcoded Values**

### **Before (Hardcoded)**
```yaml
case "$TARGET_ENV" in
  "dev")
    AKS_CLUSTER="aks-dev-cluster"
    AKS_RG="rg-aks-dev"
    ;;
esac
```

### **After (Environment Variables)**
```yaml
# Load from environment variables
AKS_CLUSTER="${{ vars.AKS_CLUSTER_NAME }}"
AKS_RG="${{ vars.AKS_RESOURCE_GROUP }}"

# Fallback if not set
if [ -z "$AKS_CLUSTER" ]; then
  AKS_CLUSTER="aks-dev-cluster"  # fallback
fi
```

## 🚀 **Benefits**

### **✅ Advantages**
- **Environment Isolation**: Each environment has its own configuration
- **Security**: Environment-specific access controls
- **Flexibility**: Easy to change cluster names without code changes
- **Scalability**: Easy to add new environments
- **Consistency**: Same variable names across all environments
- **Auditability**: Changes tracked in GitHub environment history

### **🎯 Use Cases**
- **Multi-region deployments**: Different regions per environment
- **Organization-specific naming**: Custom cluster naming conventions
- **Environment-specific configurations**: Different cluster sizes or configurations
- **Compliance requirements**: Separate clusters for different environments

---

**📝 Document Version**: 1.0  
**🗓️ Last Updated**: $(date -u)  
**👥 Maintained By**: DevOps Team  
**🔄 Review Cycle**: Monthly