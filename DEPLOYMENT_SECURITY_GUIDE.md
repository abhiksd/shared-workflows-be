# Deployment Security Guide

This guide explains the multi-layered security approach for protecting production deployments while maintaining development flexibility.

## Overview

The deployment system implements three levels of protection:
- **Standard Protection**: DEV and SQE environments (minimal restrictions)
- **Enhanced Protection**: PPR environment (authorized users only for overrides)
- **Maximum Protection**: PROD environment (authorized users + emergency flag for overrides)

## Authorized Users Configuration

### Where to Configure

The authorized users list is configured in the shared workflow file:
**File**: `.github/workflows/shared-deploy.yml` (in `no-keyvault-shared-github-actions` branch)

**Location**: Line ~75 in the `validate-environment` job, within the shell script section:

```yaml
- name: Validate deployment environment and set cluster details
  shell: bash
  run: |
    # ... other code ...
    
    # Authorized users list (configurable)
    AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
    
    # ... rest of the script ...
```

### How to Modify Authorized Users

#### 1. Edit the Shared Workflow

To add or remove authorized users, modify the `AUTHORIZED_USERS` variable:

```bash
# Current configuration
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"

# Example: Add new users
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer,senior-dev,qa-lead"

# Example: Remove a user
AUTHORIZED_USERS="admin,devops-lead,release-manager"

# Example: Single administrator
AUTHORIZED_USERS="admin"
```

#### 2. User Identification Format

Users are identified by their **GitHub username** (not display name or email).

**Examples:**
```bash
# Correct: GitHub usernames
AUTHORIZED_USERS="john.doe,jane.smith,mike.wilson"

# Incorrect: Email addresses
AUTHORIZED_USERS="john@company.com,jane@company.com"  # ❌ Won't work

# Incorrect: Display names
AUTHORIZED_USERS="John Doe,Jane Smith"  # ❌ Won't work
```

#### 3. Configuration Examples

**Small Team Configuration:**
```bash
AUTHORIZED_USERS="tech-lead,devops-admin"
```

**Medium Team Configuration:**
```bash
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer,senior-dev-1,senior-dev-2"
```

**Enterprise Configuration:**
```bash
AUTHORIZED_USERS="platform-admin,devops-manager,release-director,infrastructure-lead,security-engineer,production-operator"
```

**Emergency-Only Configuration:**
```bash
AUTHORIZED_USERS="emergency-admin"
```

### Best Practices for User Management

#### 1. Role-Based Authorization

Organize users by responsibility:

```bash
# Production Operations Team
AUTHORIZED_USERS="prod-ops-lead,infrastructure-manager,platform-engineer,devops-senior"

# Release Management Team  
AUTHORIZED_USERS="release-manager,deployment-lead,qa-director,product-owner"

# Emergency Response Team
AUTHORIZED_USERS="on-call-engineer,site-reliability-lead,platform-architect"
```

#### 2. Principle of Least Privilege

- **Minimum Required**: Only include users who regularly need to perform protected deployments
- **Regular Review**: Audit the list quarterly to remove inactive users
- **Emergency Access**: Maintain at least 2-3 authorized users for emergency scenarios

#### 3. User Lifecycle Management

**Adding New Users:**
1. Verify GitHub username spelling
2. Test with a non-production override first
3. Document the addition in team records

**Removing Users:**
1. Remove from `AUTHORIZED_USERS` list
2. Verify removal with a test deployment
3. Update team documentation

#### 4. Security Considerations

**GitHub Username Verification:**
```bash
# To verify a GitHub username exists:
curl -s https://api.github.com/users/USERNAME

# Example response for valid user:
{
  "login": "octocat",
  "id": 1,
  "type": "User"
}
```

**Case Sensitivity:**
- GitHub usernames are case-insensitive
- Configuration is case-sensitive in the workflow
- Use exact casing from GitHub profile

### Configuration Testing

#### 1. Test Authorized User Access

**Scenario**: Test PPR manual override
```bash
# Manual deployment as authorized user
gh workflow run deploy.yml \
  --ref any-branch \
  -f environment=ppr \
  -f override_branch_validation=true \
  -f deploy_notes="Testing authorized access"
```

**Expected Result**: ✅ Deployment proceeds with authorization message

#### 2. Test Unauthorized User Access

**Scenario**: Non-authorized user attempts PPR override
```bash
# Manual deployment as non-authorized user
gh workflow run deploy.yml \
  --ref any-branch \
  -f environment=ppr \
  -f override_branch_validation=true
```

**Expected Result**: ❌ Deployment blocked with authorization error

#### 3. Test PROD Emergency Access

**Scenario**: Test emergency PROD deployment
```bash
# Emergency PROD deployment
gh workflow run deploy.yml \
  --ref any-branch \
  -f environment=prod \
  -f override_branch_validation=true \
  -f emergency_deployment=true \
  -f deploy_notes="Critical security patch deployment"
```

**Expected Result**: ✅ Deployment proceeds with emergency warning logs

### Common Configuration Errors

#### 1. Syntax Errors

**Incorrect Formatting:**
```bash
# ❌ Spaces around commas
AUTHORIZED_USERS="admin, devops-lead, release-manager"

# ❌ Extra quotes
AUTHORIZED_USERS="'admin','devops-lead','release-manager'"

# ❌ Missing quotes
AUTHORIZED_USERS=admin,devops-lead,release-manager

# ✅ Correct format
AUTHORIZED_USERS="admin,devops-lead,release-manager"
```

#### 2. Username Errors

**Common Mistakes:**
```bash
# ❌ Using email instead of username
AUTHORIZED_USERS="john@company.com"

# ❌ Using display name
AUTHORIZED_USERS="John Doe"

# ❌ Incorrect casing (if user is actually 'JohnDoe')
AUTHORIZED_USERS="johndoe"

# ✅ Correct GitHub username
AUTHORIZED_USERS="JohnDoe"
```

### Audit and Monitoring

#### 1. Deployment Logs

All authorization attempts are logged:

```
✅ User 'admin' authorized for PPR manual override
❌ User 'unauthorized-dev' blocked from PPR manual override
🚨 EMERGENCY DEPLOYMENT: User=admin, Notes='Critical patch'
```

#### 2. Regular Audits

**Monthly Review Checklist:**
- [ ] Review authorized users list
- [ ] Verify all users are still active team members
- [ ] Check for any unauthorized deployment attempts
- [ ] Update user list based on team changes

#### 3. Security Monitoring

**Key Metrics to Track:**
- Number of manual overrides per month
- Emergency deployments frequency
- Blocked deployment attempts
- User authorization failures

### Advanced Configuration Options

#### 1. Environment-Specific Authorization

For more granular control, you could extend the configuration:

```bash
# Future enhancement: Environment-specific users
PPR_AUTHORIZED_USERS="devops-lead,release-manager"
PROD_AUTHORIZED_USERS="admin,platform-engineer"
```

#### 2. Time-Based Restrictions

```bash
# Future enhancement: Time-based access
BUSINESS_HOURS_ONLY="true"
WEEKEND_DEPLOYMENTS="emergency-only"
```

#### 3. Integration with External Systems

```bash
# Future enhancement: External authorization
AUTH_SYSTEM="okta"
AUTH_GROUP="production-deployers"
```

## Protection Levels

### Standard Protection (DEV, SQE)
- **Auto-deployment**: Based on branch triggers
- **Manual Override**: No restrictions
- **User Requirements**: Any team member
- **Audit Level**: Basic logging

### Enhanced Protection (PPR)
- **Auto-deployment**: `release/**` branches only
- **Manual Override**: Authorized users only
- **User Requirements**: Must be in `AUTHORIZED_USERS` list
- **Audit Level**: Enhanced logging with user identification

### Maximum Protection (PROD)
- **Auto-deployment**: Tagged releases only
- **Manual Override**: Authorized users + emergency flag
- **User Requirements**: Must be in `AUTHORIZED_USERS` list AND set `emergency_deployment=true`
- **Audit Level**: Maximum logging with emergency alerts

## Emergency Deployment Procedures

### When to Use Emergency Deployment

**Valid Emergency Scenarios:**
- Critical security vulnerabilities
- Production outages requiring immediate fixes
- Data corruption issues
- Compliance-related urgent updates

**Process:**
1. Assess if it's truly an emergency
2. Ensure you're an authorized user
3. Prepare detailed deployment notes
4. Set `emergency_deployment=true`
5. Monitor deployment closely
6. Document post-deployment actions

### Emergency Deployment Example

```yaml
# Manual workflow dispatch for emergency PROD deployment
environment: prod
override_branch_validation: true
emergency_deployment: true
custom_image_tag: "hotfix-security-patch-v1.2.3"
deploy_notes: "EMERGENCY: Critical security patch for CVE-2024-XXXX. Approved by security team. Rollback plan: revert to v1.2.2 tag."
```

## Best Practices

### 1. Access Management
- Limit authorized users to essential personnel only
- Regular review and cleanup of user list
- Document reasons for each authorized user

### 2. Emergency Procedures
- Clear escalation path for emergencies
- Pre-approved emergency contact list
- Post-deployment review process

### 3. Audit and Compliance
- Monitor all deployment activities
- Maintain deployment logs for compliance
- Regular security reviews of access patterns

### 4. Documentation
- Keep authorization list updated
- Document emergency procedures
- Train team on security protocols

## Troubleshooting

### Common Issues

**"User not authorized" Error:**
1. Verify GitHub username spelling
2. Check if user is in `AUTHORIZED_USERS` list
3. Ensure correct casing of username

**Emergency Deployment Blocked:**
1. Verify user is authorized
2. Ensure `emergency_deployment=true` is set
3. Check if deployment notes are provided

**Configuration Not Taking Effect:**
1. Verify changes are committed to correct branch
2. Check workflow file syntax
3. Ensure latest shared workflow version is being used

For additional support, consult the team's deployment documentation or contact the platform engineering team.