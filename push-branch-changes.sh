#!/bin/bash

# Push Branch Changes Script
# Pushes all migrated changes to respective remote branches

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
FORCE_PUSH="${1:-false}"

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  📤 Push Branch Changes to Remote${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${CYAN}Shared Workflows Branch: ${SHARED_BRANCH}${NC}"
    echo -e "${CYAN}App Branch: ${APP_BRANCH}${NC}"
    echo -e "${CYAN}Force Push: ${FORCE_PUSH}${NC}"
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
    echo "Usage: $0 [force]"
    echo ""
    echo "Options:"
    echo "  force    Force push to remote branches (use with caution)"
    echo ""
    echo "Examples:"
    echo "  $0           # Normal push"
    echo "  $0 force     # Force push (overwrites remote)"
    echo ""
    echo "This script will:"
    echo "  1. Check remote repository access"
    echo "  2. Push shared-github-actions branch"
    echo "  3. Push my-java-app branch"
    echo "  4. Set up branch tracking"
    echo "  5. Display push summary"
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
    
    # Check if branches exist locally
    if ! git show-ref --verify --quiet "refs/heads/$SHARED_BRANCH"; then
        print_error "Local branch $SHARED_BRANCH does not exist"
        print_info "Run ./migrate-to-branches.sh first"
        exit 1
    fi
    
    if ! git show-ref --verify --quiet "refs/heads/$APP_BRANCH"; then
        print_error "Local branch $APP_BRANCH does not exist"
        print_info "Run ./migrate-to-branches.sh first"
        exit 1
    fi
    
    # Check if remote is configured
    if ! git remote get-url origin > /dev/null 2>&1; then
        print_error "No remote 'origin' configured"
        print_info "Configure remote with: git remote add origin <repository-url>"
        exit 1
    fi
    
    # Check remote access
    print_info "Testing remote access..."
    if git ls-remote --heads origin > /dev/null 2>&1; then
        print_success "Remote access verified"
    else
        print_error "Cannot access remote repository"
        print_info "Check your Git credentials and network connection"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

check_remote_branches() {
    print_step "Checking remote branch status..."
    
    # Fetch latest remote information
    git fetch origin --quiet || print_warning "Could not fetch from remote"
    
    # Check if remote branches exist
    if git ls-remote --heads origin | grep -q "refs/heads/$SHARED_BRANCH"; then
        print_info "Remote branch $SHARED_BRANCH exists"
        SHARED_BRANCH_EXISTS_REMOTE=true
    else
        print_info "Remote branch $SHARED_BRANCH does not exist (will be created)"
        SHARED_BRANCH_EXISTS_REMOTE=false
    fi
    
    if git ls-remote --heads origin | grep -q "refs/heads/$APP_BRANCH"; then
        print_info "Remote branch $APP_BRANCH exists"
        APP_BRANCH_EXISTS_REMOTE=true
    else
        print_info "Remote branch $APP_BRANCH does not exist (will be created)"
        APP_BRANCH_EXISTS_REMOTE=false
    fi
}

push_shared_workflows_branch() {
    print_step "Pushing shared workflows branch..."
    
    git checkout "$SHARED_BRANCH"
    
    # Check if there are commits to push
    if git diff --quiet HEAD^ HEAD 2>/dev/null; then
        print_info "No changes to push in $SHARED_BRANCH"
        return 0
    fi
    
    local push_command="git push origin $SHARED_BRANCH"
    
    if [[ "$FORCE_PUSH" == "force" ]]; then
        push_command="git push --force-with-lease origin $SHARED_BRANCH"
        print_warning "Force pushing $SHARED_BRANCH branch"
    elif [[ "$SHARED_BRANCH_EXISTS_REMOTE" == "true" ]]; then
        print_warning "Remote branch $SHARED_BRANCH exists"
        print_info "Checking if force push is needed..."
        
        # Check if local and remote have diverged
        git fetch origin "$SHARED_BRANCH" --quiet 2>/dev/null || true
        
        if ! git merge-base --is-ancestor "origin/$SHARED_BRANCH" HEAD 2>/dev/null; then
            print_warning "Local and remote branches have diverged"
            read -p "Force push $SHARED_BRANCH? This will overwrite remote changes. (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                push_command="git push --force-with-lease origin $SHARED_BRANCH"
            else
                print_info "Skipping push of $SHARED_BRANCH"
                return 1
            fi
        fi
    fi
    
    print_info "Executing: $push_command"
    if eval "$push_command"; then
        print_success "Successfully pushed $SHARED_BRANCH branch"
        
        # Set up tracking
        git branch --set-upstream-to="origin/$SHARED_BRANCH" "$SHARED_BRANCH" 2>/dev/null || true
        
        return 0
    else
        print_error "Failed to push $SHARED_BRANCH branch"
        return 1
    fi
}

push_app_branch() {
    print_step "Pushing app branch..."
    
    git checkout "$APP_BRANCH"
    
    # Check if there are commits to push
    if git diff --quiet HEAD^ HEAD 2>/dev/null; then
        print_info "No changes to push in $APP_BRANCH"
        return 0
    fi
    
    local push_command="git push origin $APP_BRANCH"
    
    if [[ "$FORCE_PUSH" == "force" ]]; then
        push_command="git push --force-with-lease origin $APP_BRANCH"
        print_warning "Force pushing $APP_BRANCH branch"
    elif [[ "$APP_BRANCH_EXISTS_REMOTE" == "true" ]]; then
        print_warning "Remote branch $APP_BRANCH exists"
        print_info "Checking if force push is needed..."
        
        # Check if local and remote have diverged
        git fetch origin "$APP_BRANCH" --quiet 2>/dev/null || true
        
        if ! git merge-base --is-ancestor "origin/$APP_BRANCH" HEAD 2>/dev/null; then
            print_warning "Local and remote branches have diverged"
            read -p "Force push $APP_BRANCH? This will overwrite remote changes. (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                push_command="git push --force-with-lease origin $APP_BRANCH"
            else
                print_info "Skipping push of $APP_BRANCH"
                return 1
            fi
        fi
    fi
    
    print_info "Executing: $push_command"
    if eval "$push_command"; then
        print_success "Successfully pushed $APP_BRANCH branch"
        
        # Set up tracking
        git branch --set-upstream-to="origin/$APP_BRANCH" "$APP_BRANCH" 2>/dev/null || true
        
        return 0
    else
        print_error "Failed to push $APP_BRANCH branch"
        return 1
    fi
}

push_backup_branch() {
    print_step "Checking for backup branch..."
    
    # Find the most recent backup branch
    local backup_branch
    backup_branch=$(git branch --list "migration-backup-*" | sort | tail -n 1 | sed 's/^[* ] //')
    
    if [[ -n "$backup_branch" ]]; then
        print_info "Found backup branch: $backup_branch"
        read -p "Push backup branch to remote? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git checkout "$backup_branch"
            if git push origin "$backup_branch"; then
                print_success "Backup branch pushed: $backup_branch"
            else
                print_warning "Failed to push backup branch"
            fi
        fi
    else
        print_info "No backup branch found"
    fi
}

create_pull_requests() {
    print_step "Creating pull requests (if needed)..."
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        print_info "GitHub CLI not available, skipping PR creation"
        print_info "You can create PRs manually in the GitHub web interface"
        return 0
    fi
    
    # Check if we should create PRs
    read -p "Create pull requests for review? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping PR creation"
        return 0
    fi
    
    # Create PR for shared workflows branch
    print_info "Creating PR for shared workflows..."
    if gh pr create \
        --head "$SHARED_BRANCH" \
        --base main \
        --title "feat: migrate shared GitHub Actions workflows" \
        --body "🚀 **Shared Workflows Migration**

This PR introduces centralized GitHub Actions workflows and composite actions.

## 📋 Changes

- ✅ Migrated all shared workflows to dedicated branch
- ✅ Created reusable composite actions
- ✅ Added comprehensive documentation
- ✅ Established contribution guidelines

## 🎯 Purpose

- **Centralized CI/CD**: Consistent deployment patterns across all services
- **Maintenance Efficiency**: Update workflows in one place, benefit everywhere
- **Security Standards**: Enforce security scanning and compliance
- **Best Practices**: Ensure all services follow the same patterns

## 🔗 Related

This works together with the service migration in the $APP_BRANCH branch.

## 🧪 Testing

- [ ] Workflow syntax validation passed
- [ ] Documentation reviewed
- [ ] Integration tested with service branches

Ready for review! 🎉" 2>/dev/null; then
        print_success "Created PR for $SHARED_BRANCH"
    else
        print_warning "Could not create PR for $SHARED_BRANCH (may already exist)"
    fi
    
    # Create PR for app branch
    print_info "Creating PR for app branch..."
    if gh pr create \
        --head "$APP_BRANCH" \
        --base main \
        --title "feat: migrate Spring Boot application to independent branch" \
        --body "🎁 **Spring Boot Application Migration**

This PR migrates the Spring Boot application to an independent branch with proper workflow integration.

## 📋 Changes

- ✅ Migrated complete Spring Boot application
- ✅ Updated workflows to reference shared branch
- ✅ Configured multi-environment profiles
- ✅ Updated documentation and deployment guides

## 🏗️ Application Features

- **Framework**: Spring Boot 3.x with Java 21
- **Multi-Environment**: Profiles for local, dev, staging, production
- **Monitoring**: Actuator endpoints, metrics, health checks
- **Deployment**: GitHub Actions + Kubernetes + Helm

## 🔗 Dependencies

This branch references shared workflows from the $SHARED_BRANCH branch.

## 🧪 Testing

- [ ] Maven build passes
- [ ] Docker build successful
- [ ] Workflow syntax validated
- [ ] Spring Boot profiles tested

Ready for independent development! 🚀" 2>/dev/null; then
        print_success "Created PR for $APP_BRANCH"
    else
        print_warning "Could not create PR for $APP_BRANCH (may already exist)"
    fi
}

display_remote_info() {
    print_step "Displaying remote repository information..."
    
    local remote_url
    remote_url=$(git remote get-url origin)
    
    echo -e "${BLUE}📍 Remote Repository:${NC} $remote_url"
    echo ""
    echo -e "${BLUE}🌿 Remote Branches:${NC}"
    
    # Show remote branches
    git ls-remote --heads origin | while read -r sha ref; do
        local branch_name=${ref#refs/heads/}
        if [[ "$branch_name" == "$SHARED_BRANCH" || "$branch_name" == "$APP_BRANCH" ]]; then
            echo -e "  ✅ $branch_name"
        else
            echo -e "  📂 $branch_name"
        fi
    done
    
    echo ""
    echo -e "${BLUE}🔗 Branch URLs:${NC}"
    local repo_url=${remote_url%.git}
    repo_url=${repo_url#git@github.com:}
    repo_url=${repo_url#https://github.com/}
    
    echo -e "  🔄 Shared Workflows: https://github.com/$repo_url/tree/$SHARED_BRANCH"
    echo -e "  🎁 Application Code: https://github.com/$repo_url/tree/$APP_BRANCH"
}

print_summary() {
    echo ""
    echo -e "${GREEN}🎉 Branch Push Completed Successfully!${NC}"
    echo ""
    echo -e "${BLUE}📊 Push Summary:${NC}"
    echo -e "   🔄 Shared workflows pushed to: ${SHARED_BRANCH}"
    echo -e "   🎁 Application code pushed to: ${APP_BRANCH}"
    echo ""
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo ""
    echo -e "${YELLOW}1. Verify branches on GitHub:${NC}"
    echo "   - Check shared workflows: https://github.com/<your-repo>/tree/$SHARED_BRANCH"
    echo "   - Check application code: https://github.com/<your-repo>/tree/$APP_BRANCH"
    echo ""
    echo -e "${YELLOW}2. Test deployment:${NC}"
    echo "   git checkout $APP_BRANCH"
    echo "   gh workflow run deploy.yml -f environment=dev"
    echo ""
    echo -e "${YELLOW}3. Configure branch protection (recommended):${NC}"
    echo "   gh api repos/:owner/:repo/branches/$SHARED_BRANCH/protection --method PUT --field required_pull_request_reviews='{\"required_approving_review_count\":1}'"
    echo "   gh api repos/:owner/:repo/branches/$APP_BRANCH/protection --method PUT --field required_pull_request_reviews='{\"required_approving_review_count\":1}'"
    echo ""
    echo -e "${YELLOW}4. Team workflow:${NC}"
    echo "   - DevOps team: Work on $SHARED_BRANCH for CI/CD improvements"
    echo "   - Development team: Work on $APP_BRANCH for application features"
    echo "   - Both teams: Collaborate through pull requests"
    echo ""
    echo -e "${BLUE}🔄 Working with Branches:${NC}"
    echo ""
    echo -e "${CYAN}Update shared workflows:${NC}"
    echo "   git checkout $SHARED_BRANCH"
    echo "   # Edit workflows or actions"
    echo "   git add . && git commit -m 'feat: improve deployment'"
    echo "   git push origin $SHARED_BRANCH"
    echo ""
    echo -e "${CYAN}Develop application:${NC}"
    echo "   git checkout $APP_BRANCH"
    echo "   # Edit Spring Boot application"
    echo "   git add . && git commit -m 'feat: add new feature'"
    echo "   git push origin $APP_BRANCH"
    echo ""
    echo -e "${GREEN}✅ Your branch-based CI/CD architecture is now live!${NC}"
    echo ""
}

print_troubleshooting() {
    echo -e "${BLUE}🔧 Troubleshooting:${NC}"
    echo ""
    echo -e "${YELLOW}Push rejected:${NC}"
    echo "  - Use 'force' option: ./push-branch-changes.sh force"
    echo "  - Or merge conflicts manually"
    echo ""
    echo -e "${YELLOW}Authentication failed:${NC}"
    echo "  - Check GitHub credentials: gh auth status"
    echo "  - Re-authenticate: gh auth login"
    echo ""
    echo -e "${YELLOW}Workflow not triggering:${NC}"
    echo "  - Check workflow file: .github/workflows/deploy.yml"
    echo "  - Verify branch references: @$SHARED_BRANCH"
    echo "  - Check repository secrets configuration"
    echo ""
}

# Main execution
main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
    fi
    
    print_header
    
    check_prerequisites
    check_remote_branches
    
    # Push branches
    local shared_push_success=false
    local app_push_success=false
    
    if push_shared_workflows_branch; then
        shared_push_success=true
    fi
    
    if push_app_branch; then
        app_push_success=true
    fi
    
    # Optionally push backup
    push_backup_branch
    
    # Create pull requests if requested
    if [[ "$shared_push_success" == "true" && "$app_push_success" == "true" ]]; then
        create_pull_requests
    fi
    
    display_remote_info
    print_summary
    
    if [[ "$shared_push_success" == "false" || "$app_push_success" == "false" ]]; then
        print_troubleshooting
        exit 1
    fi
}

# Run main function with all arguments
main "$@"