# Emergency Security Scan Bypass Guide

## 🚨 Overview

The Emergency Security Scan Bypass feature allows DevOps teams to temporarily bypass SonarQube and Checkmarx security scans during critical emergency deployments. This feature provides necessary flexibility while maintaining strict authorization controls and comprehensive audit trails.

## ⚠️ Important Security Notice

**WARNING**: This feature bypasses critical security controls and should only be used for genuine emergencies. Improper use can introduce security vulnerabilities into production systems.

### When to Use Emergency Bypass

✅ **Appropriate Use Cases:**
- Critical security patches requiring immediate deployment
- Production outages blocking business operations
- Hot fixes for data corruption issues
- Compliance-mandated urgent updates
- Service disruptions requiring immediate resolution

❌ **Inappropriate Use Cases:**
- Routine deployment delays
- Failed scans due to code quality issues
- Time pressure from business deadlines
- Developer convenience
- Avoiding scan remediation work

## 🔧 How It Works

### Repository Variables Control

The emergency bypass is controlled through GitHub repository variables that can be set by authorized DevOps team members:

- `EMERGENCY_BYPASS_SONAR`: Controls SonarQube scan bypass
- `EMERGENCY_BYPASS_CHECKMARX`: Controls Checkmarx scan bypass

### Authorization Levels

1. **Repository Variable Management**: DevOps team members with repository admin access
2. **Deployment Authorization**: Authorized users defined in the workflow
3. **Audit Trail**: All bypass activities are logged for compliance

## 📋 Step-by-Step Emergency Bypass Process

### Step 1: Assess Emergency Situation

**Confirm Genuine Emergency:**
- Document the critical issue requiring bypass
- Verify business impact and urgency
- Confirm no alternative solutions exist
- Get stakeholder approval if required

### Step 2: Enable Emergency Bypass

**Navigate to Repository Variables:**
```
GitHub Repository → Settings → Secrets and variables → Actions → Variables tab
```

**Add Repository Variables:**

**For SonarQube Bypass:**
```
Variable Name: EMERGENCY_BYPASS_SONAR
Variable Value: true
```

**For Checkmarx Bypass:**
```
Variable Name: EMERGENCY_BYPASS_CHECKMARX  
Variable Value: true
```

### Step 3: Deploy with Emergency Bypass

**Trigger Deployment:**
```bash
# Manual deployment with emergency bypass enabled
gh workflow run deploy.yml \
  -f environment=prod \
  -f override_branch_validation=true \
  -f emergency_deployment=true \
  -f deploy_notes="EMERGENCY: Critical security patch - CVE-2024-XXXX. Bypass approved by security team."
```

**Verify Bypass Activation:**
- Check workflow logs for bypass confirmation messages
- Confirm scans are skipped and marked as "BYPASSED"
- Verify deployment proceeds despite bypass

### Step 4: Post-Deployment Actions (CRITICAL)

**Immediate Actions (Within 1 Hour):**
1. **Disable Bypass Variables**:
   - Delete `EMERGENCY_BYPASS_SONAR` variable
   - Delete `EMERGENCY_BYPASS_CHECKMARX` variable

2. **Document Emergency**:
   - Record bypass justification
   - Document business impact
   - Note approval chain

**Within 24 Hours:**
3. **Conduct Manual Security Review**:
   - Review deployed code changes
   - Perform manual security assessment
   - Validate emergency fix effectiveness

4. **Schedule Retroactive Scans**:
   - Run SonarQube scan on deployed code
   - Execute Checkmarx security scan
   - Address any identified issues

**Within 1 Week:**
5. **Process Review**:
   - Review emergency process effectiveness
   - Identify process improvements
   - Update emergency procedures if needed

## 🔍 Emergency Bypass Behavior

### SonarQube Bypass

**Normal Flow:**
```
SonarQube Scan → Quality Gate Validation → Build Process
```

**Emergency Bypass Flow:**
```
SonarQube Bypass Check → Skip Scan → Mark as BYPASSED → Build Process
```

**Repository Variable Check:**
```yaml
- name: SonarQube Scan
  if: vars.EMERGENCY_BYPASS_SONAR != 'true'
  # Scan only runs if bypass variable is not set to 'true'
```

### Checkmarx Bypass

**Normal Flow:**
```
Checkmarx Scan → Security Validation → Build Process
```

**Emergency Bypass Flow:**
```
Checkmarx Bypass Check → Skip Scan → Mark as BYPASSED → Build Process
```

**Repository Variable Check:**
```yaml
- name: Checkmarx Scan
  if: vars.EMERGENCY_BYPASS_CHECKMARX != 'true'
  # Scan only runs if bypass variable is not set to 'true'
```

## 🛡️ Authorization and Security Controls

### Multi-Layer Authorization

#### Layer 1: Repository Variable Access
- **Required**: Repository admin or maintain permissions
- **Purpose**: Control who can enable/disable bypass
- **Verification**: GitHub audit logs

#### Layer 2: Deployment Authorization  
- **Required**: User in authorized users list
- **Purpose**: Control who can perform deployments
- **Verification**: Workflow authorization check

#### Layer 3: Emergency Flag (PROD only)
- **Required**: `emergency_deployment=true` for production
- **Purpose**: Explicit emergency declaration
- **Verification**: Production approval gate

### Authorization Matrix

| Action | Repository Admin | Authorized User | Regular User |
|--------|-----------------|----------------|--------------|
| **Set Bypass Variables** | ✅ | ❌ | ❌ |
| **Deploy with Bypass** | ✅ (if in auth list) | ✅ | ❌ |
| **View Bypass Status** | ✅ | ✅ | ✅ |
| **Audit Trail Access** | ✅ | ✅ | ✅ |

## 📊 Bypass Status Monitoring

### Workflow Log Messages

**SonarQube Bypass Activated:**
```
🚨 EMERGENCY BYPASS ACTIVATED: SonarQube scan will be bypassed
   Repository variable EMERGENCY_BYPASS_SONAR: true
   Authorized user: admin
   Target environment: prod
   Reason: Emergency deployment bypass (repository configuration)
   ⚠️  SECURITY WARNING: Quality gate bypassed - immediate manual review required

📋 EMERGENCY BYPASS CONDITIONS MET:
   ✅ EMERGENCY_BYPASS_SONAR repository variable set to 'true'
   ✅ User 'admin' is in authorized users list
   ✅ Bypass approved for emergency deployment

⚠️  POST-DEPLOYMENT ACTIONS REQUIRED:
   1. Delete EMERGENCY_BYPASS_SONAR repository variable immediately after deployment
   2. Conduct manual security review of deployed code
   3. Schedule retroactive SonarQube scan
   4. Document emergency bypass justification
```

**Checkmarx Bypass Activated:**
```
🚨 EMERGENCY BYPASS ACTIVATED: Checkmarx scan will be bypassed
   Repository variable EMERGENCY_BYPASS_CHECKMARX: true
   Authorized user: admin
   Target environment: prod
   Reason: Emergency deployment bypass (repository configuration)
   ⚠️  SECURITY WARNING: Security scan bypassed - immediate manual review required

📋 EMERGENCY BYPASS CONDITIONS MET:
   ✅ EMERGENCY_BYPASS_CHECKMARX repository variable set to 'true'
   ✅ User 'admin' is in authorized users list
   ✅ Bypass approved for emergency deployment

⚠️  POST-DEPLOYMENT ACTIONS REQUIRED:
   1. Delete EMERGENCY_BYPASS_CHECKMARX repository variable immediately after deployment
   2. Conduct manual security review of deployed code
   3. Schedule retroactive Checkmarx security scan
   4. Document emergency bypass justification
```

### Production Approval Display

When bypass is active, the production approval gate shows:

```
✅ Quality Gates Status:
   SonarQube: BYPASSED
   Checkmarx: BYPASSED

🚨 EMERGENCY BYPASS ALERT - SonarQube:
   Status: BYPASSED
   Reason: Emergency bypass by admin
   ⚠️  Manual security review required post-deployment

🚨 EMERGENCY BYPASS ALERT - Checkmarx:
   Status: BYPASSED
   Reason: Emergency bypass by admin
   ⚠️  Manual security review required post-deployment
```

## 🔧 Configuration Management

### Repository Variables Setup

#### Creating Variables

**Via GitHub UI:**
1. Navigate to Repository → Settings → Secrets and variables → Actions
2. Click "Variables" tab
3. Click "New repository variable"
4. Add variable name and value

**Via GitHub CLI:**
```bash
# Enable SonarQube bypass
gh variable set EMERGENCY_BYPASS_SONAR --body "true"

# Enable Checkmarx bypass  
gh variable set EMERGENCY_BYPASS_CHECKMARX --body "true"
```

#### Removing Variables

**Via GitHub UI:**
1. Navigate to Repository → Settings → Secrets and variables → Actions
2. Click "Variables" tab
3. Find the variable and click "Delete"

**Via GitHub CLI:**
```bash
# Disable SonarQube bypass
gh variable delete EMERGENCY_BYPASS_SONAR

# Disable Checkmarx bypass
gh variable delete EMERGENCY_BYPASS_CHECKMARX
```

### Authorized Users Management

The authorized users list is configured in the shared workflow:

**Location**: `.github/workflows/shared-deploy.yml`
**Variable**: `AUTHORIZED_USERS`

```bash
# Current authorized users for emergency bypass
AUTHORIZED_USERS="admin,devops-lead,release-manager,platform-engineer"
```

**To Add Users:**
1. Edit the shared workflow file
2. Add usernames to the `AUTHORIZED_USERS` list
3. Commit and push changes

## 📈 Monitoring and Alerting

### Key Metrics to Track

- **Bypass Frequency**: Number of emergency bypasses per month
- **Bypass Duration**: Time between enabling and disabling bypass
- **Post-Deployment Actions**: Completion of required follow-up tasks
- **False Emergencies**: Bypasses used inappropriately
- **Audit Compliance**: Documentation and approval completeness

### Recommended Alerts

#### Immediate Alerts (Real-time)
```yaml
Emergency Bypass Enabled:
  - Trigger: Repository variable created (EMERGENCY_BYPASS_*)
  - Recipients: DevOps team, Security team
  - Message: "🚨 Emergency bypass enabled in {repository}"

Emergency Deployment:
  - Trigger: Deployment with BYPASSED scan status
  - Recipients: DevOps lead, Security lead
  - Message: "🚨 Emergency deployment executed with security bypass"
```

#### Follow-up Alerts (Time-based)
```yaml
Bypass Cleanup Reminder:
  - Trigger: 2 hours after bypass enabled
  - Recipients: DevOps team
  - Message: "⏰ Reminder: Disable emergency bypass variables"

Retroactive Scan Reminder:
  - Trigger: 24 hours after emergency deployment
  - Recipients: Security team, DevOps team
  - Message: "📊 Schedule retroactive security scans for emergency deployment"
```

## 🔍 Audit and Compliance

### Audit Trail Components

#### GitHub Native Auditing
```yaml
Repository Variables:
  - Creation timestamps
  - Modification history
  - User attribution
  - Value changes

Workflow Executions:
  - Bypass activation logs
  - User authorization checks
  - Deployment outcomes
  - Approval decisions
```

#### Workflow Logging
```yaml
Emergency Bypass Logs:
  - Tool bypassed (SonarQube/Checkmarx)
  - User performing bypass
  - Timestamp of activation
  - Justification provided
  - Repository variable status
```

### Compliance Reporting

#### Monthly Audit Report
```yaml
Emergency Bypass Summary:
  Total Bypasses: 3
  SonarQube Bypasses: 2
  Checkmarx Bypasses: 1
  Average Duration: 4.2 hours
  Compliance Rate: 100% (all post-actions completed)

Breakdown by User:
  - admin: 2 bypasses (emergency patches)
  - devops-lead: 1 bypass (production outage)

Follow-up Completion:
  - Variable cleanup: 100% (within 2 hours)
  - Manual reviews: 100% (within 24 hours)
  - Retroactive scans: 100% (within 48 hours)
```

## ⚡ Emergency Scenarios

### Scenario 1: Critical Security Patch

**Situation**: Zero-day vulnerability requiring immediate patch

**Process:**
1. **Enable Bypass**: Set both `EMERGENCY_BYPASS_SONAR` and `EMERGENCY_BYPASS_CHECKMARX` to `true`
2. **Deploy**: Use manual deployment with emergency flag
3. **Monitor**: Verify patch effectiveness
4. **Cleanup**: Disable bypass variables within 1 hour
5. **Review**: Conduct security review within 24 hours

### Scenario 2: Production Outage

**Situation**: Critical bug causing service disruption

**Process:**
1. **Assess**: Confirm business impact and urgency
2. **Enable Bypass**: Set relevant bypass variable to `true`
3. **Deploy**: Emergency deployment with detailed notes
4. **Validate**: Confirm outage resolution
5. **Follow-up**: Complete all post-deployment actions

### Scenario 3: Compliance-Mandated Update

**Situation**: Regulatory requirement with strict deadline

**Process:**
1. **Document**: Record compliance requirement and deadline
2. **Approve**: Get stakeholder approval for bypass
3. **Enable Bypass**: Set appropriate variables
4. **Deploy**: Execute deployment with compliance notes
5. **Audit**: Provide compliance documentation

## 🎯 Best Practices

### Emergency Preparedness
1. **Pre-Authorization**: Maintain updated authorized users list
2. **Process Documentation**: Keep emergency procedures accessible
3. **Contact Lists**: Maintain current emergency contact information
4. **Escalation Paths**: Define clear escalation procedures

### During Emergency
1. **Quick Assessment**: Rapidly confirm genuine emergency
2. **Minimal Bypass**: Only bypass necessary scans
3. **Clear Documentation**: Provide detailed deployment notes
4. **Team Communication**: Notify relevant stakeholders

### Post-Emergency
1. **Immediate Cleanup**: Disable bypass variables quickly
2. **Thorough Review**: Conduct comprehensive security assessment
3. **Process Improvement**: Identify lessons learned
4. **Documentation**: Complete audit documentation

## 🚀 Implementation Checklist

### Initial Setup
- [ ] Configure authorized users list in shared workflow
- [ ] Set up monitoring and alerting for bypass events
- [ ] Create emergency contact lists
- [ ] Document emergency procedures

### Emergency Activation
- [ ] Assess and confirm genuine emergency situation
- [ ] Get required approvals and authorizations
- [ ] Set appropriate repository variables
- [ ] Execute emergency deployment
- [ ] Verify deployment success

### Post-Emergency Actions
- [ ] Disable bypass repository variables
- [ ] Document emergency justification
- [ ] Conduct manual security review
- [ ] Schedule retroactive security scans
- [ ] Update procedures based on lessons learned

## 📚 Related Documentation

- [Production Approval Gate Guide](PRODUCTION_APPROVAL_GATE_GUIDE.md)
- [Deployment Security Guide](DEPLOYMENT_SECURITY_GUIDE.md)
- [GitHub Enterprise Configuration](GITHUB_ENTERPRISE_CONFIGURATION.md)
- [Authorized Users Configuration](AUTHORIZED_USERS_CONFIGURATION.md)

## 🆘 Emergency Contacts

```yaml
DevOps Team:
  - Primary: devops-lead@company.com
  - Secondary: platform-engineer@company.com
  
Security Team:
  - Primary: security-lead@company.com
  - Secondary: security-engineer@company.com
  
Management Escalation:
  - Director: engineering-director@company.com
  - VP: vp-engineering@company.com
```

## 🎉 Summary

The Emergency Security Scan Bypass feature provides critical flexibility for emergency deployments while maintaining:

- **🔐 Strong Authorization Controls**: Multi-layer authorization requirements
- **📝 Complete Audit Trail**: Comprehensive logging and tracking
- **⚡ Rapid Response**: Quick bypass activation for genuine emergencies
- **🛡️ Security Safeguards**: Authorized users and post-deployment requirements
- **📊 Monitoring and Compliance**: Full visibility and reporting capabilities

This feature ensures that emergency situations can be handled quickly without compromising long-term security standards or compliance requirements.