# Shared GitHub Actions Workflows

This branch contains centralized, reusable GitHub Actions workflows and composite actions for all services in this repository.

## 🎯 Purpose

- **Centralized CI/CD**: Consistent deployment patterns across all services
- **Maintenance Efficiency**: Update workflows in one place, benefit everywhere  
- **Security Standards**: Enforce security scanning and compliance
- **Best Practices**: Ensure all services follow the same patterns

## 📁 Structure

```
.github/
├── workflows/           # Reusable workflows
│   ├── shared-deploy.yml           # Main deployment workflow
│   ├── shared-security-scan.yml    # Security scanning
│   ├── rollback-deployment.yml     # Rollback procedures
│   └── pr-security-check.yml       # PR security validation
└── actions/             # Composite actions
    ├── maven-build/               # Java/Maven build
    ├── docker-build-push/         # Docker build and push
    ├── helm-deploy/               # Helm deployment
    └── sonar-scan/                # Code quality analysis
```

## 🚀 Usage in Service Branches

Services reference these workflows from their own branches:

```yaml
# In service branch .github/workflows/deploy.yml
jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml@shared-github-actions
    with:
      environment: dev
      application_name: my-service
      application_type: java-springboot
      build_context: .
      dockerfile_path: ./Dockerfile
      helm_chart_path: ./helm
```

## 📋 Available Workflows

### shared-deploy.yml
Complete CI/CD pipeline for Java Spring Boot applications:
- Multi-environment deployment (dev, staging, production)
- Maven build with caching
- Docker build and push
- Helm deployment to Kubernetes
- Security scanning integration

### shared-security-scan.yml  
Comprehensive security scanning:
- Dependency vulnerability scanning
- Static code analysis
- Container security scanning
- License compliance checking

### rollback-deployment.yml
Automated rollback procedures:
- Helm-based rollbacks
- Database migration rollbacks
- Notification integration

## 🧩 Composite Actions

### maven-build
```yaml
- uses: ./.github/actions/maven-build@shared-github-actions
  with:
    application_name: my-service
    java_version: '21'
    run_tests: 'true'
```

### docker-build-push
```yaml
- uses: ./.github/actions/docker-build-push@shared-github-actions
  with:
    application_name: my-service
    application_type: java-springboot
    image_tag: ${{ github.sha }}
```

## 🔄 Updating Shared Workflows

1. Switch to this branch: `git checkout shared-github-actions`
2. Make your changes to workflows or actions
3. Test with a service branch
4. Commit and push changes
5. Service branches automatically use updated workflows

## 📚 Documentation

- Each workflow includes detailed inline documentation
- Composite actions have their own README files
- See service branches for usage examples

---

**Branch**: shared-github-actions  
**Purpose**: Centralized CI/CD workflows and actions  
**Usage**: Referenced by service branches for consistent deployments
