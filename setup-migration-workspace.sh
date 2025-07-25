#!/bin/bash

# Migration Workspace Setup Script
# Creates a separate workspace for migration tools and processes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_DIR="${1:-migration-workspace}"
SOURCE_DIR="$(pwd)"

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  🛠️ Migration Workspace Setup${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${CYAN}Creating workspace: ${WORKSPACE_DIR}${NC}"
    echo -e "${CYAN}Source directory: ${SOURCE_DIR}${NC}"
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

usage() {
    echo "Usage: $0 [workspace-directory]"
    echo ""
    echo "Examples:"
    echo "  $0                          # Creates 'migration-workspace' directory"
    echo "  $0 my-migration-tools       # Creates 'my-migration-tools' directory"
    echo ""
    echo "This script creates a separate workspace with all migration tools"
    exit 1
}

create_workspace() {
    print_step "Creating migration workspace..."
    
    if [[ -d "$WORKSPACE_DIR" ]]; then
        print_info "Workspace directory already exists: $WORKSPACE_DIR"
        read -p "Do you want to continue and update it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Setup cancelled by user"
            exit 0
        fi
    fi
    
    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"
    
    print_success "Workspace directory created: $(pwd)"
}

copy_migration_files() {
    print_step "Copying migration tools..."
    
    # Copy migration scripts
    mkdir -p scripts
    cp "$SOURCE_DIR/scripts"/*.sh scripts/ 2>/dev/null || true
    chmod +x scripts/*.sh 2>/dev/null || true
    
    # Copy documentation
    cp "$SOURCE_DIR"/*.md . 2>/dev/null || true
    
    # Create logs directory
    mkdir -p logs
    cat > logs/.gitignore << 'EOF'
# Migration logs
*.log
*.md
*.txt

# Keep directory but ignore contents
*
!.gitignore
EOF
    
    print_success "Migration tools copied"
}

create_migration_config() {
    print_step "Creating migration configuration..."
    
    cat > migration-config.sh << 'EOF'
#!/bin/bash

# Migration Configuration
# Edit these variables for your specific setup

# GitHub Organization
export ORG_NAME="your-github-org"

# Shared Workflows Repository
export SHARED_WORKFLOWS_REPO="shared-workflows"

# Services to migrate (format: "directory-name:new-repo-name:service-type")
export SERVICES_TO_MIGRATE=(
    "java-backend1:java-backend1-user-management:java-springboot"
    "java-backend2:java-backend2-product-catalog:java-springboot"
    "java-backend3:java-backend3-order-management:java-springboot"
    "nodejs-backend1:nodejs-backend1-notification:nodejs"
    "nodejs-backend2:nodejs-backend2-analytics:nodejs"
    "nodejs-backend3:nodejs-backend3-file-management:nodejs"
)

# Source monorepo path (where your current apps are located)
export SOURCE_MONOREPO_PATH="../your-monorepo-path"

echo "Migration Configuration:"
echo "========================"
echo "Organization: $ORG_NAME"
echo "Shared Workflows Repo: $SHARED_WORKFLOWS_REPO"
echo "Source Monorepo: $SOURCE_MONOREPO_PATH"
echo "Services to migrate: ${#SERVICES_TO_MIGRATE[@]}"
echo ""
echo "Edit this file to match your setup:"
echo "nano migration-config.sh"
EOF
    
    chmod +x migration-config.sh
    print_success "Created: migration-config.sh"
}

create_master_migration_script() {
    print_step "Creating master migration script..."
    
    cat > run-complete-migration.sh << 'EOF'
#!/bin/bash

# Complete Migration Script
# Runs the entire migration process step by step

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load configuration
source ./migration-config.sh

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  🚀 Complete Migration Process${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${CYAN}Organization: $ORG_NAME${NC}"
    echo -e "${CYAN}Shared Workflows: $SHARED_WORKFLOWS_REPO${NC}"
    echo -e "${CYAN}Source: $SOURCE_MONOREPO_PATH${NC}"
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

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

run_prerequisites_check() {
    print_step "Step 1: Checking Prerequisites"
    
    if ./scripts/check-migration-prerequisites.sh; then
        print_success "Prerequisites check passed"
    else
        print_error "Prerequisites check failed"
        echo "Please fix the issues above before continuing"
        exit 1
    fi
    echo ""
}

create_shared_workflows() {
    print_step "Step 2: Creating Shared Workflows Repository"
    
    if ./scripts/create-shared-workflows-repo.sh "$ORG_NAME" "$SHARED_WORKFLOWS_REPO"; then
        print_success "Shared workflows repository created: https://github.com/$ORG_NAME/$SHARED_WORKFLOWS_REPO"
    else
        print_error "Failed to create shared workflows repository"
        exit 1
    fi
    echo ""
}

migrate_services() {
    print_step "Step 3: Migrating Services"
    
    local migration_results=()
    
    for service_config in "${SERVICES_TO_MIGRATE[@]}"; do
        IFS=':' read -r service_dir repo_name service_type <<< "$service_config"
        
        print_info "Migrating $service_dir -> $ORG_NAME/$repo_name"
        
        if [[ "$service_type" == "java-springboot" ]]; then
            if ./scripts/migrate-java-service.sh "$service_dir" "$ORG_NAME/$repo_name" "$SHARED_WORKFLOWS_REPO"; then
                print_success "✅ $service_dir migrated successfully"
                migration_results+=("SUCCESS: $service_dir -> $ORG_NAME/$repo_name")
            else
                print_error "❌ Failed to migrate $service_dir"
                migration_results+=("FAILED: $service_dir")
            fi
        elif [[ "$service_type" == "nodejs" ]]; then
            # Placeholder for Node.js migration (you can implement this later)
            print_info "Node.js migration not implemented yet: $service_dir"
            migration_results+=("SKIPPED: $service_dir (Node.js)")
        fi
        
        echo ""
    done
    
    # Print migration summary
    echo -e "${BLUE}Migration Summary:${NC}"
    for result in "${migration_results[@]}"; do
        if [[ "$result" =~ ^SUCCESS ]]; then
            echo -e "${GREEN}$result${NC}"
        elif [[ "$result" =~ ^FAILED ]]; then
            echo -e "${RED}$result${NC}"
        else
            echo -e "${YELLOW}$result${NC}"
        fi
    done
    echo ""
}

verify_migrations() {
    print_step "Step 4: Verifying Migrations"
    
    for service_config in "${SERVICES_TO_MIGRATE[@]}"; do
        IFS=':' read -r service_dir repo_name service_type <<< "$service_config"
        
        if [[ "$service_type" == "java-springboot" ]]; then
            print_info "Verifying $ORG_NAME/$repo_name"
            
            if ./scripts/verify-migration.sh "$ORG_NAME/$repo_name"; then
                print_success "✅ $repo_name verification passed"
            else
                print_error "❌ $repo_name verification failed"
            fi
        fi
        echo ""
    done
}

print_next_steps() {
    echo -e "${GREEN}🎉 Migration Process Complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo ""
    echo -e "${YELLOW}1. Configure Repository Secrets:${NC}"
    echo "   For each service repository, add these secrets:"
    echo "   - AZURE_CLIENT_ID"
    echo "   - AZURE_TENANT_ID" 
    echo "   - AZURE_SUBSCRIPTION_ID"
    echo "   - ACR_LOGIN_SERVER"
    echo "   - KEYVAULT_NAME"
    echo ""
    echo -e "${YELLOW}2. Test Deployments:${NC}"
    for service_config in "${SERVICES_TO_MIGRATE[@]}"; do
        IFS=':' read -r service_dir repo_name service_type <<< "$service_config"
        if [[ "$service_type" == "java-springboot" ]]; then
            echo "   gh workflow run deploy.yml -R $ORG_NAME/$repo_name -f environment=dev"
        fi
    done
    echo ""
    echo -e "${YELLOW}3. Set up Team Access:${NC}"
    echo "   Configure team permissions for each repository"
    echo ""
    echo -e "${YELLOW}4. Monitor Deployments:${NC}"
    echo "   Check that all services deploy successfully"
    echo ""
    echo -e "${BLUE}📊 Repository URLs:${NC}"
    echo "   Shared Workflows: https://github.com/$ORG_NAME/$SHARED_WORKFLOWS_REPO"
    for service_config in "${SERVICES_TO_MIGRATE[@]}"; do
        IFS=':' read -r service_dir repo_name service_type <<< "$service_config"
        echo "   $repo_name: https://github.com/$ORG_NAME/$repo_name"
    done
    echo ""
}

# Main execution
main() {
    print_header
    
    # Check if configuration exists
    if [[ ! -f "migration-config.sh" ]]; then
        print_error "migration-config.sh not found!"
        echo "Please edit migration-config.sh with your configuration first"
        exit 1
    fi
    
    print_info "Starting complete migration process..."
    echo "This will:"
    echo "1. Check prerequisites"
    echo "2. Create shared workflows repository"
    echo "3. Migrate all configured services"
    echo "4. Verify migrations"
    echo ""
    
    read -p "Continue with migration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration cancelled by user"
        exit 0
    fi
    
    run_prerequisites_check
    create_shared_workflows
    migrate_services
    verify_migrations
    print_next_steps
}

main "$@"
EOF
    
    chmod +x run-complete-migration.sh
    print_success "Created: run-complete-migration.sh"
}

create_individual_scripts() {
    print_step "Creating individual migration scripts..."
    
    # Prerequisites check script
    cat > check-prerequisites.sh << 'EOF'
#!/bin/bash
source ./migration-config.sh
./scripts/check-migration-prerequisites.sh
EOF
    
    # Create shared workflows script
    cat > create-shared-workflows.sh << 'EOF'
#!/bin/bash
source ./migration-config.sh
./scripts/create-shared-workflows-repo.sh "$ORG_NAME" "$SHARED_WORKFLOWS_REPO"
EOF
    
    # Migrate single service script
    cat > migrate-single-service.sh << 'EOF'
#!/bin/bash
# Usage: ./migrate-single-service.sh java-backend1 new-repo-name

source ./migration-config.sh

SERVICE_DIR="$1"
REPO_NAME="$2"

if [[ -z "$SERVICE_DIR" || -z "$REPO_NAME" ]]; then
    echo "Usage: $0 <service-directory> <new-repo-name>"
    echo "Example: $0 java-backend1 java-backend1-user-management"
    exit 1
fi

echo "Migrating $SERVICE_DIR to $ORG_NAME/$REPO_NAME"
./scripts/migrate-java-service.sh "$SERVICE_DIR" "$ORG_NAME/$REPO_NAME" "$SHARED_WORKFLOWS_REPO"
EOF
    
    # Verify single service script
    cat > verify-single-service.sh << 'EOF'
#!/bin/bash
# Usage: ./verify-single-service.sh repo-name

source ./migration-config.sh

REPO_NAME="$1"

if [[ -z "$REPO_NAME" ]]; then
    echo "Usage: $0 <repo-name>"
    echo "Example: $0 java-backend1-user-management"
    exit 1
fi

echo "Verifying $ORG_NAME/$REPO_NAME"
./scripts/verify-migration.sh "$ORG_NAME/$REPO_NAME"
EOF
    
    chmod +x check-prerequisites.sh create-shared-workflows.sh migrate-single-service.sh verify-single-service.sh
    print_success "Individual scripts created"
}

create_readme() {
    print_step "Creating README..."
    
    cat > README.md << 'EOF'
# Backend Services Migration Workspace

This workspace contains all tools and scripts needed to migrate your backend services from a monorepo to independent repositories.

## 🏗️ Target Architecture

After migration, you'll have:

- **1 Shared Workflows Repository**: Centralized CI/CD workflows and composite actions
- **Multiple App Repositories**: Each service in its own independent repository

## 🚀 Quick Start

### 1. Configure Your Migration

```bash
# Edit configuration with your details
nano migration-config.sh
```

Update:
- `ORG_NAME`: Your GitHub organization
- `SHARED_WORKFLOWS_REPO`: Name for shared workflows repository
- `SERVICES_TO_MIGRATE`: List of services to migrate
- `SOURCE_MONOREPO_PATH`: Path to your current monorepo

### 2. Run Complete Migration

```bash
# Run entire migration process
./run-complete-migration.sh
```

This will:
1. Check prerequisites
2. Create shared workflows repository
3. Migrate all services
4. Verify migrations

### 3. Individual Operations (Optional)

```bash
# Check prerequisites only
./check-prerequisites.sh

# Create shared workflows only
./create-shared-workflows.sh

# Migrate single service
./migrate-single-service.sh java-backend1 java-backend1-user-management

# Verify single service
./verify-single-service.sh java-backend1-user-management
```

## 📁 Directory Structure

```
migration-workspace/
├── scripts/                          # Migration scripts
│   ├── check-migration-prerequisites.sh
│   ├── create-shared-workflows-repo.sh
│   ├── migrate-java-service.sh
│   └── verify-migration.sh
├── logs/                             # Migration logs and reports
├── migration-config.sh               # Your configuration
├── run-complete-migration.sh         # Master migration script
├── check-prerequisites.sh            # Individual scripts
├── create-shared-workflows.sh
├── migrate-single-service.sh
├── verify-single-service.sh
└── README.md                         # This file
```

## 🎯 Migration Process

1. **Prerequisites**: Validate tools and environment
2. **Shared Workflows**: Create centralized workflows repository
3. **Service Migration**: Move each service to independent repository
4. **Verification**: Validate migration success
5. **Testing**: Deploy to development environment

## 📊 Expected Results

### Shared Workflows Repository
- Centralized GitHub Actions workflows
- Reusable composite actions
- Complete documentation

### Each Service Repository
- Complete Spring Boot application
- Independent CI/CD workflow
- Environment-specific configurations
- Helm charts for Kubernetes
- Comprehensive documentation

## 🛠️ Troubleshooting

- Check `logs/` directory for detailed logs
- Review error messages and follow suggested solutions
- Ensure all prerequisites are met
- Verify GitHub CLI authentication

## 📞 Support

- Review documentation files for detailed guides
- Check logs for specific error details
- Contact your DevOps team for assistance

---

**Ready to migrate? Start by editing `migration-config.sh`!**
EOF
    
    print_success "Created: README.md"
}

print_next_steps() {
    echo ""
    echo -e "${GREEN}🎉 Migration Workspace Setup Complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo ""
    echo -e "${YELLOW}1. Navigate to the workspace:${NC}"
    echo "   cd $WORKSPACE_DIR"
    echo ""
    echo -e "${YELLOW}2. Configure your migration:${NC}"
    echo "   nano migration-config.sh"
    echo ""
    echo -e "${YELLOW}3. Edit the configuration:${NC}"
    echo "   - Update ORG_NAME with your GitHub organization"
    echo "   - Set SOURCE_MONOREPO_PATH to your monorepo location"
    echo "   - Update SERVICES_TO_MIGRATE list"
    echo ""
    echo -e "${YELLOW}4. Run the complete migration:${NC}"
    echo "   ./run-complete-migration.sh"
    echo ""
    echo -e "${BLUE}📁 Workspace created at: $(readlink -f $WORKSPACE_DIR)${NC}"
    echo ""
    echo -e "${CYAN}🔗 Or run individual steps:${NC}"
    echo "   ./check-prerequisites.sh           # Check prerequisites"
    echo "   ./create-shared-workflows.sh       # Create shared workflows repo"
    echo "   ./migrate-single-service.sh        # Migrate one service"
    echo "   ./verify-single-service.sh         # Verify one service"
    echo ""
}

# Main execution
main() {
    print_header
    
    create_workspace
    copy_migration_files
    create_migration_config
    create_master_migration_script
    create_individual_scripts
    create_readme
    
    print_next_steps
}

main "$@"