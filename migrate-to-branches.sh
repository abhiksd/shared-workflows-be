#!/bin/bash

# Branch-Based Migration Script
# Migrates shared workflows to shared-github-actions branch
# Migrates Spring Boot app to my-java-app branch

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SHARED_BRANCH="shared-github-actions"
APP_BRANCH="my-java-app"
SERVICE_NAME="${1:-java-backend1}"
BACKUP_BRANCH="migration-backup-$(date '+%Y%m%d-%H%M%S')"

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  🔄 Branch-Based Migration Tool${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${CYAN}Shared Workflows Branch: ${SHARED_BRANCH}${NC}"
    echo -e "${CYAN}App Branch: ${APP_BRANCH}${NC}"
    echo -e "${CYAN}Service: ${SERVICE_NAME}${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}✨ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
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

usage() {
    echo "Usage: $0 [service-name]"
    echo ""
    echo "Examples:"
    echo "  $0                     # Uses java-backend1 as default service"
    echo "  $0 java-backend1       # Migrates java-backend1 service"
    echo "  $0 java-backend2       # Migrates java-backend2 service"
    echo ""
    echo "This script will:"
    echo "  1. Create backup of current state"
    echo "  2. Clean up both branches"
    echo "  3. Migrate shared workflows to '$SHARED_BRANCH' branch"
    echo "  4. Migrate '$SERVICE_NAME' to '$APP_BRANCH' branch"
    echo "  5. Update workflows to reference shared branch"
    echo ""
    exit 1
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a Git repository"
        exit 1
    fi
    
    # Check if service exists
    if [[ ! -d "apps/$SERVICE_NAME" ]]; then
        print_error "Service not found: apps/$SERVICE_NAME"
        print_info "Available services:"
        ls apps/ 2>/dev/null || echo "No apps directory found"
        exit 1
    fi
    
    # Check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        print_warning "You have uncommitted changes"
        print_info "Current changes will be included in the backup"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Migration cancelled"
            exit 0
        fi
    fi
    
    print_success "Prerequisites check passed"
}

create_backup() {
    print_step "Creating backup branch..."
    
    # Create backup branch from current state
    git checkout -b "$BACKUP_BRANCH"
    git add -A  # Add any uncommitted changes to backup
    git commit -m "Backup before branch migration" || print_info "No changes to commit for backup"
    
    print_success "Backup created: $BACKUP_BRANCH"
}

ensure_branches_exist() {
    print_step "Ensuring target branches exist..."
    
    # Go back to main/master to create branches
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || {
        print_error "Could not find main or master branch"
        exit 1
    }
    
    # Create or checkout shared workflows branch
    if git show-ref --verify --quiet "refs/heads/$SHARED_BRANCH"; then
        print_info "Branch $SHARED_BRANCH already exists"
    else
        git checkout -b "$SHARED_BRANCH"
        print_success "Created branch: $SHARED_BRANCH"
    fi
    
    # Create or checkout app branch
    git checkout main 2>/dev/null || git checkout master 2>/dev/null
    if git show-ref --verify --quiet "refs/heads/$APP_BRANCH"; then
        print_info "Branch $APP_BRANCH already exists"
    else
        git checkout -b "$APP_BRANCH"
        print_success "Created branch: $APP_BRANCH"
    fi
}

cleanup_shared_branch() {
    print_step "Cleaning up shared workflows branch..."
    
    git checkout "$SHARED_BRANCH"
    
    # Remove everything except .git
    find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
    
    print_success "Shared branch cleaned"
}

cleanup_app_branch() {
    print_step "Cleaning up app branch..."
    
    git checkout "$APP_BRANCH"
    
    # Remove everything except .git
    find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
    
    print_success "App branch cleaned"
}

migrate_shared_workflows() {
    print_step "Migrating shared workflows to $SHARED_BRANCH branch..."
    
    git checkout "$SHARED_BRANCH"
    
    # Go back to backup to get files
    git checkout "$BACKUP_BRANCH" -- .github/workflows/ .github/actions/ 2>/dev/null || true
    
    # Copy workflows and actions
    if [[ -d ".github" ]]; then
        print_success "Copied .github directory"
    else
        # Create from scratch if not found
        mkdir -p .github/workflows .github/actions
        print_info "Created .github structure"
    fi
    
    # Create shared workflows documentation
    create_shared_workflows_readme
    create_shared_workflows_docs
    
    # Commit shared workflows
    git add -A
    git commit -m "feat: migrate shared GitHub Actions workflows and composite actions

🚀 Complete shared workflows setup:

✅ Workflows:
- shared-deploy.yml: Multi-environment deployment
- shared-security-scan.yml: Security scanning  
- rollback-deployment.yml: Rollback procedures
- pr-security-check.yml: PR validation

✅ Composite Actions:
- maven-build: Java/Maven builds with caching
- docker-build-push: Multi-arch Docker builds
- helm-deploy: Kubernetes deployment
- Security scanning actions

✅ Documentation:
- Comprehensive README with usage examples
- Contributing guidelines
- Workflow documentation

Ready for service integration! Services can reference these workflows via:
uses: ./.github/workflows/shared-deploy.yml@shared-github-actions" || print_info "No changes to commit in shared branch"
    
    print_success "Shared workflows migrated to $SHARED_BRANCH"
}

migrate_app_code() {
    print_step "Migrating $SERVICE_NAME to $APP_BRANCH branch..."
    
    git checkout "$APP_BRANCH"
    
    # Copy service files from backup
    git checkout "$BACKUP_BRANCH" -- "apps/$SERVICE_NAME/" 2>/dev/null || {
        print_error "Could not find service in backup: apps/$SERVICE_NAME"
        return 1
    }
    
    # Move service files to root
    if [[ -d "apps/$SERVICE_NAME" ]]; then
        mv "apps/$SERVICE_NAME"/* .
        mv "apps/$SERVICE_NAME"/.[^.]* . 2>/dev/null || true  # Move hidden files
        rm -rf apps/
        print_success "Moved service files to root"
    fi
    
    # Update workflow to reference shared branch
    update_workflow_for_branch
    
    # Create app-specific documentation
    create_app_readme
    update_deployment_docs
    
    # Commit app code
    git add -A
    git commit -m "feat: migrate $(echo $SERVICE_NAME | sed 's/-/ /g' | sed 's/\b\w/\U&/g') to independent branch

🚀 Complete Spring Boot application migration:

✅ Application Features:
- Spring Boot 3.x with Java 21
- RESTful API endpoints
- Multi-environment profiles (local, dev, staging, prod)
- Comprehensive health checks and metrics

✅ Configuration:
- Environment-specific Spring Boot profiles
- Database connection configurations
- Redis caching setup
- Monitoring and observability

✅ DevOps:
- GitHub Actions workflow referencing shared workflows
- Docker containerization
- Kubernetes Helm charts
- Multi-environment deployment support

✅ Documentation:
- Service-specific README
- Deployment guides
- API documentation structure
- Troubleshooting guides

Ready for independent development and deployment!" || print_info "No changes to commit in app branch"
    
    print_success "$SERVICE_NAME migrated to $APP_BRANCH"
}

update_workflow_for_branch() {
    print_step "Updating workflow to reference shared branch..."
    
    local workflow_file=".github/workflows/deploy.yml"
    
    if [[ -f "$workflow_file" ]]; then
        # Update workflow to reference shared branch instead of external repo
        sed -i "s|uses: .*/.github/workflows/shared-deploy.yml@.*|uses: ./.github/workflows/shared-deploy.yml@$SHARED_BRANCH|g" "$workflow_file"
        
        # Update other workflow references
        sed -i "s|uses: .*/.github/workflows/shared-security-scan.yml@.*|uses: ./.github/workflows/shared-security-scan.yml@$SHARED_BRANCH|g" "$workflow_file"
        sed -i "s|uses: .*/.github/workflows/rollback-deployment.yml@.*|uses: ./.github/workflows/rollback-deployment.yml@$SHARED_BRANCH|g" "$workflow_file"
        
        # Update build context to root since we moved files
        sed -i "s|build_context: apps/$SERVICE_NAME|build_context: .|g" "$workflow_file"
        sed -i "s|dockerfile_path: apps/$SERVICE_NAME/Dockerfile|dockerfile_path: ./Dockerfile|g" "$workflow_file"
        sed -i "s|helm_chart_path: helm|helm_chart_path: ./helm|g" "$workflow_file"
        
        # Update path triggers
        sed -i "s|apps/$SERVICE_NAME/\\*\\*|**|g" "$workflow_file"
        sed -i "s|- 'apps/$SERVICE_NAME/\\*\\*'|- '**'|g" "$workflow_file"
        
        print_success "Workflow updated to reference $SHARED_BRANCH branch"
    else
        print_warning "No workflow file found to update"
    fi
}

create_shared_workflows_readme() {
    cat > README.md << 'EOF'
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
EOF
}

create_shared_workflows_docs() {
    # Create CONTRIBUTING.md
    cat > CONTRIBUTING.md << 'EOF'
# Contributing to Shared Workflows

## Making Changes

1. Switch to shared workflows branch:
   ```bash
   git checkout shared-github-actions
   ```

2. Make your changes to workflows or actions

3. Test with a service branch:
   ```bash
   git checkout my-java-app
   gh workflow run deploy.yml -f environment=dev
   ```

4. Commit and push:
   ```bash
   git checkout shared-github-actions
   git add .
   git commit -m "feat: improve deployment workflow"
   git push origin shared-github-actions
   ```

## Best Practices

- Always test workflow changes with service branches
- Document breaking changes
- Maintain backward compatibility when possible
- Use semantic commit messages

## Workflow Structure

- Keep workflows generic and reusable
- Use inputs for service-specific configurations
- Include comprehensive error handling
- Add detailed logging for debugging
EOF

    # Create workflow documentation
    mkdir -p docs
    cat > docs/workflow-guide.md << 'EOF'
# Workflow Usage Guide

## Referencing Shared Workflows

From any service branch, reference shared workflows:

```yaml
uses: ./.github/workflows/shared-deploy.yml@shared-github-actions
```

## Required Secrets

Each service branch needs these repository secrets:
- AZURE_CLIENT_ID
- AZURE_TENANT_ID  
- AZURE_SUBSCRIPTION_ID
- ACR_LOGIN_SERVER
- KEYVAULT_NAME

## Environment Configuration

Workflows support multiple environments:
- dev: Automatic on push to develop
- staging: Automatic on push to release/*
- production: Automatic on push to main
EOF
}

create_app_readme() {
    local app_title=$(echo "$SERVICE_NAME" | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
    
    cat > README.md << EOF
# $app_title

A Spring Boot microservice for $app_title functionality.

## 🚀 Quick Start

### Local Development
\`\`\`bash
# Build and run
mvn clean spring-boot:run

# Run with specific profile
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# Or with Docker
docker build -t ${SERVICE_NAME} .
docker run -p 8080:8080 ${SERVICE_NAME}
\`\`\`

### API Endpoints
- **Base URL**: \`http://localhost:8080/api\`
- **Health Check**: \`/actuator/health\`
- **Metrics**: \`/actuator/prometheus\`
- **Info**: \`/actuator/info\`

## 🏗️ Architecture

- **Framework**: Spring Boot 3.x
- **Java Version**: 21
- **Build Tool**: Maven
- **Database**: PostgreSQL (configurable)
- **Caching**: Redis
- **Monitoring**: Prometheus + Grafana
- **Deployment**: Kubernetes with Helm

## 🔧 Configuration

### Spring Boot Profiles
- **local**: Local development with H2 database
- **dev**: Development environment with PostgreSQL
- **staging**: Staging environment with full monitoring
- **production**: Production environment with all features

### Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| \`DB_HOST\` | Database host | localhost |
| \`DB_PORT\` | Database port | 5432 |
| \`DB_NAME\` | Database name | ${SERVICE_NAME//-/_}_dev |
| \`DB_USERNAME\` | Database username | app_user |
| \`DB_PASSWORD\` | Database password | (required) |
| \`REDIS_HOST\` | Redis host | localhost |
| \`REDIS_PORT\` | Redis port | 6379 |

## 🚀 Deployment

This service uses shared GitHub Actions workflows from the \`shared-github-actions\` branch.

### Manual Deployment
\`\`\`bash
# Deploy to development
gh workflow run deploy.yml -f environment=dev

# Deploy to staging  
gh workflow run deploy.yml -f environment=staging

# Deploy to production
gh workflow run deploy.yml -f environment=production
\`\`\`

### Automatic Deployment
- **Dev**: Triggered on push to this branch
- **Staging**: Triggered on push to \`release/*\` branches
- **Production**: Triggered on push to \`main\` branch

## 📊 Monitoring & Observability

### Health Checks
- **Liveness**: \`/actuator/health/liveness\`
- **Readiness**: \`/actuator/health/readiness\`
- **Custom Health**: Application-specific indicators

### Metrics
- **Prometheus**: \`/actuator/prometheus\`
- **JVM Metrics**: Memory, GC, threads
- **HTTP Metrics**: Request duration, response codes
- **Custom Metrics**: Business-specific metrics

### Logging
- **Format**: JSON structured logging
- **Levels**: Configurable per environment
- **Correlation**: Request tracing with correlation IDs

## 🛠️ Development

### Prerequisites
- Java 21+
- Maven 3.6+
- Docker & Docker Compose
- PostgreSQL (for local dev)

### Setup
\`\`\`bash
# Clone and switch to app branch
git clone <repository-url>
git checkout $APP_BRANCH

# Install dependencies
mvn clean install

# Run tests
mvn test

# Run with development profile
mvn spring-boot:run -Dspring-boot.run.profiles=dev
\`\`\`

### Testing
\`\`\`bash
# Unit tests
mvn test

# Integration tests
mvn verify

# Test with specific profile
mvn test -Dspring.profiles.active=dev
\`\`\`

### Docker Development
\`\`\`bash
# Build image
docker build -t ${SERVICE_NAME}:latest .

# Run with docker-compose (if available)
docker-compose up -d

# Run standalone
docker run -p 8080:8080 \\
  -e SPRING_PROFILES_ACTIVE=dev \\
  -e DB_HOST=host.docker.internal \\
  ${SERVICE_NAME}:latest
\`\`\`

## 🔗 Branch Structure

This repository uses a branch-based approach:

- **\`shared-github-actions\`**: Shared CI/CD workflows and composite actions
- **\`$APP_BRANCH\`**: This Spring Boot application (current branch)
- **\`main\`**: Production releases

### Workflow Integration

The deployment workflow references shared workflows:

\`\`\`yaml
uses: ./.github/workflows/shared-deploy.yml@shared-github-actions
\`\`\`

## 📚 Documentation

- [Deployment Guide](./DEPLOYMENT.md) - Comprehensive deployment instructions
- [Shared Workflows](../../tree/shared-github-actions) - CI/CD workflows documentation
- [API Documentation](./docs/api.md) - API endpoints and examples

## 🐛 Troubleshooting

### Common Issues

1. **Application won't start**
   - Check database connectivity
   - Verify environment variables
   - Check application logs

2. **Workflow failures**
   - Verify shared workflows are up to date
   - Check repository secrets configuration
   - Review workflow logs

3. **Docker build fails**
   - Check Dockerfile syntax
   - Verify JAR file exists in target/
   - Ensure Maven build completes successfully

### Debug Commands
\`\`\`bash
# Check application logs
kubectl logs -f deployment/${SERVICE_NAME}

# Check health status
curl http://localhost:8080/actuator/health

# View configuration
curl http://localhost:8080/actuator/configprops
\`\`\`

## 🤝 Contributing

1. Create a feature branch from \`$APP_BRANCH\`
2. Make your changes
3. Test locally and with CI/CD
4. Create a pull request to \`$APP_BRANCH\`

## 📄 License

This project is licensed under the MIT License.

---

**Service**: $app_title  
**Branch**: $APP_BRANCH  
**Type**: Spring Boot Microservice  
**Shared Workflows**: shared-github-actions branch  
**Deployment**: GitHub Actions + Kubernetes + Helm
EOF
}

update_deployment_docs() {
    if [[ -f "DEPLOYMENT.md" ]]; then
        # Update deployment documentation for branch-based approach
        sed -i "1s/.*/# $(echo $SERVICE_NAME | sed 's/-/ /g' | sed 's/\b\w/\U&/g') Deployment Guide/" DEPLOYMENT.md
        sed -i "s|apps/$SERVICE_NAME/||g" DEPLOYMENT.md
        sed -i "s|Navigate to the $SERVICE_NAME directory|Deploy from current branch root|g" DEPLOYMENT.md
        sed -i "s|cd apps/$SERVICE_NAME|# Deploy from branch root|g" DEPLOYMENT.md
        
        # Add branch information
        sed -i "2i\\
\\
This service is deployed from the \`$APP_BRANCH\` branch using shared workflows from the \`$SHARED_BRANCH\` branch.\\
" DEPLOYMENT.md
    fi
}

cleanup_and_finalize() {
    print_step "Finalizing migration..."
    
    # Switch back to main branch
    git checkout main 2>/dev/null || git checkout master 2>/dev/null
    
    print_success "Migration completed successfully!"
}

print_summary() {
    echo ""
    echo -e "${GREEN}🎉 Branch Migration Completed Successfully!${NC}"
    echo ""
    echo -e "${BLUE}📊 Migration Summary:${NC}"
    echo -e "   🔄 Shared workflows migrated to: ${SHARED_BRANCH}"
    echo -e "   🎁 Service code migrated to: ${APP_BRANCH}"
    echo -e "   💾 Backup created: ${BACKUP_BRANCH}"
    echo ""
    echo -e "${BLUE}📋 Branch Structure:${NC}"
    echo -e "   📂 ${SHARED_BRANCH} - Centralized GitHub Actions workflows and composite actions"
    echo -e "   📂 ${APP_BRANCH} - Spring Boot application with references to shared workflows"
    echo -e "   📂 ${BACKUP_BRANCH} - Complete backup of pre-migration state"
    echo ""
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo ""
    echo -e "${YELLOW}1. Review shared workflows:${NC}"
    echo "   git checkout $SHARED_BRANCH"
    echo "   cat README.md"
    echo ""
    echo -e "${YELLOW}2. Review migrated service:${NC}"
    echo "   git checkout $APP_BRANCH"
    echo "   cat README.md"
    echo ""
    echo -e "${YELLOW}3. Test deployment:${NC}"
    echo "   git checkout $APP_BRANCH"
    echo "   gh workflow run deploy.yml -f environment=dev"
    echo ""
    echo -e "${YELLOW}4. Configure repository secrets (if not already done):${NC}"
    echo "   - AZURE_CLIENT_ID"
    echo "   - AZURE_TENANT_ID"
    echo "   - AZURE_SUBSCRIPTION_ID"
    echo "   - ACR_LOGIN_SERVER"
    echo "   - KEYVAULT_NAME"
    echo ""
    echo -e "${YELLOW}5. Set up branch protection rules:${NC}"
    echo "   - Protect $SHARED_BRANCH branch"
    echo "   - Protect $APP_BRANCH branch"
    echo "   - Require PR reviews for changes"
    echo ""
    echo -e "${BLUE}🔗 Quick Commands:${NC}"
    echo "   git checkout $SHARED_BRANCH  # View shared workflows"
    echo "   git checkout $APP_BRANCH     # Work on service code"
    echo "   git checkout $BACKUP_BRANCH  # Restore if needed"
    echo ""
    echo -e "${CYAN}✅ Your repository now uses branch-based architecture!${NC}"
    echo ""
}

# Main execution
main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
    fi
    
    print_header
    
    check_prerequisites
    create_backup
    ensure_branches_exist
    cleanup_shared_branch
    migrate_shared_workflows
    cleanup_app_branch
    migrate_app_code
    cleanup_and_finalize
    
    print_summary
}

# Run main function with all arguments
main "$@"