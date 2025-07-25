#!/bin/bash

# Create Shared Workflows Repository Script
# Sets up centralized GitHub Actions workflows repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMP_DIR=""

# Configuration
ORG_NAME="${1}"
SHARED_WORKFLOWS_REPO="${2:-shared-workflows}"

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  🔄 Shared Workflows Repository Creator${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${CYAN}Organization: ${ORG_NAME}${NC}"
    echo -e "${CYAN}Repository: ${SHARED_WORKFLOWS_REPO}${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}✨ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        print_info "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

usage() {
    echo "Usage: $0 <org-name> [shared-workflows-repo-name]"
    echo ""
    echo "Examples:"
    echo "  $0 mycompany"
    echo "  $0 mycompany shared-workflows"
    echo "  $0 mycompany shared-devops-workflows"
    echo ""
    echo "Arguments:"
    echo "  org-name                  GitHub organization name"
    echo "  shared-workflows-repo     Repository name for shared workflows (default: shared-workflows)"
    exit 1
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("gh" "git")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check GitHub authentication
    if ! gh auth status &> /dev/null; then
        print_error "Not authenticated with GitHub CLI. Run: gh auth login"
        exit 1
    fi
    
    # Check if we're in the correct directory
    if [[ ! -d "$ROOT_DIR/.github/workflows" ]] || [[ ! -d "$ROOT_DIR/.github/actions" ]]; then
        print_error "Please run this script from the root of the shared-workflows-be repository"
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
}

create_repository() {
    print_step "Creating shared workflows repository..."
    
    local full_repo_name="${ORG_NAME}/${SHARED_WORKFLOWS_REPO}"
    
    # Check if repository already exists
    if gh repo view "$full_repo_name" &> /dev/null; then
        print_warning "Repository $full_repo_name already exists"
        read -p "Do you want to continue and update it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Operation cancelled by user"
            exit 0
        fi
    else
        # Create repository
        gh repo create "$full_repo_name" \
            --public \
            --description "Centralized GitHub Actions workflows and composite actions for microservices" \
            --add-readme=false
        
        print_success "Repository created: $full_repo_name"
    fi
}

clone_and_setup() {
    print_step "Setting up local repository..."
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Clone the repository
    gh repo clone "${ORG_NAME}/${SHARED_WORKFLOWS_REPO}"
    cd "$SHARED_WORKFLOWS_REPO"
    
    print_success "Repository cloned to temporary directory"
}

copy_workflows() {
    print_step "Copying shared workflows..."
    
    # Create directory structure
    mkdir -p .github/workflows
    
    # Copy all shared workflows
    local workflows=(
        "shared-deploy.yml"
        "shared-security-scan.yml"
        "rollback-deployment.yml"
        "deploy-monitoring.yml"
        "monitoring-deploy.yml"
        "pr-security-check.yml"
    )
    
    for workflow in "${workflows[@]}"; do
        if [[ -f "$ROOT_DIR/.github/workflows/$workflow" ]]; then
            cp "$ROOT_DIR/.github/workflows/$workflow" .github/workflows/
            print_success "Copied workflow: $workflow"
        else
            print_warning "Workflow not found: $workflow"
        fi
    done
}

copy_composite_actions() {
    print_step "Copying composite actions..."
    
    # Create actions directory
    mkdir -p .github/actions
    
    # Copy all composite actions
    local actions=(
        "maven-build"
        "docker-build-push"
        "helm-deploy"
        "sonar-scan"
        "checkmarx-scan"
        "create-release"
        "version-strategy"
        "workspace-cleanup"
        "check-changes"
    )
    
    for action in "${actions[@]}"; do
        if [[ -d "$ROOT_DIR/.github/actions/$action" ]]; then
            cp -r "$ROOT_DIR/.github/actions/$action" .github/actions/
            print_success "Copied action: $action"
        else
            print_warning "Action not found: $action"
        fi
    done
}

create_documentation() {
    print_step "Creating documentation..."
    
    # Create main README
    cat > README.md << 'EOF'
# Shared GitHub Actions Workflows

This repository contains centralized, reusable GitHub Actions workflows and composite actions for all microservices in the organization.

## 🎯 Purpose

- **Centralized CI/CD**: Consistent deployment patterns across all services
- **Maintenance Efficiency**: Update workflows in one place, benefit everywhere
- **Security Standards**: Enforce security scanning and compliance across all services
- **Best Practices**: Ensure all services follow the same deployment patterns

## 📁 Repository Structure

```
.github/
├── workflows/           # Reusable workflows
│   ├── shared-deploy.yml           # Main deployment workflow
│   ├── shared-security-scan.yml    # Security scanning
│   ├── rollback-deployment.yml     # Rollback procedures
│   ├── deploy-monitoring.yml       # Monitoring stack deployment
│   └── pr-security-check.yml       # PR security validation
└── actions/             # Composite actions
    ├── maven-build/               # Java/Maven build action
    ├── docker-build-push/         # Docker build and push
    ├── helm-deploy/               # Helm deployment
    ├── sonar-scan/                # SonarQube analysis
    ├── checkmarx-scan/            # Security scanning
    ├── create-release/            # GitHub release creation
    ├── version-strategy/          # Version management
    ├── workspace-cleanup/         # Cleanup operations
    └── check-changes/             # Change detection
```

## 🚀 Available Workflows

### 1. shared-deploy.yml
**Purpose**: Complete CI/CD pipeline for Java Spring Boot and Node.js applications

**Features**:
- Multi-environment deployment (dev, staging, production)
- Java Spring Boot and Node.js support
- Docker build and push to Azure Container Registry
- Helm deployment to Azure Kubernetes Service
- Security scanning integration
- Rollback capabilities

**Usage**:
```yaml
jobs:
  deploy:
    uses: your-org/shared-workflows/.github/workflows/shared-deploy.yml@main
    with:
      environment: dev
      application_name: my-service
      application_type: java-springboot  # or nodejs
      build_context: .
      dockerfile_path: ./Dockerfile
      helm_chart_path: ./helm
      # AKS cluster configuration
      aks_cluster_name_dev: ${{ vars.AKS_CLUSTER_NAME_DEV }}
      aks_resource_group_dev: ${{ vars.AKS_RESOURCE_GROUP_DEV }}
    secrets:
      ACR_LOGIN_SERVER: ${{ secrets.ACR_LOGIN_SERVER }}
      AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      KEYVAULT_NAME: ${{ secrets.KEYVAULT_NAME }}
```

### 2. shared-security-scan.yml
**Purpose**: Comprehensive security scanning for applications

**Features**:
- Dependency vulnerability scanning
- Static code analysis
- Container image security scanning
- License compliance checking

**Usage**:
```yaml
jobs:
  security-scan:
    uses: your-org/shared-workflows/.github/workflows/shared-security-scan.yml@main
    with:
      application_type: java-springboot
      scan_type: full  # or quick
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      CHECKMARX_TOKEN: ${{ secrets.CHECKMARX_TOKEN }}
```

### 3. rollback-deployment.yml
**Purpose**: Automated rollback procedures for failed deployments

**Features**:
- Helm-based rollbacks
- Database migration rollbacks
- Traffic routing rollbacks
- Notification integration

**Usage**:
```yaml
jobs:
  rollback:
    uses: your-org/shared-workflows/.github/workflows/rollback-deployment.yml@main
    with:
      environment: production
      application_name: my-service
      rollback_version: previous  # or specific version
```

### 4. deploy-monitoring.yml
**Purpose**: Deploy and configure monitoring stack

**Features**:
- Prometheus deployment
- Grafana dashboard setup
- Alert manager configuration
- Service discovery setup

### 5. pr-security-check.yml
**Purpose**: Security validation for pull requests

**Features**:
- Lightweight security scanning
- Dependency vulnerability check
- Secret detection
- Code quality gates

## 🧩 Available Composite Actions

### maven-build
Builds Java applications using Maven with caching and validation.

```yaml
- uses: your-org/shared-workflows/.github/actions/maven-build@main
  with:
    application_name: my-java-service
    build_context: .
    java_version: '21'
    run_tests: 'true'
```

### docker-build-push
Builds and pushes Docker images with multi-arch support and caching.

```yaml
- uses: your-org/shared-workflows/.github/actions/docker-build-push@main
  with:
    application_name: my-service
    application_type: java-springboot
    build_context: .
    dockerfile_path: ./Dockerfile
    image_tag: ${{ github.sha }}
    registry: myregistry.azurecr.io
```

### helm-deploy
Deploys applications to Kubernetes using Helm charts.

```yaml
- uses: your-org/shared-workflows/.github/actions/helm-deploy@main
  with:
    environment: dev
    application_name: my-service
    helm_chart_path: ./helm
    image_tag: ${{ github.sha }}
    aks_cluster_name: my-dev-cluster
    aks_resource_group: my-dev-rg
```

## 📋 Service Repository Setup

### 1. Create Service Repository Workflow

Create `.github/workflows/deploy.yml` in your service repository:

```yaml
name: Deploy My Service

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options: [dev, staging, production]

jobs:
  deploy:
    uses: your-org/shared-workflows/.github/workflows/shared-deploy.yml@main
    with:
      environment: ${{ github.event.inputs.environment || 'auto' }}
      application_name: my-service
      application_type: java-springboot
      build_context: .
      dockerfile_path: ./Dockerfile
      helm_chart_path: ./helm
      aks_cluster_name_dev: ${{ vars.AKS_CLUSTER_NAME_DEV }}
      aks_resource_group_dev: ${{ vars.AKS_RESOURCE_GROUP_DEV }}
      aks_cluster_name_sqe: ${{ vars.AKS_CLUSTER_NAME_SQE }}
      aks_resource_group_sqe: ${{ vars.AKS_RESOURCE_GROUP_SQE }}
      aks_cluster_name_prod: ${{ vars.AKS_CLUSTER_NAME_PROD }}
      aks_resource_group_prod: ${{ vars.AKS_RESOURCE_GROUP_PROD }}
    secrets:
      ACR_LOGIN_SERVER: ${{ secrets.ACR_LOGIN_SERVER }}
      KEYVAULT_NAME: ${{ secrets.KEYVAULT_NAME }}
      AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

### 2. Required Repository Secrets

Set up these secrets in each service repository:

- `ACR_LOGIN_SERVER` - Azure Container Registry URL
- `AZURE_CLIENT_ID` - Azure Service Principal Client ID
- `AZURE_TENANT_ID` - Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure Subscription ID
- `KEYVAULT_NAME` - Azure Key Vault name

### 3. Required Repository Variables

Set up these variables in each service repository:

- `AKS_CLUSTER_NAME_DEV` - Development AKS cluster name
- `AKS_RESOURCE_GROUP_DEV` - Development resource group
- `AKS_CLUSTER_NAME_SQE` - Staging AKS cluster name
- `AKS_RESOURCE_GROUP_SQE` - Staging resource group
- `AKS_CLUSTER_NAME_PROD` - Production AKS cluster name
- `AKS_RESOURCE_GROUP_PROD` - Production resource group

## 🔄 Workflow Update Process

### Making Changes
1. Create a feature branch in this repository
2. Make necessary changes to workflows or actions
3. Test changes with a service repository
4. Create pull request with detailed description
5. After approval and merge, service repositories automatically use the updated workflows

### Version Management
- **main branch**: Latest stable version (recommended for production)
- **develop branch**: Development version (for testing new features)
- **Version tags**: Specific stable versions (e.g., v1.0.0, v1.1.0)

### Best Practices
- Always test workflow changes with a development service first
- Use semantic versioning for major changes
- Document breaking changes in release notes
- Maintain backward compatibility when possible

## 📊 Monitoring and Observability

### Workflow Monitoring
- All workflows include comprehensive logging
- Metrics collection for deployment success rates
- Integration with monitoring systems
- Slack/Teams notifications for failures

### Security Monitoring
- Automated security scanning on all workflows
- Vulnerability tracking and reporting
- Compliance checking and enforcement
- Regular security audits

## 🛠️ Troubleshooting

### Common Issues

#### Workflow Not Found
```
Error: workflow not found: shared-deploy.yml
```
**Solution**: Ensure the workflow reference points to the correct repository and branch:
```yaml
uses: your-org/shared-workflows/.github/workflows/shared-deploy.yml@main
```

#### Permission Denied
```
Error: Resource not accessible by integration
```
**Solution**: Check that the calling repository has access to this shared workflows repository and all required secrets are configured.

#### Build Failures
```
Error: Maven build failed
```
**Solution**: Check the Maven build logs in the workflow run details. Common issues:
- Missing dependencies
- Incorrect Java version
- Test failures

### Getting Help
1. Check the workflow run logs for detailed error messages
2. Review the troubleshooting section in service-specific documentation
3. Create an issue in this repository for workflow-related problems
4. Contact the DevOps team for urgent issues

## 🤝 Contributing

### Workflow Contributions
1. Fork this repository
2. Create a feature branch (`git checkout -b feature/amazing-workflow`)
3. Make your changes and test thoroughly
4. Commit your changes (`git commit -m 'Add amazing workflow feature'`)
5. Push to the branch (`git push origin feature/amazing-workflow`)
6. Open a Pull Request

### Guidelines
- Follow existing patterns and conventions
- Include comprehensive documentation
- Add appropriate error handling
- Test with multiple service types
- Include security considerations

### Review Process
- All changes require DevOps team review
- Breaking changes require additional approval
- Security-related changes require security team review

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Issues**: Create an issue in this repository
- **Questions**: DevOps team Slack channel #devops-support
- **Urgent Issues**: Contact DevOps on-call engineer

---

**Maintained by**: DevOps Team  
**Last Updated**: December 2024  
**Version**: 2.0.0
EOF

    # Create CHANGELOG
    cat > CHANGELOG.md << 'EOF'
# Changelog

All notable changes to the shared workflows will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial setup of shared workflows repository
- Comprehensive documentation and usage examples

## [2.0.0] - 2024-12-XX

### Added
- Complete shared workflows repository setup
- Reusable deployment workflow for Java Spring Boot services
- Reusable deployment workflow for Node.js services
- Security scanning workflows
- Rollback deployment procedures
- Monitoring deployment workflows
- Comprehensive composite actions library
- Multi-environment support (dev, staging, production)
- Azure Kubernetes Service integration
- Azure Container Registry integration
- Helm deployment support
- Maven build automation
- Docker multi-arch build support
- Security vulnerability scanning
- Dependency checking
- Code quality gates

### Security
- Implemented comprehensive security scanning
- Added dependency vulnerability checks
- Container image security scanning
- Secret detection in code
- License compliance checking

### Documentation
- Complete README with usage examples
- Troubleshooting guide
- Contributing guidelines
- Security best practices
- Migration documentation

## [1.0.0] - 2024-11-XX

### Added
- Initial monorepo structure with individual service workflows
- Basic CI/CD for Java Spring Boot services
- Docker build and deployment
- Kubernetes Helm chart support

### Changed
- Migrated from individual service workflows to shared workflows
- Centralized composite actions
- Improved security scanning integration

### Deprecated
- Individual service workflow files (replaced by shared workflows)

### Removed
- Duplicate workflow code across services
- Service-specific CI/CD configurations

### Fixed
- Inconsistent deployment patterns across services
- Security scanning gaps
- Resource cleanup issues

### Security
- Enhanced security scanning with multiple tools
- Improved secret management
- Better access controls
EOF

    # Create CONTRIBUTING.md
    cat > CONTRIBUTING.md << 'EOF'
# Contributing to Shared Workflows

Thank you for contributing to our shared workflows repository! This document provides guidelines for contributing to this project.

## 🎯 Contribution Types

### Workflow Improvements
- Bug fixes in existing workflows
- Performance optimizations
- New workflow features
- Enhanced error handling

### New Workflows
- Support for new application types
- Additional deployment targets
- New security scanning tools
- Monitoring and observability enhancements

### Composite Actions
- New reusable actions
- Improvements to existing actions
- Better input validation
- Enhanced output handling

### Documentation
- Usage examples
- Troubleshooting guides
- Best practices
- API documentation

## 📋 Before Contributing

1. **Check existing issues** - Look for existing issues or feature requests
2. **Discuss major changes** - For significant changes, create an issue first
3. **Test thoroughly** - Ensure your changes work across different service types
4. **Follow conventions** - Maintain consistency with existing patterns

## 🔧 Development Process

### 1. Fork and Clone
```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/your-username/shared-workflows.git
cd shared-workflows
```

### 2. Create Feature Branch
```bash
git checkout -b feature/your-feature-name
```

### 3. Make Changes
- Follow existing code patterns
- Include appropriate error handling
- Add comprehensive logging
- Update documentation as needed

### 4. Test Changes
- Test with multiple service types (Java, Node.js)
- Test across different environments (dev, staging)
- Verify backwards compatibility
- Check security implications

### 5. Commit Changes
```bash
git add .
git commit -m "feat: add new deployment workflow for Python services

- Add support for Python Flask/Django applications
- Include pip dependency management
- Add pytest integration
- Update documentation with Python examples"
```

### 6. Push and Create PR
```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub.

## 📝 Commit Message Convention

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Format
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples
```
feat(deploy): add support for Python applications
fix(maven): resolve dependency caching issue
docs(readme): update usage examples for new workflow
refactor(docker): improve build performance
```

## 🧪 Testing Guidelines

### Workflow Testing
1. **Unit Testing**: Test individual components
2. **Integration Testing**: Test complete workflows
3. **Cross-Service Testing**: Test with different service types
4. **Environment Testing**: Test across dev/staging/prod

### Testing Checklist
- [ ] Workflow runs successfully
- [ ] All outputs are generated correctly
- [ ] Error handling works as expected
- [ ] Security scanning completes
- [ ] Deployment succeeds
- [ ] Rollback procedures work
- [ ] Documentation is accurate

### Test Services
Use these test services for validation:
- `test-java-service`: Java Spring Boot test service
- `test-nodejs-service`: Node.js Express test service
- `test-python-service`: Python Flask test service

## 📚 Documentation Standards

### Workflow Documentation
Each workflow should include:
- Purpose and use cases
- Input parameters with descriptions
- Output parameters
- Usage examples
- Common troubleshooting

### Composite Action Documentation
Each action should include:
- Clear description
- Input/output specifications
- Usage examples
- Dependencies
- Limitations

### README Updates
- Update main README for new workflows
- Include usage examples
- Update troubleshooting section
- Add any new prerequisites

## 🔒 Security Guidelines

### Security Considerations
- Never hardcode secrets or sensitive data
- Use secure secret management
- Implement proper input validation
- Follow least privilege principle
- Regular security scanning

### Security Review
All security-related changes require:
- Security team review
- Penetration testing (for major changes)
- Compliance verification
- Documentation updates

## 🚀 Release Process

### Version Management
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Tag releases with version numbers
- Maintain changelog

### Release Steps
1. Update CHANGELOG.md
2. Update version references
3. Create release tag
4. Test with service repositories
5. Update service repository references

### Breaking Changes
- Document breaking changes
- Provide migration guide
- Maintain backwards compatibility when possible
- Communicate changes to teams

## 👥 Code Review Process

### Review Requirements
- All changes require at least one review
- DevOps team member must review
- Security team review for security changes
- Breaking changes require additional approval

### Review Checklist
- [ ] Code follows project conventions
- [ ] Tests pass and coverage is adequate
- [ ] Documentation is updated
- [ ] Security implications considered
- [ ] Backwards compatibility maintained
- [ ] Performance impact assessed

## 🐛 Issue Reporting

### Bug Reports
Include:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Relevant logs or screenshots

### Feature Requests
Include:
- Use case description
- Proposed solution
- Alternative approaches considered
- Impact on existing workflows

## 📞 Getting Help

### Support Channels
- **General Questions**: GitHub Discussions
- **Bug Reports**: GitHub Issues
- **Urgent Issues**: DevOps team Slack
- **Security Issues**: Security team (private channel)

### Response Times
- Bug reports: 24-48 hours
- Feature requests: 1 week
- Security issues: 4 hours
- General questions: 2-3 days

## 🏆 Recognition

Contributors are recognized through:
- GitHub contributor statistics
- Monthly team recognition
- Annual contributor awards
- Public acknowledgments in releases

Thank you for helping improve our shared workflows! 🎉
EOF

    print_success "Documentation created successfully"
}

create_github_settings() {
    print_step "Creating GitHub repository settings..."
    
    # Create .github directory for repository settings
    mkdir -p .github
    
    # Create pull request template
    cat > .github/pull_request_template.md << 'EOF'
## 📝 Description

Brief description of the changes and their purpose.

## 🔄 Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Refactoring (no functional changes)

## 🧪 Testing

- [ ] I have tested these changes locally
- [ ] I have tested with a Java Spring Boot service
- [ ] I have tested with a Node.js service
- [ ] I have tested across multiple environments (dev/staging)
- [ ] I have verified backwards compatibility

## 📋 Checklist

- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes

## 📚 Documentation

- [ ] README.md updated (if applicable)
- [ ] CHANGELOG.md updated
- [ ] Workflow documentation updated
- [ ] Usage examples provided

## 🔒 Security

- [ ] I have considered security implications of my changes
- [ ] No secrets or sensitive data are exposed
- [ ] Input validation is implemented where needed
- [ ] Security scanning passes

## 🔗 Related Issues

Fixes #(issue number)

## 📸 Screenshots (if applicable)

Add screenshots to help explain your changes.

## 🗂️ Additional Context

Add any other context about the pull request here.
EOF

    # Create issue templates
    mkdir -p .github/ISSUE_TEMPLATE
    
    # Bug report template
    cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: Bug Report
about: Create a report to help us improve
title: "[BUG] "
labels: bug
assignees: ''
---

## 🐛 Bug Description

A clear and concise description of what the bug is.

## 🔄 Workflow/Action Affected

- Workflow: (e.g., shared-deploy.yml)
- Action: (e.g., maven-build)
- Version/Branch: (e.g., main, v1.2.0)

## 📝 Steps to Reproduce

1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## ✅ Expected Behavior

A clear and concise description of what you expected to happen.

## ❌ Actual Behavior

A clear and concise description of what actually happened.

## 📱 Environment

- Service Type: (Java Spring Boot, Node.js, etc.)
- Repository: (link to service repository)
- Environment: (dev, staging, production)
- Runner: (GitHub-hosted, self-hosted)

## 📋 Logs

```
Paste relevant logs here
```

## 📸 Screenshots

If applicable, add screenshots to help explain your problem.

## 🔗 Additional Context

Add any other context about the problem here.

## 🚨 Impact

- [ ] Blocking deployment
- [ ] Degraded performance
- [ ] Security concern
- [ ] Documentation issue
- [ ] Minor inconvenience
EOF

    # Feature request template
    cat > .github/ISSUE_TEMPLATE/feature_request.md << 'EOF'
---
name: Feature Request
about: Suggest an idea for this project
title: "[FEATURE] "
labels: enhancement
assignees: ''
---

## 🚀 Feature Description

A clear and concise description of what you want to happen.

## 🎯 Problem Statement

A clear and concise description of what the problem is. Ex. I'm always frustrated when [...]

## 💡 Proposed Solution

A clear and concise description of what you want to happen.

## 🔄 Workflow/Action Impact

- Which workflows would be affected?
- Which actions would be affected?
- Is this a new workflow/action or modification of existing?

## 🧪 Use Cases

Describe the use cases this feature would enable:

1. Use case 1...
2. Use case 2...
3. Use case 3...

## 🔧 Implementation Ideas

If you have ideas for implementation, describe them here.

## 🔄 Alternatives Considered

A clear and concise description of any alternative solutions or features you've considered.

## 📊 Benefits

- Performance improvements
- Security enhancements
- Developer experience
- Operational efficiency
- Cost savings

## 🚨 Priority

- [ ] Critical (blocking current operations)
- [ ] High (significant improvement)
- [ ] Medium (nice to have)
- [ ] Low (future consideration)

## 🔗 Additional Context

Add any other context or screenshots about the feature request here.
EOF

    print_success "GitHub repository settings created"
}

commit_and_push() {
    print_step "Committing and pushing changes..."
    
    # Configure git if needed
    if ! git config user.email &> /dev/null; then
        git config user.email "shared-workflows@company.com"
        git config user.name "Shared Workflows Setup"
    fi
    
    # Add all files
    git add .
    
    # Create comprehensive commit message
    cat > commit_message.txt << EOF
feat: initialize shared workflows repository

🚀 Complete shared workflows and composite actions setup:

✅ Workflows Added:
- shared-deploy.yml: Multi-environment deployment for Java/Node.js
- shared-security-scan.yml: Comprehensive security scanning
- rollback-deployment.yml: Automated rollback procedures
- deploy-monitoring.yml: Monitoring stack deployment
- pr-security-check.yml: Pull request security validation

✅ Composite Actions:
- maven-build: Java/Maven build with caching
- docker-build-push: Multi-arch Docker builds
- helm-deploy: Kubernetes deployment with Helm
- sonar-scan: Code quality analysis
- checkmarx-scan: Security vulnerability scanning
- create-release: GitHub release automation
- version-strategy: Semantic versioning
- workspace-cleanup: Resource cleanup
- check-changes: Change detection

✅ Documentation:
- Comprehensive README with usage examples
- Contributing guidelines and standards
- Changelog for version tracking
- GitHub issue/PR templates
- Troubleshooting guides

✅ Features:
- Multi-environment support (dev/staging/prod)
- Azure Kubernetes Service integration
- Azure Container Registry support
- Security scanning integration
- Monitoring and observability
- Rollback capabilities
- Version management

Ready for microservice integration! 🎉

Migration Path:
1. Services reference shared workflows via: uses: org/shared-workflows/.github/workflows/shared-deploy.yml@main
2. All deployment patterns centralized and consistent
3. Security and compliance enforced across all services
4. Simplified maintenance and updates
EOF
    
    git commit -F commit_message.txt
    rm commit_message.txt
    
    # Push to repository
    git push origin main
    
    print_success "Changes committed and pushed successfully"
}

setup_repository_settings() {
    print_step "Configuring repository settings..."
    
    local full_repo_name="${ORG_NAME}/${SHARED_WORKFLOWS_REPO}"
    
    # Set up branch protection for main branch
    print_info "Setting up branch protection..."
    gh api repos/"$full_repo_name"/branches/main/protection \
        --method PUT \
        --field required_status_checks='{"strict":true,"contexts":[]}' \
        --field enforce_admins=true \
        --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":true}' \
        --field restrictions=null \
        --field allow_force_pushes=false \
        --field allow_deletions=false 2>/dev/null || print_warning "Could not set branch protection (may require admin privileges)"
    
    # Enable vulnerability alerts
    print_info "Enabling security features..."
    gh api repos/"$full_repo_name"/vulnerability-alerts \
        --method PUT 2>/dev/null || print_warning "Could not enable vulnerability alerts"
    
    # Enable automated security fixes
    gh api repos/"$full_repo_name"/automated-security-fixes \
        --method PUT 2>/dev/null || print_warning "Could not enable automated security fixes"
    
    print_success "Repository settings configured"
}

print_summary() {
    echo ""
    echo -e "${GREEN}🎉 Shared Workflows Repository Created Successfully!${NC}"
    echo ""
    echo -e "${BLUE}📦 Repository Details:${NC}"
    echo -e "   🔗 https://github.com/${ORG_NAME}/${SHARED_WORKFLOWS_REPO}"
    echo -e "   📚 Comprehensive documentation included"
    echo -e "   🔄 Ready for service integration"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo -e "   1. 🔐 Configure organization secrets (if not already done)"
    echo -e "   2. 👥 Set up team access permissions"
    echo -e "   3. 🚀 Start migrating services with: ./scripts/migrate-java-service.sh"
    echo -e "   4. 📊 Monitor workflow usage and performance"
    echo ""
    echo -e "${BLUE}🧪 Test the Setup:${NC}"
    echo -e "   # Reference shared workflows in service repositories:"
    echo -e "   uses: ${ORG_NAME}/${SHARED_WORKFLOWS_REPO}/.github/workflows/shared-deploy.yml@main"
    echo ""
    echo -e "${BLUE}📄 Documentation:${NC}"
    echo -e "   📖 README.md - Complete usage guide"
    echo -e "   📋 CONTRIBUTING.md - Contribution guidelines"
    echo -e "   📊 CHANGELOG.md - Version history"
    echo ""
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        usage
    fi
    
    print_header
    
    check_prerequisites
    create_repository
    clone_and_setup
    
    copy_workflows
    copy_composite_actions
    create_documentation
    create_github_settings
    
    commit_and_push
    setup_repository_settings
    
    print_summary
}

# Run main function with all arguments
main "$@"