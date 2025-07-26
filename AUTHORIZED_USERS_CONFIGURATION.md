# Authorized Users Configuration Guide

## Quick Setup

### 1. Location
**File**: `.github/workflows/shared-deploy.yml` (in `no-keyvault-shared-github-actions` branch)
**Line**: ~75 in the `validate-environment` job

### 2. Configuration Format
```bash
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
```

### 3. User Identification
- Use **GitHub usernames** (not emails or display names)
- Case-sensitive (match GitHub profile casing)
- Comma-separated, no spaces
- Enclosed in double quotes

## Configuration Examples

### Basic Team Setup
```bash
# Small team (2-3 people)
AUTHORIZED_USERS="team-lead,devops-admin"

# Medium team (4-6 people)  
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer,senior-dev"

# Large team (enterprise)
AUTHORIZED_USERS="platform-admin,devops-manager,release-director,infrastructure-lead,security-engineer,production-operator"
```

### Role-Based Examples
```bash
# Production Operations Focus
AUTHORIZED_USERS="prod-ops-lead,infrastructure-manager,platform-engineer"

# Release Management Focus
AUTHORIZED_USERS="release-manager,deployment-lead,qa-director"

# Emergency Response Team
AUTHORIZED_USERS="on-call-engineer,site-reliability-lead,platform-architect"

# Single Administrator (Emergency Only)
AUTHORIZED_USERS="emergency-admin"
```

## Step-by-Step Configuration

### Step 1: Find Your GitHub Username
```bash
# Check your GitHub username
gh api user --jq .login

# Or visit: https://github.com/settings/profile
```

### Step 2: Edit the Shared Workflow
1. Switch to `no-keyvault-shared-github-actions` branch
2. Open `.github/workflows/shared-deploy.yml`
3. Find line ~75 with `AUTHORIZED_USERS=`
4. Update the user list

### Step 3: Test Configuration
```bash
# Test PPR manual override (should work for authorized users)
gh workflow run deploy.yml \
  -f environment=ppr \
  -f override_branch_validation=true \
  -f deploy_notes="Testing authorization"

# Test PROD emergency deployment (should work for authorized users)
gh workflow run deploy.yml \
  -f environment=prod \
  -f override_branch_validation=true \
  -f emergency_deployment=true \
  -f deploy_notes="Testing emergency access"
```

## Common Mistakes

### ❌ Incorrect Formats
```bash
# Wrong: Spaces around commas
AUTHORIZED_USERS="admin, devops-lead, release-manager"

# Wrong: Using emails
AUTHORIZED_USERS="john@company.com,jane@company.com"

# Wrong: Using display names  
AUTHORIZED_USERS="John Doe,Jane Smith"

# Wrong: Missing quotes
AUTHORIZED_USERS=admin,devops-lead

# Wrong: Extra quotes
AUTHORIZED_USERS="'admin','devops-lead'"
```

### ✅ Correct Format
```bash
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
```

## Protection Summary

| Environment | Auto Deployment | Manual Override | Emergency Required |
|-------------|------------------|-----------------|-------------------|
| **DEV** | `dev` branch | Any user | No |
| **SQE** | `sqe` branch | Any user | No |
| **PPR** | `release/**` | Authorized users only | No |
| **PROD** | Tags only | Authorized users only | Yes |

## Quick Reference Commands

### Add New User
```bash
# Current list
AUTHORIZED_USERS="admin,devops-lead,release-manager"

# Add new user
AUTHORIZED_USERS="admin,devops-lead,release-manager,new-user"
```

### Remove User
```bash
# Current list
AUTHORIZED_USERS="admin,devops-lead,release-manager,old-user"

# Remove user
AUTHORIZED_USERS="admin,devops-lead,release-manager"
```

### Verify User Exists
```bash
# Check if GitHub username exists
curl -s https://api.github.com/users/USERNAME | jq .login
```

## Emergency Access Setup

For teams that primarily use automated deployments but need emergency access:

```bash
# Minimal authorized users (emergency only)
AUTHORIZED_USERS="emergency-contact-1,emergency-contact-2"

# With backup contacts
AUTHORIZED_USERS="primary-admin,backup-admin,on-call-engineer"
```

## Troubleshooting

### Issue: "User not authorized" error
**Solution**: 
1. Check exact GitHub username spelling
2. Verify user is in `AUTHORIZED_USERS` list
3. Ensure no extra spaces or incorrect formatting

### Issue: Configuration not working
**Solution**:
1. Verify changes are committed to `no-keyvault-shared-github-actions` branch
2. Check for syntax errors in the workflow file
3. Ensure application is using the correct shared workflow reference

### Issue: Emergency deployment blocked
**Solution**:
1. Verify user is authorized
2. Ensure `emergency_deployment=true` is set for PROD
3. Provide deployment notes

## Best Practices

1. **Principle of Least Privilege**: Only authorize users who need production access
2. **Regular Reviews**: Audit the list monthly, remove inactive users
3. **Documentation**: Keep a record of why each user is authorized
4. **Testing**: Test configuration changes with non-production overrides first
5. **Emergency Contacts**: Maintain at least 2-3 authorized users for emergencies

## GitHub Enterprise Integration

For enterprise environments using GitHub teams and groups, see the comprehensive [GitHub Enterprise Configuration Guide](GITHUB_ENTERPRISE_CONFIGURATION.md) which covers:

- **Teams and Groups Setup**: Creating and managing GitHub teams
- **SAML/SSO Integration**: Identity provider configuration
- **Environment Protection**: Repository environment security rules
- **Branch Protection**: Advanced branch protection configurations
- **API Integration**: Team membership validation via GitHub API
- **Audit and Compliance**: Enterprise-grade logging and reporting

### Quick Team-Based Configuration

**Option 1: Individual Users (Current)**
```bash
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
```

**Option 2: Team-Based (Enterprise)**
```bash
AUTHORIZED_TEAMS="devops-team,release-team,platform-team"
AUTHORIZED_USERS="admin,emergency-contact-1"
```

**Option 3: Mixed Approach (Recommended)**
```bash
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
AUTHORIZED_TEAMS="devops-team,emergency-team"
```

## Support

For additional help:
- Review the full [Deployment Security Guide](DEPLOYMENT_SECURITY_GUIDE.md)
- For GitHub Enterprise: See [GitHub Enterprise Configuration Guide](GITHUB_ENTERPRISE_CONFIGURATION.md)
- Contact the platform engineering team
- Check deployment logs for specific error messages