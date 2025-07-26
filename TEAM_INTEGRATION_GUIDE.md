# Team-Based Authorization Integration Guide

## Overview

This guide explains how to integrate GitHub teams with the deployment authorization system, providing a scalable alternative to individual user management.

## Current Implementation

The system currently uses individual user authorization:

```bash
# In .github/workflows/shared-deploy.yml
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
```

## Team-Based Authorization Benefits

### Advantages
- **Scalable Management**: Add/remove users via team membership
- **SAML Integration**: Automatic team assignment via identity provider
- **Centralized Control**: Manage permissions at organization level
- **Audit Trail**: GitHub provides team membership change logs
- **Role-Based Access**: Align permissions with organizational structure

### Use Cases
- **Large Organizations**: 50+ developers with role-based access
- **SAML/SSO Integration**: Automated user provisioning
- **Compliance Requirements**: Centralized access management
- **Dynamic Teams**: Frequent team membership changes

## Implementation Options

### Option 1: Individual Users Only (Current)
```bash
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
```
**Best for**: Small teams (< 10 users), simple setups

### Option 2: Teams Only
```bash
AUTHORIZED_TEAMS="devops-team,release-team,platform-team"
```
**Best for**: Large organizations, full SAML integration

### Option 3: Mixed Approach (Recommended)
```bash
AUTHORIZED_USERS="admin,emergency-contact-1"
AUTHORIZED_TEAMS="devops-team,release-team,platform-team"
```
**Best for**: Most organizations, provides flexibility

## GitHub Teams Setup

### Required Teams

1. **devops-team**
   - DevOps engineers and infrastructure specialists
   - PPR and PROD deployment authorization
   - Repository: Maintain permissions

2. **release-team**
   - Release managers and QA leads
   - PPR deployment authorization
   - Repository: Write permissions

3. **platform-team**
   - Platform engineers and architects
   - PPR and PROD deployment authorization
   - Repository: Admin permissions

4. **emergency-team**
   - On-call engineers for emergency deployments
   - PROD emergency deployment authorization
   - Repository: Maintain permissions

### Team Creation Process

```bash
# GitHub UI Navigation
Organization → Teams → New Team

# Example: DevOps Team
Name: devops-team
Description: DevOps engineers with deployment privileges
Privacy: Visible to organization members
Parent Team: engineering
```

## Technical Implementation

### Step 1: Update Workflow Variables

In `.github/workflows/shared-deploy.yml`, add team configuration:

```bash
# Individual users (keep for emergency access)
AUTHORIZED_USERS="admin,emergency-contact-1,emergency-contact-2"

# Team-based authorization
AUTHORIZED_TEAMS="devops-team,release-team,platform-team,emergency-team"

# Organization configuration
ORG_NAME="your-github-org"
```

### Step 2: Implement Team Validation Function

```bash
# Function to check team membership via GitHub API
is_user_in_authorized_teams() {
  local user="$1"
  local teams=("devops-team" "release-team" "platform-team" "emergency-team")
  
  for team in "${teams[@]}"; do
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/orgs/$ORG_NAME/teams/$team/memberships/$user")
    
    if echo "$response" | jq -e '.state == "active"' > /dev/null 2>&1; then
      echo "✅ User $user is member of $team"
      return 0
    fi
  done
  
  return 1
}
```

### Step 3: Update Authorization Logic

```bash
# Enhanced authorization check
validate_protected_deployment() {
  local env="$1"
  local requires_emergency="$2"
  local user="$ACTOR"
  
  echo "🔒 Validating protected environment deployment: $env"
  
  # Check individual user authorization first
  if is_authorized_user "$user"; then
    echo "✅ User '$user' individually authorized"
    return 0
  fi
  
  # Check team membership
  if is_user_in_authorized_teams "$user"; then
    echo "✅ User '$user' authorized via team membership"
    return 0
  fi
  
  echo "❌ User '$user' not authorized for $env deployments"
  echo "   Authorized users: $AUTHORIZED_USERS"
  echo "   Authorized teams: $AUTHORIZED_TEAMS"
  return 1
}
```

### Step 4: Configure GitHub Token

The team validation requires a GitHub token with appropriate permissions:

```bash
# Required GitHub token scopes
GITHUB_TOKEN_SCOPES:
  - read:org        # Read organization data
  - read:user       # Read user data
  - repo            # Repository access (if private)

# Token configuration
# 1. Create Personal Access Token or GitHub App
# 2. Add as organization secret: TEAM_VALIDATION_TOKEN
# 3. Grant read:org and read:user scopes
```

## Migration Strategy

### Phase 1: Parallel Implementation (Recommended)

Keep existing individual users while adding team support:

```bash
# Phase 1: Both individual and team authorization
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
AUTHORIZED_TEAMS="devops-team,release-team,platform-team"

# Authorization logic checks both
if is_authorized_user "$user" || is_user_in_authorized_teams "$user"; then
  echo "✅ User authorized"
fi
```

### Phase 2: Gradual Team Adoption

Move specific roles to teams while keeping emergency users:

```bash
# Phase 2: Primary team-based with emergency individual users
AUTHORIZED_USERS="admin,emergency-contact-1"
AUTHORIZED_TEAMS="devops-team,release-team,platform-team,emergency-team"
```

### Phase 3: Full Team Integration

Complete migration to team-based authorization:

```bash
# Phase 3: Team-based with minimal individual exceptions
AUTHORIZED_USERS="admin"  # Super admin only
AUTHORIZED_TEAMS="devops-team,release-team,platform-team,emergency-team"
```

## Configuration Examples

### Small Organization (< 20 developers)
```bash
# Simple team structure
AUTHORIZED_USERS="admin,devops-lead"
AUTHORIZED_TEAMS="engineering-team"
```

### Medium Organization (20-100 developers)
```bash
# Role-based teams
AUTHORIZED_USERS="admin,emergency-contact"
AUTHORIZED_TEAMS="devops-team,release-team,platform-team"
```

### Large Enterprise (100+ developers)
```bash
# Comprehensive team structure
AUTHORIZED_USERS="platform-admin"
AUTHORIZED_TEAMS="devops-team,release-team,platform-team,security-team,emergency-team"
```

## Environment-Specific Team Authorization

### Future Enhancement: Environment-Specific Teams

```bash
# Environment-specific team authorization
case "$env" in
  "ppr")
    AUTHORIZED_TEAMS="devops-team,release-team,platform-team"
    ;;
  "prod")
    AUTHORIZED_TEAMS="platform-team,security-team"
    if [[ "$requires_emergency" == "true" ]]; then
      AUTHORIZED_TEAMS="$AUTHORIZED_TEAMS,emergency-team"
    fi
    ;;
esac
```

## Testing Team Integration

### Test Team Membership API

```bash
# Test GitHub API team membership check
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/orgs/your-org/teams/devops-team/memberships/username"

# Expected response for active member:
{
  "url": "https://api.github.com/teams/123456/memberships/username",
  "role": "member",
  "state": "active"
}
```

### Test Deployment Authorization

```bash
# Test team member deployment
gh workflow run deploy.yml \
  -f environment=ppr \
  -f override_branch_validation=true \
  -f deploy_notes="Testing team-based authorization"

# Expected log output:
"✅ User 'team-member' authorized via team membership for PPR deployment"
```

## Security Considerations

### Token Security
- Use GitHub App instead of Personal Access Token when possible
- Rotate tokens regularly (90 days maximum)
- Limit token scope to minimum required (read:org, read:user)
- Store token as encrypted organization secret

### Team Management Security
- Regular team membership audits
- Monitor team changes via audit logs
- Use SAML group mapping for automated membership
- Implement just-in-time access for temporary permissions

### API Rate Limits
- GitHub API has rate limits (5000 requests/hour for authenticated requests)
- Cache team membership results if needed
- Consider GraphQL API for better efficiency

## Troubleshooting

### Common Issues

**Issue**: API returns 404 for team membership
```bash
# Solutions:
1. Verify team name spelling
2. Check if user has public membership
3. Ensure token has read:org scope
4. Confirm organization name is correct
```

**Issue**: Team member not authorized
```bash
# Diagnosis:
1. Check team membership in GitHub UI
2. Verify user has "active" membership state
3. Test API call manually
4. Check workflow logs for API response
```

**Issue**: API rate limit exceeded
```bash
# Solutions:
1. Implement caching for team membership
2. Use GraphQL API for efficiency
3. Consider GitHub App instead of PAT
4. Reduce frequency of API calls
```

## Best Practices

### Team Management
1. **Consistent Naming**: Use clear, consistent team naming conventions
2. **Team Hierarchy**: Organize teams in logical hierarchy
3. **Regular Audits**: Monthly review of team memberships
4. **Documentation**: Maintain team purpose and responsibility documentation

### API Integration
1. **Error Handling**: Implement robust error handling for API calls
2. **Fallback**: Always have fallback to individual user authorization
3. **Monitoring**: Monitor API usage and rate limits
4. **Caching**: Cache results to reduce API calls

### Security
1. **Principle of Least Privilege**: Minimal required permissions
2. **Token Rotation**: Regular token rotation
3. **Audit Logging**: Monitor all authorization decisions
4. **SAML Integration**: Use identity provider for team management

## Implementation Checklist

### Prerequisites
- [ ] GitHub teams created with appropriate members
- [ ] GitHub token with read:org scope configured
- [ ] Team naming conventions established
- [ ] Repository permissions configured for teams

### Implementation Steps
- [ ] Update workflow variables with team configuration
- [ ] Implement team validation function
- [ ] Update authorization logic to check teams
- [ ] Test team-based authorization
- [ ] Monitor and validate functionality

### Post-Implementation
- [ ] Document team procedures
- [ ] Train team on new authorization process
- [ ] Set up monitoring for team changes
- [ ] Schedule regular team membership audits

This comprehensive guide provides everything needed to implement team-based authorization for deployment security while maintaining the existing individual user support.