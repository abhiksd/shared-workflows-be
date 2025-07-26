# Final Deployment Strategy

This document describes the complete deployment strategy implemented across both codebases with environment-specific branches for lower environments and comprehensive manual deployment capabilities.

## 🎯 Deployment Strategy Overview

### Environment-Specific Branch Strategy

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│     DEV     │───▶│     SQE     │───▶│     PPR     │───▶│    PROD     │
│             │    │             │    │             │    │             │
│  dev branch │    │ sqe branch  │    │ release/**  │    │    tags     │
│ namespace:  │    │ namespace:  │    │ namespace:  │    │ namespace:  │
│     dev     │    │     sqe     │    │     ppr     │    │    prod     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## 🏗️ Environment Configuration

### Lower Environments (Environment-Specific Branches)

#### Development Environment
- **Branch**: `dev` (also supports `develop` for legacy)
- **Namespace**: `dev`
- **URL**: `https://dev.mydomain.com/backend1`
- **Auto-deploy**: ✅ On push to `dev` branch
- **Purpose**: Active development and feature testing

#### SQE Environment (System Quality Engineering)
- **Branch**: `sqe`
- **Namespace**: `sqe`
- **URL**: `https://sqe.mydomain.com/backend1`
- **Auto-deploy**: ✅ On push to `sqe` branch
- **Purpose**: System integration testing and quality validation

### Upper Environments (Existing Logic Preserved)

#### Pre-Production Environment
- **Branch**: `release/**` patterns (existing logic preserved)
- **Namespace**: `ppr`
- **URL**: `https://ppr.mydomain.com/backend1`
- **Auto-deploy**: ✅ On push to `release/**` branches
- **Purpose**: Final validation before production deployment

#### Production Environment
- **Branch**: **Tags** (existing tagging logic preserved)
- **Namespace**: `prod`
- **URL**: `https://production.mydomain.com/backend1`
- **Auto-deploy**: ✅ On tag creation (with manual approval gate)
- **Purpose**: Live production environment

## 🚀 Automatic Deployment Rules

| Environment | Branch/Tag Pattern | Trigger | Namespace | Validation |
|-------------|-------------------|---------|-----------|------------|
| **DEV** | `dev`, `develop` | Push | `dev` | Basic CI checks |
| **SQE** | `sqe` | Push | `sqe` | PR approval + CI |
| **PPR** | `release/**` | Push | `ppr` | Release validation |
| **PROD** | `refs/tags/*` | Tag creation | `prod` | Manual approval gate |

## 🎛️ Manual Deployment (Workflow Dispatch)

### Enhanced Manual Deployment Capabilities

The workflow dispatch provides comprehensive manual deployment options:

#### 1. Environment Selection
```yaml
environment:
  description: 'Environment to deploy to'
  type: choice
  options: [dev, sqe, ppr, prod]
  default: 'dev'
```

#### 2. Branch Validation Override
```yaml
override_branch_validation:
  description: 'Override branch validation (allows deployment from any branch)'
  type: boolean
  default: false
```

#### 3. Custom Image Tag
```yaml
custom_image_tag:
  description: 'Custom image tag (optional - uses auto-generated if empty)'
  type: string
  default: ''
```

#### 4. Force Deployment
```yaml
force_deploy:
  description: 'Force deployment even if no changes'
  type: boolean
  default: false
```

#### 5. Deployment Notes
```yaml
deploy_notes:
  description: 'Deployment notes/reason (for audit trail)'
  type: string
  default: 'Manual deployment via workflow dispatch'
```

### Manual Deployment Examples

#### Standard Manual Deployment
```bash
# Deploy to dev environment from any branch
gh workflow run deploy.yml \
  -f environment=dev \
  -f deploy_notes="Testing new feature X"
```

#### Emergency Production Deployment
```bash
# Deploy to production from hotfix branch with override
gh workflow run deploy.yml \
  -f environment=prod \
  -f override_branch_validation=true \
  -f custom_image_tag=hotfix-v1.2.1 \
  -f deploy_notes="Emergency hotfix for critical bug"
```

#### Specific Version Deployment
```bash
# Deploy specific version to staging
gh workflow run deploy.yml \
  -f environment=ppr \
  -f custom_image_tag=v1.2.0 \
  -f deploy_notes="Testing release candidate v1.2.0"
```

## 🔒 Validation Rules

### Automatic Deployment Validation
- **DEV**: Must be from `dev` or `develop` branch
- **SQE**: Must be from `sqe` branch
- **PPR**: Must be from `release/**` branch
- **PROD**: Must be from tag

### Manual Deployment Validation
- **Default**: Respects branch validation rules
- **Override**: Can deploy from any branch when `override_branch_validation=true`
- **All Environments**: Support manual deployment with appropriate permissions

## 🌟 Future Environment Extensibility

### Adding New Lower Environments

To add a new lower environment (e.g., `uat`):

1. **Create Branch**: Create `uat` branch
2. **Add Spring Profile**: Create `application-uat.yml`
3. **Add Helm Values**: Create `values-uat.yaml`
4. **Update Cluster Config**: Add `AKS_CLUSTER_NAME_UAT` and `AKS_RESOURCE_GROUP_UAT`

The deployment logic will automatically:
- Detect `refs/heads/uat` → `TARGET_ENV="uat"`
- Use namespace `uat`
- Support manual deployment to `uat` environment

### Example: Adding UAT Environment

```yaml
# In shared workflow - add cluster configuration
env:
  AKS_CLUSTER_NAME_UAT: "aks-uat-cluster"
  AKS_RESOURCE_GROUP_UAT: "rg-aks-uat"

# Auto-detection will automatically handle:
# refs/heads/uat → TARGET_ENV="uat"
```

## 📋 Deployment Scenarios

### 1. Feature Development Flow
```bash
# Developer creates feature branch
git checkout -b feature/new-api

# Work and commit changes
git commit -m "Add new API endpoint"

# Deploy to dev for testing
git checkout dev
git merge feature/new-api
git push origin dev
# ✅ Automatic deployment to DEV environment
```

### 2. Quality Engineering Flow
```bash
# Promote to SQE after dev testing
git checkout sqe
git merge dev
git push origin sqe
# ✅ Automatic deployment to SQE environment
```

### 3. Release Preparation Flow
```bash
# Create release branch for PPR
git checkout -b release/v1.2.0
git push origin release/v1.2.0
# ✅ Automatic deployment to PPR environment

# After PPR validation, create tag
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0
# ✅ Automatic deployment to PROD (with approval)
```

### 4. Emergency Deployment Flow
```bash
# Emergency hotfix from any branch
gh workflow run deploy.yml \
  -f environment=prod \
  -f override_branch_validation=true \
  -f deploy_notes="Critical security patch"
# ✅ Manual deployment with override
```

## 🔧 Technical Implementation

### Namespace Strategy
- **Lower Environments**: Namespace = Environment name (`dev`, `sqe`)
- **Upper Environments**: Namespace = Environment name (`ppr`, `prod`)
- **Future Environments**: Automatic namespace creation matching environment name

### Branch Validation Logic
```bash
# Lower environments: Branch name must match environment
if [[ "$GITHUB_REF" == "refs/heads/$TARGET_ENV" ]]; then
  SHOULD_DEPLOY="true"
fi

# Manual override available for all environments
if [[ "$EVENT_NAME" == "workflow_dispatch" && "$OVERRIDE_VALIDATION" == "true" ]]; then
  SHOULD_DEPLOY="true"
fi
```

### Custom Image Tag Integration
- **Default**: Auto-generated based on environment and git commit
- **Custom**: Uses provided image tag when specified
- **Version Strategy**: Integrates with existing version strategy action

## 📊 Benefits

### 1. Scalability
- **Easy Environment Addition**: Create branch → automatic integration
- **Consistent Patterns**: Lower environments follow same pattern
- **Minimal Configuration**: Only cluster config and Spring profiles needed

### 2. Flexibility
- **Branch Override**: Deploy from any branch when needed
- **Version Control**: Deploy specific versions using custom tags
- **Emergency Deployments**: Quick deployment capability with audit trail

### 3. Maintainability
- **Preserve Existing Logic**: PPR and PROD patterns unchanged
- **Clear Separation**: Lower vs upper environment strategies
- **Future-Proof**: Easy to extend and modify

### 4. Auditability
- **Deployment Notes**: Required for manual deployments
- **Branch Tracking**: Clear mapping of branch → environment
- **Override Logging**: Explicit logging when validation is bypassed

## ✅ Summary

The final deployment strategy provides:

- **🎯 Environment-Specific Branches**: For lower environments (dev, sqe)
- **🔄 Preserved Logic**: Existing release/** and tagging for upper environments
- **🚀 Full Manual Control**: Comprehensive workflow dispatch options
- **📈 Easy Extensibility**: Simple addition of new lower environments
- **🔒 Security**: Maintained validation rules with emergency override capability
- **📝 Audit Trail**: Complete logging and documentation of deployments

**Deployment Patterns**:
- **Dev/SQE**: Branch name = Environment name
- **PPR**: `release/**` branches (unchanged)
- **PROD**: Tags (unchanged)
- **Manual**: All environments with full flexibility

This strategy maintains all existing deployment logic while providing the flexibility requested for environment-specific branches and comprehensive manual deployment capabilities.