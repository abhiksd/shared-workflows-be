# Debug: Secrets Have Values But Show Empty

## Current Issue
- You've set proper values in repository secrets
- But workflow shows: `AKS_CLUSTER_NAME_DEV: ''` (empty)
- This suggests a secret access or scope issue

## Possible Causes

### 1. **Secret Names Don't Match Exactly**
Check that your repository secret names are **exactly**:
- `AKS_CLUSTER_NAME_DEV` (case sensitive)
- `AKS_RESOURCE_GROUP_DEV` (case sensitive)

### 2. **Secret Scope Issue**
If you have both repository secrets AND environment secrets with the same names, there might be a conflict.

### 3. **Secret Values Have Leading/Trailing Spaces**
Secret values might have invisible spaces that make them appear empty.

### 4. **Organization-Level Restrictions**
Your organization might have restrictions on secret access.

## Debugging Steps

### Step 1: Verify Exact Secret Names
Take a screenshot of your repository secrets page or copy the exact names you see.

### Step 2: Test with Different Secret Names
Temporarily create test secrets with different names to see if it's a naming issue:

Add this to your validate-environment step:
```bash
# Test with different secret names
echo "🔧 Testing secret access variations:"
echo "Test 1 - Original names:"
echo "  AKS_CLUSTER_NAME_DEV: '${{ secrets.AKS_CLUSTER_NAME_DEV }}'"
echo "  AKS_RESOURCE_GROUP_DEV: '${{ secrets.AKS_RESOURCE_GROUP_DEV }}'"

# Test if any other secrets work
echo "Test 2 - Known working secrets:"
echo "  AZURE_TENANT_ID: '${{ secrets.AZURE_TENANT_ID }}'"
echo "  ACR_LOGIN_SERVER: '${{ secrets.ACR_LOGIN_SERVER }}'"

# Test secret length
echo "Test 3 - Secret lengths:"
echo "  AKS_CLUSTER_NAME_DEV length: ${#'${{ secrets.AKS_CLUSTER_NAME_DEV }}'}"
echo "  AKS_RESOURCE_GROUP_DEV length: ${#'${{ secrets.AKS_RESOURCE_GROUP_DEV }}'}"
```

### Step 3: Create Test Secrets
Create these test secrets in your repository:
- `TEST_CLUSTER_NAME` = `test-cluster-value`
- `TEST_RESOURCE_GROUP` = `test-rg-value`

Then test access:
```bash
echo "🔧 Testing with test secrets:"
echo "  TEST_CLUSTER_NAME: '${{ secrets.TEST_CLUSTER_NAME }}'"
echo "  TEST_RESOURCE_GROUP: '${{ secrets.TEST_RESOURCE_GROUP }}'"
```

### Step 4: Check for Environment Conflicts
If you have environment secrets with the same names, they might be interfering. 

Remove the `environment:` line from your deploy job temporarily:
```yaml
deploy:
  runs-on: sld-helper
  needs: [validate-environment, setup, build]
  # environment: ${{ needs.validate-environment.outputs.target_environment }}  # Comment this out
```

## Alternative: Use Hardcoded Values Temporarily

To test if the issue is secret access, temporarily hardcode the values:

```bash
case "$TARGET_ENV" in
  "dev")
    # Temporary hardcoded values for testing
    AKS_CLUSTER="your-actual-cluster-name-here"
    AKS_RG="your-actual-resource-group-here"
    echo "🔧 TEMP: Using hardcoded values for testing"
    echo "🔍 Dev environment - AKS_CLUSTER: '$AKS_CLUSTER', AKS_RG: '$AKS_RG'"
    ;;
esac
```

If hardcoded values work but secrets don't, it confirms the issue is with secret access.

## Quick Verification Questions

1. **Are you the repository owner or admin?** Secret access might be restricted.

2. **What exact names do you see in Settings → Secrets?** Copy them exactly.

3. **Do other secrets work?** Like `AZURE_TENANT_ID` - does that show a value?

4. **Are there environment secrets with the same names?** This can cause conflicts.

5. **When did you create the secrets?** Sometimes there's a delay in availability.

## Immediate Action

1. **Add the debugging code** from Step 2 above to see what's actually happening
2. **Try the test secrets** approach to isolate the issue
3. **Share the debug output** so we can see exactly what's being accessed

The issue is likely one of:
- Secret naming mismatch
- Environment/repository secret conflict  
- Access permissions
- Hidden characters in secret values

Let's identify which one it is!