#!/bin/bash

# Migration Files Copy Script
# Copies all necessary migration files to your existing repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SOURCE_DIR="$(pwd)"
TARGET_REPO_PATH="${1}"

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  📂 Migration Files Copy Tool${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${CYAN}Source: ${SOURCE_DIR}${NC}"
    echo -e "${CYAN}Target: ${TARGET_REPO_PATH}${NC}"
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

usage() {
    echo "Usage: $0 <target-repository-path>"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/your/existing/repo"
    echo "  $0 ../my-backend-repo"
    echo "  $0 ."
    echo ""
    echo "This script will copy all migration files to your existing repository:"
    echo "  - Migration scripts (scripts/)"
    echo "  - Documentation (*.md files)"
    echo "  - Workflow templates"
    echo ""
    exit 1
}

validate_target() {
    print_step "Validating target repository..."
    
    if [[ ! -d "$TARGET_REPO_PATH" ]]; then
        print_error "Target directory does not exist: $TARGET_REPO_PATH"
        exit 1
    fi
    
    if [[ ! -d "$TARGET_REPO_PATH/.git" ]]; then
        print_error "Target directory is not a Git repository: $TARGET_REPO_PATH"
        print_info "Make sure you're pointing to the root of your repository"
        exit 1
    fi
    
    print_success "Target repository validated"
}

copy_migration_scripts() {
    print_step "Copying migration scripts..."
    
    # Create scripts directory if it doesn't exist
    mkdir -p "$TARGET_REPO_PATH/scripts"
    
    # Copy all migration scripts
    local scripts=(
        "check-migration-prerequisites.sh"
        "create-shared-workflows-repo.sh"
        "migrate-java-service.sh"
        "verify-migration.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$SOURCE_DIR/scripts/$script" ]]; then
            cp "$SOURCE_DIR/scripts/$script" "$TARGET_REPO_PATH/scripts/"
            chmod +x "$TARGET_REPO_PATH/scripts/$script"
            print_success "Copied: scripts/$script"
        else
            print_error "Script not found: scripts/$script"
        fi
    done
    
    # Copy any existing migration script
    if [[ -f "$SOURCE_DIR/scripts/migrate-to-separate-repos.sh" ]]; then
        cp "$SOURCE_DIR/scripts/migrate-to-separate-repos.sh" "$TARGET_REPO_PATH/scripts/"
        chmod +x "$TARGET_REPO_PATH/scripts/migrate-to-separate-repos.sh"
        print_success "Copied: scripts/migrate-to-separate-repos.sh (original)"
    fi
}

copy_documentation() {
    print_step "Copying documentation..."
    
    local docs=(
        "BACKEND_MIGRATION_COMPREHENSIVE_GUIDE.md"
        "MIGRATION_QUICK_START.md"
    )
    
    for doc in "${docs[@]}"; do
        if [[ -f "$SOURCE_DIR/$doc" ]]; then
            cp "$SOURCE_DIR/$doc" "$TARGET_REPO_PATH/"
            print_success "Copied: $doc"
        else
            print_error "Documentation not found: $doc"
        fi
    done
    
    # Copy existing migration guide if available
    if [[ -f "$SOURCE_DIR/REPOSITORY_MIGRATION_GUIDE.md" ]]; then
        cp "$SOURCE_DIR/REPOSITORY_MIGRATION_GUIDE.md" "$TARGET_REPO_PATH/"
        print_success "Copied: REPOSITORY_MIGRATION_GUIDE.md (original)"
    fi
}

create_logs_directory() {
    print_step "Creating logs directory..."
    
    mkdir -p "$TARGET_REPO_PATH/logs"
    
    # Create .gitignore for logs if it doesn't exist
    if [[ ! -f "$TARGET_REPO_PATH/logs/.gitignore" ]]; then
        cat > "$TARGET_REPO_PATH/logs/.gitignore" << 'EOF'
# Migration logs
*.log
*.md
*.txt

# Keep directory but ignore contents
*
!.gitignore
EOF
        print_success "Created: logs/.gitignore"
    fi
    
    print_success "Logs directory ready"
}

create_readme_for_migration() {
    print_step "Creating migration README..."
    
    cat > "$TARGET_REPO_PATH/MIGRATION_README.md" << 'EOF'
# Migration Guide for This Repository

This repository contains all the necessary tools and documentation for migrating your backend services from a monorepo to independent repositories.

## 🚀 Quick Start

```bash
# 1. Check prerequisites
./scripts/check-migration-prerequisites.sh

# 2. Create shared workflows repository
./scripts/create-shared-workflows-repo.sh mycompany shared-workflows

# 3. Migrate a Java service (example)
./scripts/migrate-java-service.sh java-backend1 mycompany/java-backend1-user-management

# 4. Verify migration
./scripts/verify-migration.sh mycompany/java-backend1-user-management
```

## 📚 Documentation

- **[Quick Start Guide](./MIGRATION_QUICK_START.md)** - Get started in minutes
- **[Comprehensive Guide](./BACKEND_MIGRATION_COMPREHENSIVE_GUIDE.md)** - Detailed documentation
- **[Original Guide](./REPOSITORY_MIGRATION_GUIDE.md)** - Original migration documentation

## 🛠️ Available Scripts

### Prerequisites and Setup
- `./scripts/check-migration-prerequisites.sh` - Validate environment and tools
- `./scripts/create-shared-workflows-repo.sh` - Create centralized workflows repository

### Migration Scripts
- `./scripts/migrate-java-service.sh` - Migrate Java/Spring Boot services
- `./scripts/verify-migration.sh` - Verify migration success

### Logs and Reports
- `./logs/` - All migration logs and reports are stored here

## 📋 Before You Start

1. Make sure you have GitHub CLI installed and authenticated
2. Ensure you have the required tools (Git, Docker, Maven, Helm)
3. Run the prerequisites check first

## 🎯 Migration Process

1. **Prerequisites Check**: Ensure your environment is ready
2. **Create Shared Workflows**: Set up centralized CI/CD workflows
3. **Migrate Services**: Move each service to its own repository
4. **Verify Migration**: Validate that everything works correctly
5. **Test Deployment**: Deploy to development environment

## 📞 Support

- Check `logs/` directory for detailed logs
- Review troubleshooting sections in the documentation
- Contact your DevOps team for assistance

---

**Ready to migrate? Start with the prerequisites check!**

```bash
./scripts/check-migration-prerequisites.sh
```
EOF
    
    print_success "Created: MIGRATION_README.md"
}

create_example_commands() {
    print_step "Creating example commands file..."
    
    cat > "$TARGET_REPO_PATH/migration-commands-example.sh" << 'EOF'
#!/bin/bash

# Example Migration Commands
# Copy and modify these commands for your specific setup

# Replace these variables with your actual values
ORG_NAME="mycompany"
SHARED_WORKFLOWS_REPO="shared-workflows"

echo "📋 Example Migration Commands"
echo "============================="
echo ""

echo "1. Check Prerequisites:"
echo "   ./scripts/check-migration-prerequisites.sh"
echo ""

echo "2. Create Shared Workflows Repository:"
echo "   ./scripts/create-shared-workflows-repo.sh $ORG_NAME $SHARED_WORKFLOWS_REPO"
echo ""

echo "3. Migrate Java Services:"
echo "   ./scripts/migrate-java-service.sh java-backend1 $ORG_NAME/java-backend1-user-management"
echo "   ./scripts/migrate-java-service.sh java-backend2 $ORG_NAME/java-backend2-product-catalog"
echo "   ./scripts/migrate-java-service.sh java-backend3 $ORG_NAME/java-backend3-order-management"
echo ""

echo "4. Verify Migrations:"
echo "   ./scripts/verify-migration.sh $ORG_NAME/java-backend1-user-management"
echo "   ./scripts/verify-migration.sh $ORG_NAME/java-backend2-product-catalog"
echo "   ./scripts/verify-migration.sh $ORG_NAME/java-backend3-order-management"
echo ""

echo "5. Test Deployments:"
echo "   gh workflow run deploy.yml -R $ORG_NAME/java-backend1-user-management -f environment=dev"
echo "   gh workflow run deploy.yml -R $ORG_NAME/java-backend2-product-catalog -f environment=dev"
echo "   gh workflow run deploy.yml -R $ORG_NAME/java-backend3-order-management -f environment=dev"
echo ""

echo "📝 Remember to:"
echo "   - Replace '$ORG_NAME' with your actual GitHub organization"
echo "   - Update service names to match your actual services"
echo "   - Configure repository secrets after migration"
echo "   - Set up team access permissions"
echo ""
EOF
    
    chmod +x "$TARGET_REPO_PATH/migration-commands-example.sh"
    print_success "Created: migration-commands-example.sh"
}

print_next_steps() {
    echo ""
    echo -e "${GREEN}🎉 Migration Files Copied Successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo ""
    echo -e "${YELLOW}1. Navigate to your repository:${NC}"
    echo "   cd $TARGET_REPO_PATH"
    echo ""
    echo -e "${YELLOW}2. Review the migration documentation:${NC}"
    echo "   cat MIGRATION_README.md"
    echo "   cat MIGRATION_QUICK_START.md"
    echo ""
    echo -e "${YELLOW}3. Check prerequisites:${NC}"
    echo "   ./scripts/check-migration-prerequisites.sh"
    echo ""
    echo -e "${YELLOW}4. Review example commands:${NC}"
    echo "   cat migration-commands-example.sh"
    echo ""
    echo -e "${YELLOW}5. Start migration process:${NC}"
    echo "   # Create shared workflows first"
    echo "   ./scripts/create-shared-workflows-repo.sh YOUR_ORG shared-workflows"
    echo ""
    echo "   # Then migrate your services"
    echo "   ./scripts/migrate-java-service.sh java-backend1 YOUR_ORG/java-backend1-SERVICE_NAME"
    echo ""
    echo -e "${BLUE}📁 Files copied:${NC}"
    echo "   ✅ Migration scripts in scripts/"
    echo "   ✅ Documentation files (*.md)"
    echo "   ✅ Logs directory created"
    echo "   ✅ Example commands file"
    echo "   ✅ Migration README"
    echo ""
    echo -e "${CYAN}🔗 Quick start: Follow MIGRATION_QUICK_START.md for step-by-step instructions${NC}"
    echo ""
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        usage
    fi
    
    print_header
    
    validate_target
    copy_migration_scripts
    copy_documentation
    create_logs_directory
    create_readme_for_migration
    create_example_commands
    
    print_next_steps
}

# Run main function with all arguments
main "$@"