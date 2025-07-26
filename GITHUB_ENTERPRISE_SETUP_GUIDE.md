# GitHub Enterprise Setup Guide - Step by Step

## 🎯 Quick Setup Checklist

### Phase 1: Organization Setup
- [ ] Create GitHub teams for deployment roles
- [ ] Configure SAML/SSO integration (if applicable)
- [ ] Set up organization-level security policies
- [ ] Configure organization secrets

### Phase 2: Repository Configuration
- [ ] Create protected environments (PPR, PROD)
- [ ] Configure branch protection rules
- [ ] Set up environment-specific secrets
- [ ] Configure team permissions

### Phase 3: Workflow Integration
- [ ] Update authorized users configuration
- [ ] Test team-based authorization
- [ ] Implement team API validation (optional)
- [ ] Document team procedures

## 📋 Step-by-Step Instructions

### Step 1: Create GitHub Teams

#### 1.1 Navigate to Organization Teams
```
GitHub.com → Your Organization → Teams → New Team
```

#### 1.2 Create DevOps Team
```yaml
Team Configuration:
  Name: devops-team
  Description: "DevOps engineers with deployment privileges"
  Privacy: Visible to organization members
  Parent Team: engineering (if exists)
```

**Add Members:**
1. Click "Members" tab
2. Click "Add a member"
3. Search and add users:
   - `devops-lead`
   - `platform-engineer`
   - `infrastructure-manager`

**Set Repository Permissions:**
1. Click "Repositories" tab
2. Add repository with "Maintain" permissions
3. For shared workflow repo: "Admin" permissions

#### 1.3 Create Release Team
```yaml
Team Configuration:
  Name: release-team
  Description: "Release managers and deployment approvers"
  Privacy: Visible to organization members
  Parent Team: engineering
```

**Add Members:**
- `release-manager`
- `qa-director`
- `product-owner`

#### 1.4 Create Platform Team
```yaml
Team Configuration:
  Name: platform-team
  Description: "Platform engineers and architects"
  Privacy: Visible to organization members
  Parent Team: engineering
```

**Add Members:**
- `platform-architect`
- `site-reliability-lead`
- `security-engineer`

#### 1.5 Create Emergency Team
```yaml
Team Configuration:
  Name: emergency-team
  Description: "On-call engineers for emergency deployments"
  Privacy: Visible to organization members
  Parent Team: devops-team
```

**Add Members:**
- `on-call-engineer`
- `emergency-contact-1`
- `emergency-contact-2`

### Step 2: Configure Repository Environments

#### 2.1 Navigate to Repository Settings
```
Repository → Settings → Environments
```

#### 2.2 Create PPR Environment
1. Click "New environment"
2. Name: `ppr`
3. Configure protection rules:

**Protection Rules for PPR:**
```yaml
✅ Required reviewers: 1
   Select reviewers:
   - @your-org/release-team
   - @your-org/devops-team

✅ Wait timer: 0 minutes (optional)

✅ Deployment branches: Selected branches
   Add branch pattern: release/**

❌ Prevent self-review
❌ Required conversation resolution
```

#### 2.3 Create PROD Environment
1. Click "New environment"
2. Name: `prod`
3. Configure protection rules:

**Protection Rules for PROD:**
```yaml
✅ Required reviewers: 2
   Select reviewers:
   - @your-org/platform-team
   - @your-org/security-team

✅ Wait timer: 10 minutes

✅ Deployment branches: Selected branches
   Add branch pattern: No branch restrictions (tags only)
   Note: GitHub doesn't support "tags only" in UI, this is handled by workflow logic

✅ Prevent self-review
✅ Required conversation resolution
```

### Step 3: Configure Branch Protection

#### 3.1 Navigate to Branch Settings
```
Repository → Settings → Branches
```

#### 3.2 Protect Dev Branch
1. Click "Add rule"
2. Branch name pattern: `dev`
3. Configure rules:

```yaml
✅ Require a pull request before merging
   - Required approving reviews: 1
   - Dismiss stale reviews when new commits are pushed
   - Require review from code owners (if CODEOWNERS exists)

✅ Require status checks to pass before merging
   - Require branches to be up to date before merging
   - Status checks: (will populate after first workflow run)

✅ Require conversation resolution before merging

❌ Require signed commits
❌ Require linear history
❌ Include administrators
```

#### 3.3 Protect SQE Branch
1. Click "Add rule"
2. Branch name pattern: `sqe`
3. Configure rules (same as dev, plus):

```yaml
✅ Restrict pushes that create files
   Who can push to matching branches:
   - @your-org/devops-team
   - @your-org/release-team
```

#### 3.4 Protect Release Branches
1. Click "Add rule"
2. Branch name pattern: `release/**`
3. Configure rules:

```yaml
✅ Require a pull request before merging
   - Required approving reviews: 2
   - Dismiss stale reviews when new commits are pushed
   - Require review from code owners

✅ Require status checks to pass before merging
✅ Require conversation resolution before merging
✅ Require signed commits

✅ Restrict pushes that create files
   Who can push to matching branches:
   - @your-org/release-team
   - @your-org/platform-team

✅ Include administrators
```

### Step 4: Configure Organization Secrets

#### 4.1 Navigate to Organization Secrets
```
Organization → Settings → Secrets and variables → Actions
```

#### 4.2 Add Azure Secrets
Click "New organization secret" for each:

```yaml
AZURE_CLIENT_ID: <your-azure-client-id>
AZURE_TENANT_ID: <your-azure-tenant-id>
AZURE_SUBSCRIPTION_ID: <your-azure-subscription-id>
```

#### 4.3 Add Kubernetes Cluster Secrets
```yaml
AKS_CLUSTER_NAME_DEV: <dev-cluster-name>
AKS_CLUSTER_NAME_SQE: <sqe-cluster-name>
AKS_CLUSTER_NAME_PPR: <ppr-cluster-name>
AKS_CLUSTER_NAME_PROD: <prod-cluster-name>

AKS_RESOURCE_GROUP_DEV: <dev-resource-group>
AKS_RESOURCE_GROUP_SQE: <sqe-resource-group>
AKS_RESOURCE_GROUP_PPR: <ppr-resource-group>
AKS_RESOURCE_GROUP_PROD: <prod-resource-group>
```

#### 4.4 Set Repository Access
For each secret, configure repository access:
- Select "Selected repositories"
- Add your application repositories
- Add shared workflow repository

### Step 5: Configure Environment Secrets

#### 5.1 Navigate to Environment Settings
```
Repository → Settings → Environments → [Environment Name]
```

#### 5.2 Add PPR Environment Secrets
Click "Add secret" for each:

```yaml
PPR_DATABASE_PASSWORD: <encrypted-ppr-db-password>
PPR_JWT_SECRET: <encrypted-ppr-jwt-secret>
PPR_API_KEY: <encrypted-ppr-api-key>
PPR_REDIS_PASSWORD: <encrypted-ppr-redis-password>
```

#### 5.3 Add PROD Environment Secrets
```yaml
PROD_DATABASE_PASSWORD: <encrypted-prod-db-password>
PROD_JWT_SECRET: <encrypted-prod-jwt-secret>
PROD_API_KEY: <encrypted-prod-api-key>
PROD_REDIS_PASSWORD: <encrypted-prod-redis-password>
PROD_ENCRYPTION_KEY: <encrypted-prod-encryption-key>
```

### Step 6: Update Workflow Configuration

#### 6.1 Update Authorized Users List
In `no-keyvault-shared-github-actions` branch, edit `.github/workflows/shared-deploy.yml`:

```bash
# Current individual user approach
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"

# Future team-based approach (requires API integration)
# AUTHORIZED_TEAMS="devops-team,release-team,platform-team"
```

#### 6.2 Team Integration (Future Enhancement)
For team-based authorization, add to the workflow:

```bash
# Function to check team membership via GitHub API
is_user_in_authorized_teams() {
  local user="$1"
  local org="your-org-name"
  local teams=("devops-team" "release-team" "platform-team" "emergency-team")
  
  for team in "${teams[@]}"; do
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/orgs/$org/teams/$team/memberships/$user")
    
    if echo "$response" | jq -e '.state == "active"' > /dev/null 2>&1; then
      echo "✅ User $user is member of $team"
      return 0
    fi
  done
  
  return 1
}
```

### Step 7: Testing Configuration

#### 7.1 Test Team Permissions
1. Have team member attempt PPR deployment:
```bash
gh workflow run deploy.yml \
  -f environment=ppr \
  -f override_branch_validation=true \
  -f deploy_notes="Testing team authorization"
```

2. Verify deployment is authorized correctly

#### 7.2 Test Environment Protection
1. Attempt to trigger PPR deployment manually
2. Verify required reviewers are requested
3. Test approval process

#### 7.3 Test Branch Protection
1. Create test PR to protected branch
2. Verify status checks are required
3. Test merge protection rules

### Step 8: Configure SAML/SSO (Enterprise Only)

#### 8.1 Navigate to SAML Settings
```
Organization → Settings → Security → SAML single sign-on
```

#### 8.2 Configure Identity Provider
1. Enable SAML SSO
2. Add IdP metadata or configuration
3. Map SAML groups to GitHub teams:

```yaml
SAML Group Mappings:
  "DevOps_Engineers" → devops-team
  "Release_Managers" → release-team
  "Platform_Engineers" → platform-team
  "Security_Team" → security-team
  "Emergency_Response" → emergency-team
```

#### 8.3 Test SSO Integration
1. Test user login via SSO
2. Verify team membership is correctly assigned
3. Confirm repository access permissions

### Step 9: Set Up Monitoring and Auditing

#### 9.1 Enable Audit Logging
```
Organization → Settings → Audit log
```

Configure audit log settings:
- Log retention: 90 days minimum
- Export format: JSON
- Enable real-time alerts for security events

#### 9.2 Monitor Key Events
Set up alerts for:
- Team membership changes
- Environment deployment approvals
- Emergency deployment usage
- Failed authorization attempts

## 🔧 Troubleshooting Common Issues

### Issue: Team member can't deploy to PPR
**Diagnosis:**
1. Check if user is in authorized teams
2. Verify team has repository permissions
3. Confirm environment protection settings

**Solution:**
```bash
# Check team membership
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/orgs/your-org/teams/devops-team/members"

# Add user to team if missing
# GitHub UI: Organization → Teams → [team] → Members → Add member
```

### Issue: Environment protection not triggering
**Diagnosis:**
1. Verify environment exists and is configured
2. Check deployment branch patterns
3. Confirm reviewer requirements

**Solution:**
1. Re-check environment configuration
2. Update deployment branch patterns if needed
3. Test with different branch/tag

### Issue: SAML group mapping not working
**Diagnosis:**
1. Verify SAML configuration
2. Check group name mapping
3. Test individual user login

**Solution:**
1. Update SAML group mappings
2. Sync user manually if needed
3. Contact GitHub Enterprise support

## 📊 Configuration Validation Checklist

### Organization Level
- [ ] Teams created with proper hierarchy
- [ ] Organization secrets configured
- [ ] SAML/SSO integration working (if applicable)
- [ ] Security policies enabled

### Repository Level
- [ ] Environments created (PPR, PROD)
- [ ] Environment protection rules configured
- [ ] Branch protection rules active
- [ ] Environment secrets added

### Workflow Level
- [ ] Authorized users list updated
- [ ] Team integration planned/implemented
- [ ] Testing completed successfully
- [ ] Documentation updated

### Testing Verification
- [ ] Team member can deploy to allowed environments
- [ ] Non-team member blocked from protected environments
- [ ] Environment protection triggers correctly
- [ ] Branch protection enforced
- [ ] Emergency deployment process tested

## 🎯 Next Steps

1. **Immediate**: Complete basic setup with individual users
2. **Short-term**: Implement team-based authorization via API
3. **Long-term**: Full SAML/SSO integration with automated provisioning
4. **Ongoing**: Regular audit and review of team memberships and permissions

This completes the comprehensive GitHub Enterprise setup for deployment security!