# Debug Secret Reading in validate-environment Job

## Current Issue
- Secrets added to both Repository secrets and Environment secrets
- Still getting empty AKS cluster name and resource group
- Debug shows: `AKS Cluster Name: ` (empty)

## Root Cause
The secrets are not being read correctly in the `validate-environment` job.

## Emergency Debug Steps

### Step 1: Add Secret Reading Debug
Add this **at the beginning** of your `validate-environment` job step:

```bash
echo "🔍 DEBUG: Secret reading test"
echo "Environment detected: $TARGET_ENV"
echo "Testing secret access:"

# Test direct secret access
echo "Direct secret test:"
echo "  AKS_CLUSTER_NAME_DEV: '${{ secrets.AKS_CLUSTER_NAME_DEV }}'"
echo "  AKS_RESOURCE_GROUP_DEV: '${{ secrets.AKS_RESOURCE_GROUP_DEV }}'"
echo "  AKS_CLUSTER_NAME_STAGING: '${{ secrets.AKS_CLUSTER_NAME_STAGING }}'"
echo "  AKS_RESOURCE_GROUP_STAGING: '${{ secrets.AKS_RESOURCE_GROUP_STAGING }}'"

# Check if secrets are empty
if [ -z "${{ secrets.AKS_CLUSTER_NAME_DEV }}" ]; then
  echo "❌ AKS_CLUSTER_NAME_DEV is EMPTY!"
else
  echo "✅ AKS_CLUSTER_NAME_DEV has value"
fi

if [ -z "${{ secrets.AKS_RESOURCE_GROUP_DEV }}" ]; then
  echo "❌ AKS_RESOURCE_GROUP_DEV is EMPTY!"
else
  echo "✅ AKS_RESOURCE_GROUP_DEV has value"
fi
```

### Step 2: Debug Your Case Statement
Add this **inside your case statement** for the dev environment:

```bash
case "$TARGET_ENV" in
  "dev")
    echo "🔍 DEBUG: Processing dev environment"
    echo "  Before assignment:"
    echo "    AKS_CLUSTER_NAME_DEV secret: '${{ secrets.AKS_CLUSTER_NAME_DEV }}'"
    echo "    AKS_RESOURCE_GROUP_DEV secret: '${{ secrets.AKS_RESOURCE_GROUP_DEV }}'"
    
    AKS_CLUSTER="${{ secrets.AKS_CLUSTER_NAME_DEV }}"
    AKS_RG="${{ secrets.AKS_RESOURCE_GROUP_DEV }}"
    
    echo "  After assignment:"
    echo "    AKS_CLUSTER: '$AKS_CLUSTER'"
    echo "    AKS_RG: '$AKS_RG'"
    
    # Check deployment conditions
    if [[ "$GITHUB_REF" == "refs/heads/develop" ]] || [[ "$EVENT_NAME" == "workflow_dispatch" ]]; then
      SHOULD_DEPLOY="true"
      echo "✅ Dev deployment approved"
    else
      echo "❌ Dev deployment blocked"
    fi
    ;;
esac
```

### Step 3: Debug Output Writing
Add this **before writing outputs**:

```bash
echo "🔍 DEBUG: About to write outputs"
echo "  SHOULD_DEPLOY: '$SHOULD_DEPLOY'"
echo "  TARGET_ENV: '$TARGET_ENV'"
echo "  AKS_CLUSTER: '$AKS_CLUSTER'"
echo "  AKS_RG: '$AKS_RG'"

# Write outputs
echo "should_deploy=$SHOULD_DEPLOY" >> $GITHUB_OUTPUT
echo "target_environment=$TARGET_ENV" >> $GITHUB_OUTPUT
echo "aks_cluster_name=$AKS_CLUSTER" >> $GITHUB_OUTPUT
echo "aks_resource_group=$AKS_RG" >> $GITHUB_OUTPUT

echo "✅ Outputs written to GITHUB_OUTPUT"
```

## Most Likely Issues

### Issue 1: Wrong Environment Branch
You're testing on a branch that doesn't match the case statement:
- If running on `develop` branch → should detect `dev`
- If running on `main` branch → should detect `staging` 
- Check your environment detection logic

### Issue 2: Case Statement Not Executing
Your case statement might not be matching the detected environment.

### Issue 3: Secret Names Mismatch
Secret names in repository don't match what the code expects.

### Issue 4: Empty Secret Values
Secrets exist but have empty values.

## Quick Verification

**Before running the debug:**

1. **Check Repository Secrets**: Go to Settings → Secrets and variables → Actions
   - Verify `AKS_CLUSTER_NAME_DEV` exists and has a value
   - Verify `AKS_RESOURCE_GROUP_DEV` exists and has a value

2. **Check Branch**: What branch are you running on?
   - `develop` → should use DEV secrets
   - `main` → should use STAGING secrets
   - `release/*` → should use PROD secrets

3. **Check Secret Values**: Ensure secrets have actual values, not empty strings

## Expected Debug Output

**If secrets are working:**
```
✅ AKS_CLUSTER_NAME_DEV has value
🔍 DEBUG: Processing dev environment
  AKS_CLUSTER: 'your-cluster-name'
  AKS_RG: 'your-resource-group'
```

**If secrets are empty:**
```
❌ AKS_CLUSTER_NAME_DEV is EMPTY!
🔍 DEBUG: Processing dev environment  
  AKS_CLUSTER: ''
  AKS_RG: ''
```

**If case not matching:**
```
✅ AKS_CLUSTER_NAME_DEV has value
(No "Processing dev environment" message)
```

## Immediate Action

1. Add the debug code above to your `validate-environment` job
2. Run the workflow
3. Share the debug output

This will immediately show us:
- Are the secrets being read correctly?
- Is the case statement executing?
- What values are being assigned to variables?

The debug output will pinpoint exactly where the issue is!