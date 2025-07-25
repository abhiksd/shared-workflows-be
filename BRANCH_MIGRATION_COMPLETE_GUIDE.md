# Complete Branch Migration Guide

This guide walks you through migrating your monorepo to a branch-based architecture where shared workflows and application code are separated into different branches.

## 🎯 Final Repository Structure

```
Your Repository:
├── shared-github-actions (branch)     # 🔄 Centralized CI/CD workflows
│   ├── .github/workflows/             # Reusable workflows
│   ├── .github/actions/               # Composite actions
│   ├── README.md                      # Shared workflows documentation
│   └── CONTRIBUTING.md                # Contribution guidelines
│
├── my-java-app (branch)               # 🎁 Spring Boot application
│   ├── src/main/java/                 # Java source code
│   ├── src/main/resources/            # Spring Boot configurations
│   ├── helm/                          # Kubernetes charts
│   ├── .github/workflows/deploy.yml   # References shared workflows
│   ├── pom.xml                        # Maven configuration
│   ├── Dockerfile                     # Container definition
│   └── README.md                      # Service documentation
│
└── main (branch)                      # 🏠 Production releases
```

---

## 📋 Complete Step-by-Step Process

### Step 1: Setup and Preparation

```bash
# 1. Navigate to your repository
cd /path/to/your/repository

# 2. Ensure you have the migration scripts
# (Copy from the workspace or run from external location)
cp migrate-to-branches.sh .
cp verify-branch-migration.sh .
cp push-branch-changes.sh .

# 3. Make scripts executable
chmod +x migrate-to-branches.sh verify-branch-migration.sh push-branch-changes.sh

# 4. Check your current repository structure
ls -la apps/
git branch -a
git status
```

### Step 2: Run Migration

```bash
# Run migration for your Java service
./migrate-to-branches.sh java-backend1

# If you have a different service name:
# ./migrate-to-branches.sh your-service-name
```

**What this does:**
- ✅ Creates timestamped backup branch
- ✅ Cleans and sets up `shared-github-actions` branch
- ✅ Cleans and sets up `my-java-app` branch
- ✅ Migrates all workflows and composite actions to shared branch
- ✅ Migrates Spring Boot application to app branch
- ✅ Updates workflow references to use shared branch
- ✅ Creates comprehensive documentation for both branches

### Step 3: Verify Migration

```bash
# Verify that migration was successful
./verify-branch-migration.sh
```

This will check:
- ✅ Both branches exist and are properly structured
- ✅ Shared workflows branch has all GitHub Actions files
- ✅ App branch has Spring Boot application at root level
- ✅ Workflow references are correctly updated
- ✅ Documentation is properly generated

### Step 4: Push to Remote Repository

```bash
# Push both branches to remote repository
./push-branch-changes.sh

# Or force push if needed (use with caution)
# ./push-branch-changes.sh force
```

**What this does:**
- ✅ Checks remote repository access
- ✅ Pushes `shared-github-actions` branch
- ✅ Pushes `my-java-app` branch
- ✅ Sets up branch tracking
- ✅ Optionally creates pull requests
- ✅ Displays remote repository information

### Step 5: Review and Test

```bash
# 1. Review shared workflows branch
git checkout shared-github-actions
cat README.md
ls -la .github/

# 2. Review app branch
git checkout my-java-app
cat README.md
ls -la

# 3. Test the application build
mvn clean compile
mvn test

# 4. Test deployment workflow
gh workflow run deploy.yml -f environment=dev
```

---

## 🚀 Usage After Migration

### Working with Shared Workflows

```bash
# Switch to shared workflows branch
git checkout shared-github-actions

# Edit workflows or composite actions
nano .github/workflows/shared-deploy.yml

# Commit and push changes
git add .
git commit -m "feat: improve deployment workflow"
git push origin shared-github-actions

# All services automatically use updated workflows
```

### Working with Application Code

```bash
# Switch to app branch
git checkout my-java-app

# Edit Spring Boot application
nano src/main/java/com/example/Application.java

# Test locally
mvn spring-boot:run

# Commit and deploy
git add .
git commit -m "feat: add new feature"
git push origin my-java-app

# Workflow automatically triggers deployment
```

### Deployment Testing

```bash
# Manual deployment to different environments
git checkout my-java-app

# Deploy to development
gh workflow run deploy.yml -f environment=dev

# Deploy to staging
gh workflow run deploy.yml -f environment=staging

# Deploy to production
gh workflow run deploy.yml -f environment=production

# Monitor deployment
gh run list
gh run view <run-id>
```

---

## 🛠️ Configuration and Setup

### Repository Secrets

Configure these secrets in your repository settings:

```bash
# Using GitHub CLI
gh secret set AZURE_CLIENT_ID --body "your-client-id"
gh secret set AZURE_TENANT_ID --body "your-tenant-id"
gh secret set AZURE_SUBSCRIPTION_ID --body "your-subscription-id"
gh secret set ACR_LOGIN_SERVER --body "yourregistry.azurecr.io"
gh secret set KEYVAULT_NAME --body "your-keyvault-name"

# Or set them manually in GitHub web interface:
# Settings → Secrets and variables → Actions → New repository secret
```

### Branch Protection Rules

```bash
# Protect shared workflows branch
gh api repos/:owner/:repo/branches/shared-github-actions/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":[]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}'

# Protect app branch
gh api repos/:owner/:repo/branches/my-java-app/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":[]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}'
```

---

## 🔧 Advanced Configuration

### Spring Boot Profiles

The migration maintains all your existing profiles with environment isolation:

```yaml
# application.yml (base configuration)
spring:
  application:
    name: your-app-name
  profiles:
    active: local

# application-dev.yml (development)
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:5432/${DB_NAME:your_app_dev}

# application-staging.yml (staging)
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:5432/${DB_NAME:your_app_staging}

# application-production.yml (production)
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:5432/${DB_NAME:your_app_prod}
```

### Workflow Integration

The app deployment workflow references shared workflows:

```yaml
# .github/workflows/deploy.yml (in my-java-app branch)
jobs:
  deploy:
    uses: ./.github/workflows/shared-deploy.yml@shared-github-actions
    with:
      environment: ${{ github.event.inputs.environment || 'auto' }}
      application_name: your-app-name
      application_type: java-springboot
      build_context: .
      dockerfile_path: ./Dockerfile
      helm_chart_path: ./helm
```

### Docker Configuration

```dockerfile
# Dockerfile (in my-java-app branch)
FROM openjdk:21-jre-slim

# Application configuration
ENV APPLICATION_NAME="your-app-name"
ENV SPRING_PROFILES_ACTIVE="production"

# Copy application JAR
COPY target/*.jar app.jar

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

---

## 🚨 Troubleshooting

### Common Issues and Solutions

#### 1. **Push Rejected / Branch Conflicts**
```bash
# Force push (use with caution)
./push-branch-changes.sh force

# Or resolve conflicts manually
git checkout shared-github-actions
git pull origin shared-github-actions
# Resolve conflicts, then commit and push
```

#### 2. **Workflow Not Triggering**
```bash
# Check workflow file
git checkout my-java-app
cat .github/workflows/deploy.yml

# Verify branch reference
grep "shared-github-actions" .github/workflows/deploy.yml

# Check repository secrets
gh secret list
```

#### 3. **Authentication Issues**
```bash
# Check GitHub CLI authentication
gh auth status

# Re-authenticate if needed
gh auth login

# Check Git credentials
git config user.email
git config user.name
```

#### 4. **Maven Build Fails**
```bash
# Check Java version
java -version
mvn -version

# Clean build
mvn clean compile

# Check dependencies
mvn dependency:tree
```

#### 5. **Docker Build Issues**
```bash
# Check Docker daemon
docker info

# Build manually
docker build -t test-app .

# Check JAR file exists
ls -la target/*.jar
```

### Recovery Options

#### Restore from Backup
```bash
# List backup branches
git branch --list "migration-backup-*"

# Restore from backup (replace with actual backup branch name)
git checkout migration-backup-20241208-143022
git checkout -b recovery-branch

# Reset to backup state if needed
git reset --hard migration-backup-20241208-143022
```

#### Re-run Migration
```bash
# Delete problematic branches
git branch -D shared-github-actions my-java-app

# Re-run migration
./migrate-to-branches.sh java-backend1

# Verify and push again
./verify-branch-migration.sh
./push-branch-changes.sh
```

---

## 📊 Benefits Summary

✅ **Single Repository**: Everything stays in one repo for easy management  
✅ **Branch Separation**: Clean separation between workflows and application code  
✅ **Centralized CI/CD**: Shared workflows that are easy to maintain and update  
✅ **Independent Development**: Teams can work on their respective branches  
✅ **Version Control**: Both workflows and app code are properly versioned  
✅ **Easy Updates**: Update workflows once, all services benefit immediately  
✅ **Testing Integration**: Test workflow changes with actual application code  
✅ **Rollback Capability**: Easy to rollback either workflows or app code independently  
✅ **Team Collaboration**: Clear separation of responsibilities with pull request workflows  

---

## 🔗 Quick Reference Commands

```bash
# Branch switching
git checkout shared-github-actions  # Work on CI/CD workflows
git checkout my-java-app            # Work on application code
git checkout main                   # Production branch

# Deployment
gh workflow run deploy.yml -f environment=dev      # Deploy to dev
gh workflow run deploy.yml -f environment=staging  # Deploy to staging
gh workflow run deploy.yml -f environment=production # Deploy to prod

# Monitoring
gh run list                         # List workflow runs
gh run view <run-id>               # View specific run details
kubectl logs -f deployment/your-app # Check app logs

# Local development
mvn spring-boot:run                 # Run locally
mvn clean test                      # Run tests
docker build -t your-app .         # Build container
```

---

**🎉 Congratulations! Your repository now uses a clean branch-based architecture that separates shared workflows from application code while keeping everything in one repository for easy management.**

For support or questions, refer to the README files in each branch or the verification reports generated during migration.