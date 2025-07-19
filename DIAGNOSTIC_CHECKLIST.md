# AKS Deployment Diagnostic Checklist

## Issue: AKS resource group and cluster name are still empty

Based on your error output, both values are empty (`""`) in the helm-deploy action:
```
❌ ERROR: aks_resource_group is empty or not provided
❌ ERROR: aks_cluster_name is empty or not provided
```

## Immediate Diagnostic Steps

### 1. **Check Action Source**
Your workflow is using: `se-bb-admin/dces-n630-git-action/.github/actions/helm-deploy@N630-6313-new-pipelines`

This is **NOT** the local repository we've been fixing. The fixes we made are in your local repository, but your workflow is using a different external repository.

**Action Required:**
- Either update the external repository with our fixes
- Or change your workflow to use the local action: `./.github/actions/helm-deploy`

### 2. **Check Workflow File**
Look for your workflow file and verify the action path:

```yaml
# CURRENT (using external repo)
uses: se-bb-admin/dces-n630-git-action/.github/actions/helm-deploy@N630-6313-new-pipelines

# SHOULD BE (using local fixes)
uses: ./.github/actions/helm-deploy
```

### 3. **Check validate-environment Job Output**
Look for this section in your workflow logs to see if the validation job ran:

```bash
📊 Environment validation results:
   - Should deploy: true/false
   - Target environment: dev/staging/production
   - AKS cluster name: [should show cluster name]
   - AKS resource group: [should show resource group]
```

### 4. **Verify Repository Secrets**
Check that these secrets are set in your GitHub repository settings:

**For Development:**
- `AKS_CLUSTER_NAME_DEV`
- `AKS_RESOURCE_GROUP_DEV`

**For Staging:**
- `AKS_CLUSTER_NAME_STAGING`
- `AKS_RESOURCE_GROUP_STAGING`

**For Production:**
- `AKS_CLUSTER_NAME_PROD`
- `AKS_RESOURCE_GROUP_PROD`

## Quick Fix Options

### Option 1: Use Local Actions (Recommended)
Update your workflow file to use the local actions we've fixed:

```yaml
- name: Deploy to AKS
  uses: ./.github/actions/helm-deploy  # Use local action
  with:
    environment: ${{ needs.validate-environment.outputs.target_environment }}
    # ... other parameters
```

### Option 2: Update External Repository
If you need to use the external repository, copy our fixes to that repository:

1. Copy the fixed `.github/actions/helm-deploy/action.yml`
2. Copy the fixed `.github/workflows/shared-deploy.yml`
3. Push to the `N630-6313-new-pipelines` branch

### Option 3: Debug Current Setup
Add this debugging step to your workflow to see what the validate-environment job actually outputs:

```yaml
- name: Debug validate-environment outputs
  run: |
    echo "🔍 Debugging validate-environment job outputs:"
    echo "   - should_deploy: ${{ needs.validate-environment.outputs.should_deploy }}"
    echo "   - target_environment: ${{ needs.validate-environment.outputs.target_environment }}"
    echo "   - aks_cluster_name: ${{ needs.validate-environment.outputs.aks_cluster_name }}"
    echo "   - aks_resource_group: ${{ needs.validate-environment.outputs.aks_resource_group }}"
```

## Common Issues and Solutions

### Issue 1: Wrong Action Source
**Problem:** Using external repository that doesn't have fixes
**Solution:** Change to local action path or update external repository

### Issue 2: Missing Secrets
**Problem:** Repository secrets not set
**Solution:** Add required AKS_* secrets in repository settings

### Issue 3: Wrong Environment Detection
**Problem:** Branch doesn't match environment rules
**Solution:** Check branch naming and environment detection logic

### Issue 4: Job Dependencies Missing
**Problem:** validate-environment job not running or failing
**Solution:** Check workflow job dependencies and conditions

## Verification Steps

1. **Check action source in workflow file**
2. **Verify repository secrets are set**
3. **Look for validate-environment job output in logs**
4. **Confirm branch triggers correct environment**
5. **Validate job dependencies include validate-environment**

## Next Steps

1. **Identify which repository/branch your workflow is actually using**
2. **Either switch to local actions or update the external repository**
3. **Verify the validate-environment job is running and setting outputs**
4. **Check that repository secrets are properly configured**

The root cause is likely that you're using an external action repository that doesn't have our fixes, rather than the local repository we've been updating.