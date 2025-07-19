# Immediate Debug Steps - AKS Outputs Empty

## Issue Summary
- ✅ `target_environment` passes correctly from validate-environment to deploy
- ❌ `aks_cluster_name` and `aks_resource_group` are empty in deploy job
- ❌ Results in "resource-group" error in azure/aks-set-context@v3

## Critical Debug Steps

### Step 1: Add Emergency Debug in validate-environment Job

Add this **immediately after** your environment case logic in the `validate-environment` job:

```bash
# EMERGENCY DEBUG - Add this after your case statement
echo "🚨 EMERGENCY DEBUG - validate-environment job:"
echo "   - TARGET_ENV: '$TARGET_ENV'"
echo "   - AKS_CLUSTER: '$AKS_CLUSTER'"
echo "   - AKS_RG: '$AKS_RG'"
echo "   - SHOULD_DEPLOY: '$SHOULD_DEPLOY'"

# Check if AKS variables are actually set
if [ -z "$AKS_CLUSTER" ]; then
  echo "❌ CRITICAL: AKS_CLUSTER is EMPTY!"
  echo "   - Environment: $TARGET_ENV"
  echo "   - Expected secret: AKS_CLUSTER_NAME_${TARGET_ENV^^}"
else
  echo "✅ AKS_CLUSTER has value: '$AKS_CLUSTER'"
fi

if [ -z "$AKS_RG" ]; then
  echo "❌ CRITICAL: AKS_RG is EMPTY!"
  echo "   - Environment: $TARGET_ENV"
  echo "   - Expected secret: AKS_RESOURCE_GROUP_${TARGET_ENV^^}"
else
  echo "✅ AKS_RG has value: '$AKS_RG'"
fi

# Now write outputs with debug
echo "📝 Writing outputs to GITHUB_OUTPUT..."
echo "should_deploy=$SHOULD_DEPLOY" >> $GITHUB_OUTPUT
echo "target_environment=$TARGET_ENV" >> $GITHUB_OUTPUT
echo "aks_cluster_name=$AKS_CLUSTER" >> $GITHUB_OUTPUT
echo "aks_resource_group=$AKS_RG" >> $GITHUB_OUTPUT
echo "✅ Outputs written successfully"
```

### Step 2: Add Emergency Debug in deploy Job

Add this **immediately before** your helm-deploy action:

```yaml
- name: 🚨 EMERGENCY DEBUG - Check what deploy job receives
  run: |
    echo "🚨 EMERGENCY DEBUG - deploy job received:"
    echo "   - target_environment: '${{ needs.validate-environment.outputs.target_environment }}'"
    echo "   - aks_cluster_name: '${{ needs.validate-environment.outputs.aks_cluster_name }}'"
    echo "   - aks_resource_group: '${{ needs.validate-environment.outputs.aks_resource_group }}'"
    echo "   - should_deploy: '${{ needs.validate-environment.outputs.should_deploy }}'"
    echo ""
    
    # Check if values are truly empty
    if [ -z "${{ needs.validate-environment.outputs.aks_cluster_name }}" ]; then
      echo "❌ CRITICAL: aks_cluster_name is EMPTY in deploy job!"
    else
      echo "✅ aks_cluster_name received: '${{ needs.validate-environment.outputs.aks_cluster_name }}'"
    fi
    
    if [ -z "${{ needs.validate-environment.outputs.aks_resource_group }}" ]; then
      echo "❌ CRITICAL: aks_resource_group is EMPTY in deploy job!"
    else
      echo "✅ aks_resource_group received: '${{ needs.validate-environment.outputs.aks_resource_group }}'"
    fi
    
    echo ""
    echo "🔍 Additional context:"
    echo "   - Branch: ${{ github.ref }}"
    echo "   - Event: ${{ github.event_name }}"
    echo "   - Repository: ${{ github.repository }}"
```

## Expected Results Analysis

### Scenario A: validate-environment shows empty values
```
❌ CRITICAL: AKS_CLUSTER is EMPTY!
❌ CRITICAL: AKS_RG is EMPTY!
```
**Problem:** Secret assignment logic in validate-environment is broken
**Fix:** Check your case statement and secret names

### Scenario B: validate-environment shows values, deploy shows empty
```
# validate-environment:
✅ AKS_CLUSTER has value: 'my-cluster'
✅ AKS_RG has value: 'my-rg'

# deploy job:
❌ CRITICAL: aks_cluster_name is EMPTY in deploy job!
❌ CRITICAL: aks_resource_group is EMPTY in deploy job!
```
**Problem:** Job output mechanism is broken
**Fix:** Check job dependencies and output syntax

### Scenario C: Both show values but helm-deploy gets empty
**Problem:** Input passing to helm-deploy action
**Fix:** Check action input syntax

## Most Likely Issues

### Issue 1: Case Statement Problem
Your environment case might not be matching:
```bash
case "$TARGET_ENV" in
  "dev")  # Make sure this matches exactly what target_environment outputs
    AKS_CLUSTER="${{ secrets.AKS_CLUSTER_NAME_DEV }}"
    ;;
esac
```

### Issue 2: Secret Name Mismatch
Check if your secret names match exactly:
- `AKS_CLUSTER_NAME_DEV` (not `AKS_CLUSTER_NAME_DEVELOPMENT`)
- `AKS_RESOURCE_GROUP_DEV` (not `AKS_RESOURCE_GROUP_DEVELOPMENT`)

### Issue 3: Variable Scope
Variables might be set in wrong scope or overwritten.

## Immediate Action
1. Add both debug sections above
2. Run your workflow
3. Share the debug output from both jobs

This will immediately show us where the values are getting lost and we can fix it in the next iteration.

## Quick Check
Before running, verify in your repository secrets that you have:
- `AKS_CLUSTER_NAME_DEV` (or whatever environment you're testing)
- `AKS_RESOURCE_GROUP_DEV` (or whatever environment you're testing)

And they have actual values (not empty strings).