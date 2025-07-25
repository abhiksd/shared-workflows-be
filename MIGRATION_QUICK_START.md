# Backend Migration Quick Start Guide

**🚀 Migrate your Spring Boot services from monorepo to independent repositories in minutes!**

## 📋 TL;DR

```bash
# 1. Check prerequisites
./scripts/check-migration-prerequisites.sh

# 2. Create shared workflows repository
./scripts/create-shared-workflows-repo.sh mycompany shared-workflows

# 3. Migrate your Java service
./scripts/migrate-java-service.sh java-backend1 mycompany/java-backend1-user-management

# 4. Verify migration
./scripts/verify-migration.sh mycompany/java-backend1-user-management

# 5. Test deployment
gh workflow run deploy.yml -R mycompany/java-backend1-user-management -f environment=dev
```

## 🎯 What You Get

After migration, each service will have:

✅ **Independent Repository** with complete codebase  
✅ **GitHub Actions CI/CD** with shared workflows  
✅ **Spring Boot Profiles** for all environments  
✅ **Helm Charts** for Kubernetes deployment  
✅ **Docker Support** with multi-arch builds  
✅ **Security Scanning** and compliance  
✅ **Comprehensive Documentation** and troubleshooting  

## 📚 Migration Steps

### Step 1: Prerequisites Check (2 minutes)

```bash
./scripts/check-migration-prerequisites.sh
```

**What it checks:**
- GitHub CLI authentication
- Required tools (Git, Docker, Maven, Helm)
- Workspace structure
- Service health

**If issues found:** Follow the installation guides in the output.

### Step 2: Create Shared Workflows (5 minutes)

```bash
./scripts/create-shared-workflows-repo.sh mycompany shared-workflows
```

**What it creates:**
- Centralized workflows repository
- Reusable deployment workflows
- Composite actions for builds
- Comprehensive documentation

**Output:** `https://github.com/mycompany/shared-workflows`

### Step 3: Migrate Java Service (3 minutes)

```bash
./scripts/migrate-java-service.sh java-backend1 mycompany/java-backend1-user-management
```

**What it does:**
- Creates new independent repository
- Copies all source code and configurations
- Updates workflow references to shared workflows
- Migrates Spring Boot profiles for environment isolation
- Updates Helm charts and documentation
- Creates comprehensive README

**Output:** `https://github.com/mycompany/java-backend1-user-management`

### Step 4: Verify Migration (2 minutes)

```bash
./scripts/verify-migration.sh mycompany/java-backend1-user-management
```

**What it validates:**
- Repository structure and files
- Workflow configurations
- Maven project setup
- Spring Boot configurations
- Docker and Helm setups
- Documentation completeness

**Output:** Detailed verification report with any issues found.

### Step 5: Test Deployment (5 minutes)

```bash
# Deploy to development environment
gh workflow run deploy.yml -R mycompany/java-backend1-user-management -f environment=dev

# Monitor deployment
kubectl get pods -l app=java-backend1-user-management

# Check service health
curl https://dev-java-backend1-user-management.example.com/api/actuator/health
```

## 🔧 Service Configuration

Each migrated service includes these Spring Boot profiles:

### 📁 `application.yml` (Base Configuration)
- Default settings
- Actuator endpoints
- Basic logging configuration

### 📁 `application-dev.yml` (Development)
- PostgreSQL database connection
- Debug logging enabled
- Development-specific settings

### 📁 `application-staging.yml` (Staging)
- Production-like settings
- Performance monitoring
- Staging database configuration

### 📁 `application-production.yml` (Production)
- Production optimizations
- Security hardening
- Production database and caching

## 🚀 Deployment Environments

After migration, your service supports automatic deployment to:

| Environment | Trigger | Database | Monitoring |
|-------------|---------|----------|------------|
| **Development** | Push to `develop` | Dev DB | Basic |
| **Staging** | Push to `release/*` | Staging DB | Full |
| **Production** | Push to `main` | Prod DB | Complete |

## 📊 Repository Secrets Setup

Configure these secrets in each service repository:

```bash
# Azure Authentication
AZURE_CLIENT_ID          # Service Principal Client ID
AZURE_TENANT_ID           # Azure Tenant ID  
AZURE_SUBSCRIPTION_ID     # Azure Subscription ID

# Container Registry
ACR_LOGIN_SERVER          # Azure Container Registry URL

# Key Vault
KEYVAULT_NAME            # Azure Key Vault name
```

## 🛠️ Troubleshooting

### Common Issues

#### ❌ "Workflow not found"
**Solution:** Check workflow reference in `.github/workflows/deploy.yml`:
```yaml
uses: mycompany/shared-workflows/.github/workflows/shared-deploy.yml@main
```

#### ❌ "Maven build failed"
**Solution:** Verify Maven project:
```bash
mvn validate
mvn clean compile
```

#### ❌ "Docker build failed"
**Solution:** Check JAR file exists:
```bash
mvn clean package
ls -la target/*.jar
```

#### ❌ "Helm deployment failed"
**Solution:** Validate Helm chart:
```bash
helm lint ./helm
helm template ./helm
```

## 📞 Support

- **Migration Issues**: Check `logs/` directory for detailed logs
- **Workflow Problems**: See [Comprehensive Guide](./BACKEND_MIGRATION_COMPREHENSIVE_GUIDE.md)
- **Emergency**: Use rollback scripts in `scripts/` directory

## 🔄 Next Services

Repeat steps 3-5 for each additional service:

```bash
# Java services
./scripts/migrate-java-service.sh java-backend2 mycompany/java-backend2-product-catalog
./scripts/migrate-java-service.sh java-backend3 mycompany/java-backend3-order-management

# Node.js services (if available)
./scripts/migrate-nodejs-service.sh nodejs-backend1 mycompany/nodejs-backend1-notification
```

## 📈 Benefits Achieved

After migration:

✅ **Independent Development** - Teams can work autonomously  
✅ **Faster CI/CD** - Only changed services deploy  
✅ **Better Security** - Isolated secrets and permissions  
✅ **Easier Scaling** - Scale services independently  
✅ **Improved Reliability** - Failures isolated to single services  
✅ **Better Monitoring** - Service-specific metrics and alerting  

## 📚 Advanced Topics

For advanced configuration and customization, see:

- [Comprehensive Migration Guide](./BACKEND_MIGRATION_COMPREHENSIVE_GUIDE.md)
- [Spring Boot Best Practices](./docs/spring-boot-best-practices.md)
- [Kubernetes Deployment Guide](./docs/kubernetes-deployment.md)
- [Monitoring Setup](./docs/monitoring-setup.md)

---

**Total Migration Time: ~15 minutes per service**  
**Maintenance Effort: Significantly reduced**  
**Developer Experience: Greatly improved**

🎉 **Start your migration journey today!**