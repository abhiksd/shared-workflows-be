# Debug Workflow Outputs - Step by Step

## Current Issue
Even after making the changes locally, you're still getting:
```
❌ ERROR: aks_resource_group is empty or not provided
❌ ERROR: aks_cluster_name is empty or not provided
```

## Step-by-Step Debugging

### Step 1: Check validate-environment Job Output
In your GitHub Actions logs, look for the `validate-environment` job and find this section:

```bash
📊 Environment validation results:
   - Should deploy: [value]
   - Target environment: [value]  
   - AKS cluster name: [value]
   - AKS resource group: [value]
```

**What to check:**
- Are all 4 values showing correctly?
- Is the target environment detected correctly (dev/staging/production)?
- Are the AKS cluster name and resource group showing actual values or empty?

### Step 2: Check Repository Secrets
Go to your GitHub repository → Settings → Secrets and variables → Actions

Verify these secrets exist and have values:

**For DEV environment:**
- `AKS_CLUSTER_NAME_DEV` = your dev cluster name
- `AKS_RESOURCE_GROUP_DEV` = your dev resource group

**For STAGING environment:**
- `AKS_CLUSTER_NAME_STAGING` = your staging cluster name  
- `AKS_RESOURCE_GROUP_STAGING` = your staging resource group

**For PRODUCTION environment:**
- `AKS_CLUSTER_NAME_PROD` = your prod cluster name
- `AKS_RESOURCE_GROUP_PROD` = your prod resource group

### Step 3: Check Environment Detection
Based on your branch, verify the environment is detected correctly:

- **develop branch** → should detect `dev` environment
- **main branch** → should detect `staging` environment  
- **release/* branch or tags** → should detect `production` environment

### Step 4: Check deploy Job Debug Output
Look for the debug output in your `deploy` job:

```bash
🔍 Debugging validate-environment job outputs:
   - should_deploy: [value]
   - target_environment: [value]
   - aks_cluster_name: [value]  
   - aks_resource_group: [value]
```

**Compare this with Step 1:**
- Do the values match between validate-environment and deploy jobs?
- If validate-environment shows values but deploy shows empty, there's a job dependency issue

### Step 5: Check Job Dependencies
In your workflow file, verify the deploy job has the correct dependencies:

```yaml
deploy:
  needs: [validate-environment, setup, sonar-scan, checkmarx-scan, build]
  # Must include validate-environment in the needs array
```

## Common Issues and Quick Fixes

### Issue 1: Secrets Not Set
**Symptoms:** validate-environment shows empty values
**Fix:** Add the missing secrets in repository settings

### Issue 2: Wrong Environment Detection  
**Symptoms:** validate-environment shows "unknown" environment
**Fix:** Check branch name matches expected patterns (develop/main/release/*)

### Issue 3: Job Dependency Missing
**Symptoms:** validate-environment shows values, deploy shows empty
**Fix:** Add `validate-environment` to deploy job's `needs` array

### Issue 4: Wrong Secret Names
**Symptoms:** Secrets exist but values are empty
**Fix:** Check secret names match exactly (case sensitive):
- `AKS_CLUSTER_NAME_DEV` (not `aks_cluster_name_dev`)
- `AKS_RESOURCE_GROUP_DEV` (not `aks_resource_group_dev`)

## Immediate Action Items

1. **Find your workflow logs** and check the validate-environment job output
2. **Report back the exact values** you see in the environment validation results
3. **Verify your repository secrets** are set with correct names
4. **Confirm which branch** you're running the workflow on

## Quick Test

Add this temporary debugging step to your workflow before the helm-deploy action:

```yaml
- name: Debug all outputs
  run: |
    echo "=== ALL JOB OUTPUTS ==="
    echo "validate-environment:"
    echo "  should_deploy: '${{ needs.validate-environment.outputs.should_deploy }}'"
    echo "  target_environment: '${{ needs.validate-environment.outputs.target_environment }}'"
    echo "  aks_cluster_name: '${{ needs.validate-environment.outputs.aks_cluster_name }}'"
    echo "  aks_resource_group: '${{ needs.validate-environment.outputs.aks_resource_group }}'"
    echo ""
    echo "=== CONTEXT INFO ==="
    echo "Branch: ${{ github.ref }}"
    echo "Event: ${{ github.event_name }}"
    echo "Repository: ${{ github.repository }}"
```

This will show you exactly what values are being passed between jobs.

## Next Steps

Please share:
1. The output from the validate-environment job
2. Which branch you're running on  
3. Whether the repository secrets are set
4. The debug output from the test step above

This will help identify exactly where the issue is occurring.