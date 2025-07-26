# GitHub Enterprise Configuration Guide

## Overview

This guide covers configuring GitHub Enterprise settings for deployment security, including teams/groups management, environment protection rules, and integration with the authorized users system.

## GitHub Enterprise Setup

### 1. Repository Environment Configuration

#### A. Create Protected Environments

**Navigate to**: Repository → Settings → Environments

Create the following environments with protection rules:

1. **PPR Environment**
   ```
   Environment Name: ppr
   Protection Rules:
   ✅ Required reviewers: 1-6 reviewers
   ✅ Restrict pushes to protected branches
   ✅ Allow only selected branches: release/**
   ```

2. **PROD Environment**
   ```
   Environment Name: prod
   Protection Rules:
   ✅ Required reviewers: 2-6 reviewers
   ✅ Restrict pushes to protected branches
   ✅ Allow only selected branches: tags only
   ✅ Wait timer: 10 minutes (optional)
   ```

#### B. Environment Protection Rules Configuration

**PPR Environment Settings:**
```yaml
Environment: ppr
Required Reviewers:
  - @your-org/release-team
  - @your-org/devops-team
Deployment Branches:
  - release/**
Environment Secrets:
  - PPR_DATABASE_URL
  - PPR_API_KEYS
```

**PROD Environment Settings:**
```yaml
Environment: prod
Required Reviewers:
  - @your-org/platform-team
  - @your-org/security-team
Deployment Branches:
  - Tags only
Wait Timer: 10 minutes
Environment Secrets:
  - PROD_DATABASE_URL
  - PROD_API_KEYS
  - PROD_ENCRYPTION_KEYS
```

### 2. GitHub Teams and Groups Management

#### A. Create Deployment Teams

**Navigate to**: Organization → Teams → New Team

**Create the following teams:**

1. **DevOps Team** (`devops-team`)
   ```
   Team Name: devops-team
   Description: DevOps engineers with deployment privileges
   Privacy: Visible
   Parent Team: engineering
   
   Members:
   - devops-lead
   - platform-engineer
   - infrastructure-manager
   
   Repository Permissions:
   - Maintain access to deployment repositories
   - Admin access to shared workflow repositories
   ```

2. **Release Team** (`release-team`)
   ```
   Team Name: release-team
   Description: Release managers and deployment approvers
   Privacy: Visible
   Parent Team: engineering
   
   Members:
   - release-manager
   - qa-director
   - product-owner
   
   Repository Permissions:
   - Write access to deployment repositories
   - Read access to shared workflow repositories
   ```

3. **Platform Team** (`platform-team`)
   ```
   Team Name: platform-team
   Description: Platform engineers and architects
   Privacy: Visible
   Parent Team: engineering
   
   Members:
   - platform-architect
   - site-reliability-lead
   - security-engineer
   
   Repository Permissions:
   - Admin access to all deployment repositories
   - Admin access to shared workflow repositories
   ```

4. **Emergency Response Team** (`emergency-team`)
   ```
   Team Name: emergency-team
   Description: On-call engineers for emergency deployments
   Privacy: Visible
   Parent Team: devops-team
   
   Members:
   - on-call-engineer
   - emergency-contact-1
   - emergency-contact-2
   
   Repository Permissions:
   - Maintain access to deployment repositories
   - Emergency deployment privileges
   ```

#### B. Team Hierarchy Structure

```
Organization
├── engineering
│   ├── devops-team
│   │   └── emergency-team
│   ├── release-team
│   ├── platform-team
│   └── security-team
└── management
    └── executive-team
```

### 3. GitHub Enterprise Integration

#### A. SAML/SSO Integration

**Configure SAML Groups Mapping:**

```yaml
SAML Group Mappings:
  "DevOps_Engineers": "devops-team"
  "Release_Managers": "release-team" 
  "Platform_Engineers": "platform-team"
  "Security_Team": "security-team"
  "Emergency_Response": "emergency-team"
```

**SAML Configuration Steps:**
1. Navigate to Organization → Settings → Security → SAML single sign-on
2. Enable SAML SSO
3. Configure IdP (Identity Provider) settings
4. Map SAML groups to GitHub teams
5. Test authentication flow

#### B. SCIM Provisioning

**Enable SCIM for automatic user management:**

```yaml
SCIM Configuration:
  Endpoint: https://api.github.com/scim/v2/organizations/{org}
  Token: {SCIM_TOKEN}
  Sync Groups: true
  Auto-provision: true
  
Group Mappings:
  - SCIM Group: "DevOps Engineers"
    GitHub Team: "devops-team"
  - SCIM Group: "Release Managers" 
    GitHub Team: "release-team"
  - SCIM Group: "Platform Engineers"
    GitHub Team: "platform-team"
```

### 4. Workflow Integration with Teams

#### A. Update Authorized Users with Teams

**In `.github/workflows/shared-deploy.yml`:**

```bash
# Option 1: Individual users (current approach)
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"

# Option 2: Team-based approach (enhanced)
AUTHORIZED_TEAMS="devops-team,release-team,platform-team"
AUTHORIZED_USERS="admin,emergency-contact-1,emergency-contact-2"

# Option 3: Mixed approach (recommended)
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
AUTHORIZED_TEAMS="devops-team,emergency-team"
```

#### B. Enhanced Authorization Function

**Add team-based validation to shared workflow:**

```bash
# Enhanced authorization function with team support
validate_protected_deployment() {
  local env="$1"
  local requires_emergency="$2"
  local user="$ACTOR"
  
  echo "🔒 Validating protected environment deployment: $env"
  
  # Check individual user authorization
  if is_authorized_user "$user"; then
    echo "✅ User '$user' individually authorized"
    return 0
  fi
  
  # Check team membership (requires GitHub API)
  if is_user_in_authorized_teams "$user"; then
    echo "✅ User '$user' authorized via team membership"
    return 0
  fi
  
  echo "❌ User '$user' not authorized for $env deployments"
  return 1
}

# Function to check team membership
is_user_in_authorized_teams() {
  local user="$1"
  local teams="devops-team,release-team,platform-team,emergency-team"
  
  # This would require GitHub API integration
  # For now, maintaining individual user list approach
  return 1
}
```

### 5. Branch Protection Rules

#### A. Configure Branch Protection

**Navigate to**: Repository → Settings → Branches

**Configure protection for key branches:**

**Dev Branch Protection:**
```yaml
Branch: dev
Protection Rules:
  ✅ Require a pull request before merging
  ✅ Require status checks to pass before merging
  ✅ Require conversation resolution before merging
  ❌ Restrict pushes that create files
  ❌ Require signed commits
```

**SQE Branch Protection:**
```yaml
Branch: sqe
Protection Rules:
  ✅ Require a pull request before merging
  ✅ Require status checks to pass before merging
  ✅ Require conversation resolution before merging
  ✅ Restrict pushes to specific people/teams:
    - @your-org/devops-team
    - @your-org/release-team
```

**Release Branch Protection:**
```yaml
Branch Pattern: release/**
Protection Rules:
  ✅ Require a pull request before merging
  ✅ Require status checks to pass before merging
  ✅ Require conversation resolution before merging
  ✅ Restrict pushes to specific people/teams:
    - @your-org/release-team
    - @your-org/platform-team
  ✅ Require signed commits
```

### 6. Repository Secrets Management

#### A. Organization-Level Secrets

**Navigate to**: Organization → Settings → Secrets and variables → Actions

**Configure organization secrets:**

```yaml
Organization Secrets:
  AZURE_CLIENT_ID: {azure_client_id}
  AZURE_TENANT_ID: {azure_tenant_id}
  AZURE_SUBSCRIPTION_ID: {azure_subscription_id}
  
  # Kubernetes Configuration
  AKS_CLUSTER_NAME_DEV: {dev_cluster}
  AKS_CLUSTER_NAME_SQE: {sqe_cluster}
  AKS_CLUSTER_NAME_PPR: {ppr_cluster}
  AKS_CLUSTER_NAME_PROD: {prod_cluster}
  
  # Resource Groups
  AKS_RESOURCE_GROUP_DEV: {dev_rg}
  AKS_RESOURCE_GROUP_SQE: {sqe_rg}
  AKS_RESOURCE_GROUP_PPR: {ppr_rg}
  AKS_RESOURCE_GROUP_PROD: {prod_rg}
```

#### B. Environment-Specific Secrets

**PPR Environment Secrets:**
```yaml
PPR_DATABASE_PASSWORD: {encrypted_value}
PPR_JWT_SECRET: {encrypted_value}
PPR_API_KEY: {encrypted_value}
PPR_REDIS_PASSWORD: {encrypted_value}
```

**PROD Environment Secrets:**
```yaml
PROD_DATABASE_PASSWORD: {encrypted_value}
PROD_JWT_SECRET: {encrypted_value}
PROD_API_KEY: {encrypted_value}
PROD_REDIS_PASSWORD: {encrypted_value}
PROD_ENCRYPTION_KEY: {encrypted_value}
```

### 7. GitHub Enterprise Policies

#### A. Organization Security Policies

**Configure organization-wide policies:**

```yaml
Security Policies:
  Two-Factor Authentication:
    Required: true
    Grace Period: 7 days
    
  SAML Single Sign-On:
    Required: true
    IdP: {your_identity_provider}
    
  IP Allow Lists:
    Enabled: true
    Allowed IPs:
      - 203.0.113.0/24  # Office network
      - 198.51.100.0/24 # VPN network
      
  Third-party Application Access:
    Policy: restricted
    Pre-approved Apps:
      - GitHub Actions
      - Azure DevOps (if needed)
```

#### B. Repository Policies

**Configure repository-level policies:**

```yaml
Repository Policies:
  Default Branch Protection:
    Enabled: true
    Minimum Reviewers: 1
    
  Force Push:
    Allowed: false
    
  Deletion Protection:
    Enabled: true
    
  Vulnerability Alerts:
    Enabled: true
    Security Updates: true
```

### 8. Audit and Compliance

#### A. Audit Log Configuration

**Enable comprehensive audit logging:**

```yaml
Audit Settings:
  Events to Log:
    - Repository access
    - Team membership changes
    - Environment deployments
    - Secret access
    - Branch protection changes
    
  Log Retention: 90 days
  Export Format: JSON
  SIEM Integration: enabled
```

#### B. Compliance Reporting

**Generate regular compliance reports:**

```yaml
Compliance Reports:
  Frequency: Monthly
  Include:
    - User access reviews
    - Deployment activities
    - Security policy compliance
    - Team membership changes
    
  Distribution:
    - Security team
    - Compliance officer
    - Platform engineering lead
```

### 9. GitHub Enterprise API Integration

#### A. API Token Management

**Create service account tokens for automation:**

```yaml
Service Accounts:
  deployment-automation:
    Permissions:
      - repo:write
      - admin:org (for team membership checks)
    Scopes:
      - read:org
      - read:user
      - repo
    Token Rotation: 90 days
    
  security-scanner:
    Permissions:
      - repo:read
      - security_events:read
    Scopes:
      - repo
      - security_events
    Token Rotation: 30 days
```

#### B. Team Membership Validation API

**Example API integration for team validation:**

```bash
# Check if user is member of authorized teams
check_team_membership() {
  local user="$1"
  local org="your-org"
  local teams=("devops-team" "release-team" "platform-team")
  
  for team in "${teams[@]}"; do
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/orgs/$org/teams/$team/memberships/$user")
    
    if echo "$response" | jq -e '.state == "active"' > /dev/null; then
      echo "✅ User $user is member of $team"
      return 0
    fi
  done
  
  return 1
}
```

### 10. Best Practices for GitHub Enterprise

#### A. Security Best Practices

1. **Identity Management**
   - Use SAML/SSO for centralized authentication
   - Enable SCIM for automated user provisioning
   - Implement just-in-time access for temporary permissions

2. **Access Control**
   - Follow principle of least privilege
   - Use teams instead of individual permissions where possible
   - Regular access reviews and cleanup

3. **Monitoring and Alerting**
   - Set up alerts for suspicious activities
   - Monitor deployment patterns and anomalies
   - Track emergency deployment usage

#### B. Operational Best Practices

1. **Team Management**
   - Consistent naming conventions for teams
   - Clear team descriptions and purposes
   - Regular team membership audits

2. **Environment Management**
   - Progressive deployment through environments
   - Environment-specific protection rules
   - Automated secret rotation

3. **Documentation**
   - Maintain up-to-date team documentation
   - Document emergency procedures
   - Keep configuration documentation current

### 11. Migration from Individual Users to Teams

#### A. Migration Strategy

**Phase 1: Parallel Configuration**
```bash
# Keep existing individual users while adding team support
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
AUTHORIZED_TEAMS="devops-team,release-team,platform-team"
```

**Phase 2: Gradual Team Adoption**
```bash
# Move specific roles to teams
AUTHORIZED_USERS="admin,emergency-contact-1"
AUTHORIZED_TEAMS="devops-team,release-team,platform-team,emergency-team"
```

**Phase 3: Full Team Integration**
```bash
# Primary authorization through teams
AUTHORIZED_TEAMS="devops-team,release-team,platform-team"
EMERGENCY_USERS="admin,emergency-contact-1"
```

#### B. Testing Team Integration

**Test team-based authorization:**

```bash
# Test team member deployment
gh workflow run deploy.yml \
  -f environment=ppr \
  -f override_branch_validation=true \
  -f deploy_notes="Testing team-based authorization"

# Verify team membership via API
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/orgs/your-org/teams/devops-team/members"
```

### 12. Troubleshooting GitHub Enterprise Integration

#### Common Issues and Solutions

**Issue: SAML authentication failures**
```
Solution:
1. Verify IdP configuration
2. Check group mappings
3. Test with individual user
4. Review audit logs
```

**Issue: Team membership not syncing**
```
Solution:
1. Verify SCIM configuration
2. Check group mappings
3. Manual sync if needed
4. Contact GitHub Enterprise support
```

**Issue: Environment protection not working**
```
Solution:
1. Verify environment configuration
2. Check branch protection rules
3. Validate team permissions
4. Test with different user
```

This comprehensive guide covers all aspects of GitHub Enterprise configuration for deployment security, including teams, groups, environment protection, and integration with the existing authorized users system.