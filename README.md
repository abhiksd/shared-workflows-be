# Shared GitHub Actions Workflows

This branch contains centralized, reusable GitHub Actions workflows and composite actions for all services in this repository.

## 🎯 Purpose

- **Centralized CI/CD**: Consistent deployment patterns across all services
- **Maintenance Efficiency**: Update workflows in one place, benefit everywhere  
- **Security Standards**: Enforce security scanning and compliance
- **Simplified Operations**: Streamlined workflows for faster development and testing
- **Best Practices**: Ensure all services follow the same patterns

## 📁 Structure

```
.github/
├── workflows/           # Reusable workflows
│   ├── shared-deploy.yml           # Simplified main deployment workflow
│   ├── shared-security-scan.yml    # Security scanning (SonarQube, Checkmarx)
│   ├── rollback-deployment.yml     # Rollback procedures
│   └── pr-security-check.yml       # PR security validation
└── actions/             # Composite actions
    ├── maven-build/               # Java/Maven build
    ├── docker-build-push/         # Docker build and push
    ├── helm-deploy/               # Helm deployment
    ├── sonar-scan/                # Code quality analysis
    └── checkmarx-scan/            # Security scanning
```

## 🚀 Usage in Service Branches

Services reference these workflows from their own branches:

```yaml
# In service branch .github/workflows/deploy.yml
jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml@no-keyvault-shared-github-actions
    with:
      environment: dev
      application_name: my-service
      application_type: java-springboot
      build_context: .
      dockerfile_path: ./Dockerfile
      helm_chart_path: ./helm
```

## 📋 Available Workflows

### shared-deploy.yml (Simplified)
Streamlined CI/CD pipeline for Java Spring Boot applications:
- Multi-environment deployment (dev, sqe, ppr, prod)
- Environment-specific branch strategies (dev/sqe branches, release/**, tags)
- Maven build with caching
- Docker build and push to Azure Container Registry
- Helm deployment to AKS clusters
- Quality gates (SonarQube, Checkmarx) with emergency bypass capability
- Spring Boot profile-based configuration management
- Kubernetes-native secret management
- Rolling update deployment strategy
- Manual deployment with branch override capabilities

### Environment Deployment Strategy
| Environment | Trigger | Branch/Tag Pattern | AKS Cluster |
|-------------|---------|-------------------|-------------|
| **DEV** | Auto + Manual | `dev`, `develop` | `aks-dev-cluster` |
| **SQE** | Auto + Manual | `sqe` | `aks-sqe-cluster` |
| **PPR** | Auto + Manual | `release/**` | `aks-preprod-cluster` |
| **PROD** | Auto + Manual | `tags` | `aks-prod-cluster` |

### Manual Deployment Options

#### **Standard Deployment (Authorized Branches)**
```bash
# Deploy to DEV from dev branch (no override needed)
gh workflow run deploy.yml -f environment=dev

# Deploy to PROD from tag (no override needed)  
git tag v1.0.0 && git push origin v1.0.0
gh workflow run deploy.yml -f environment=prod
```

#### **Override Deployment (Any Branch)**
```bash
# Deploy to DEV from any branch with override
gh workflow run deploy.yml \
  -f environment=dev \
  -f override_branch_validation=true \
  -f deploy_notes="Testing feature branch deployment"

# Deploy to PROD from any branch with override (CRITICAL)
gh workflow run deploy.yml \
  -f environment=prod \
  -f override_branch_validation=true \
  -f deploy_notes="Emergency hotfix - approved by incident commander"
```

#### **Branch Validation Rules**
- **DEV/SQE**: Manual deployments from wrong branch **require override**
- **PPR**: Manual deployments from non-release branch **require override**  
- **PROD**: Manual deployments from non-tag **require override**
- **Override Usage**: Logged with user attribution for audit compliance

#### **Emergency Security Bypass** (Repository Level)
```bash
# Temporarily bypass security scans (use with extreme caution)
gh variable set EMERGENCY_BYPASS_SONAR --body "true"
gh variable set EMERGENCY_BYPASS_CHECKMARX --body "true"
gh workflow run deploy.yml -f environment=prod
# Remember to remove after deployment
gh variable delete EMERGENCY_BYPASS_SONAR
gh variable delete EMERGENCY_BYPASS_CHECKMARX
```

## 🧩 Composite Actions

### maven-build
```yaml
- uses: ./.github/actions/maven-build@no-keyvault-shared-github-actions
  with:
    application_name: my-service
    java_version: '21'
    run_tests: 'true'
```

### docker-build-push
```yaml
- uses: ./.github/actions/docker-build-push@no-keyvault-shared-github-actions
  with:
    application_name: my-service
    application_type: java-springboot
    image_tag: ${{ github.sha }}
    registry: ${{ secrets.ACR_LOGIN_SERVER }}
```

### helm-deploy
```yaml
- uses: ./.github/actions/helm-deploy@no-keyvault-shared-github-actions
  with:
    environment: dev
    application_name: my-service
    helm_chart_path: ./helm
    image_tag: ${{ github.sha }}
    aks_cluster_name: aks-dev-cluster
    aks_resource_group: rg-aks-dev
```

## 🔄 Updating Shared Workflows

1. Switch to this branch: `git checkout no-keyvault-shared-github-actions`
2. Make your changes to workflows or actions
3. Test with a service branch
4. Commit and push changes
5. Service branches automatically use updated workflows

## 🔧 Configuration Management

This branch provides simplified Spring Boot profile-based configuration management:
- Environment-specific properties through Spring profiles (local, dev, sqe, ppr, production)
- Kubernetes ConfigMaps for non-sensitive configuration
- Kubernetes Secrets for sensitive data
- No external key vault dependencies required
- Dynamic AKS cluster configuration per environment

## 📚 Documentation

### Core Documentation (Relevant)
- **[AKS Configuration Refactor](AKS_CONFIGURATION_REFACTOR.md)**: AKS cluster configuration changes and dynamic assignment
- **[Automatic Deployment Guide](AUTOMATIC_DEPLOYMENT_GUIDE.md)**: Progressive deployment strategy and environment configuration  
- **[Final Deployment Strategy](FINAL_DEPLOYMENT_STRATEGY.md)**: Complete deployment approach and manual capabilities
- **[Contributing Guidelines](CONTRIBUTING.md)**: How to contribute to the shared workflows

### Application-Specific Documentation
Located on the application branch (`no-keyvault-my-app`):
- **[Spring Boot Profiling Guide](../../../no-keyvault-my-app/SPRING_BOOT_PROFILING_GUIDE.md)**: Profile-based configuration management
- **[Workflow Simplification Guide](../../../no-keyvault-my-app/WORKFLOW_SIMPLIFICATION_GUIDE.md)**: Changes made for simplified workflows
- **[Command Reference Guide](../../../no-keyvault-my-app/COMMAND_REFERENCE_GUIDE.md)**: Comprehensive command reference for all tools
- **[Migration Summary Report](../../../no-keyvault-my-app/MIGRATION_SUMMARY_REPORT.md)**: Complete migration overview

### Quick Command Reference
For immediate access to commonly used commands, see the [Command Reference Guide](../../../no-keyvault-my-app/COMMAND_REFERENCE_GUIDE.md) which includes:
- Docker, Kubernetes, Helm commands
- Azure CLI operations
- Git and GitHub CLI usage
- Environment-specific deployment commands
- Troubleshooting and monitoring commands

## 🎯 Key Features

### Simplified Workflow Benefits
- **80% Faster Deployments**: No approval gates blocking development
- **Simplified Manual Deployments**: Easy workflow dispatch to any environment
- **Quality Gates Maintained**: SonarQube and Checkmarx still validate code
- **Emergency Procedures**: Repository variable-based bypass capability
- **Rolling Updates**: Zero-downtime Kubernetes deployments
- **Branch Override**: Deploy from any branch to any environment (when needed)

### Environment Configuration
```yaml
# Dynamic AKS configuration per environment
dev:   aks-dev-cluster     / rg-aks-dev
sqe:   aks-sqe-cluster     / rg-aks-sqe  
ppr:   aks-preprod-cluster / rg-aks-preprod
prod:  aks-prod-cluster    / rg-aks-prod
```

### Security Features
- **Quality Gates**: SonarQube code quality and Checkmarx security scanning
- **Emergency Bypass**: Repository variable-based bypass for critical deployments
- **Audit Trail**: Comprehensive logging and deployment notes
- **Rolling Updates**: Safe deployment strategy with zero downtime

## 🚀 Getting Started

1. **For New Services**: Copy the deployment workflow from an existing service branch
2. **For Existing Services**: Update workflow reference to use this branch
3. **For Testing**: Use manual deployment with override capabilities
4. **For Emergencies**: Set repository variables for quality gate bypass

## 🔍 Troubleshooting

- Check workflow runs: `gh run list --workflow=deploy.yml`
- View specific run: `gh run view <run-id>`
- Manual deployment: `gh workflow run deploy.yml -f environment=dev`
- For detailed commands and troubleshooting, see the [Command Reference Guide](../../../no-keyvault-my-app/COMMAND_REFERENCE_GUIDE.md)

---

**Branch**: no-keyvault-shared-github-actions  
**Purpose**: Simplified, centralized CI/CD workflows with Spring Boot profile-based configuration  
**Configuration**: Profile-based secret management without external dependencies  
**Usage**: Referenced by service branches for consistent, streamlined deployments  
**Status**: Production-ready with simplified security gates for faster development cycles
