#!/bin/bash

# Branch Migration Verification Script
# Verifies that both branches are properly set up after migration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SHARED_BRANCH="shared-github-actions"
APP_BRANCH="my-java-app"
VERIFICATION_RESULTS=()

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  🔍 Branch Migration Verification${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${CYAN}Shared Workflows Branch: ${SHARED_BRANCH}${NC}"
    echo -e "${CYAN}App Branch: ${APP_BRANCH}${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}✨ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    VERIFICATION_RESULTS+=("SUCCESS: $1")
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    VERIFICATION_RESULTS+=("WARNING: $1")
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    VERIFICATION_RESULTS+=("ERROR: $1")
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_branches_exist() {
    print_step "Checking if branches exist..."
    
    if git show-ref --verify --quiet "refs/heads/$SHARED_BRANCH"; then
        print_success "Branch $SHARED_BRANCH exists"
    else
        print_error "Branch $SHARED_BRANCH does not exist"
    fi
    
    if git show-ref --verify --quiet "refs/heads/$APP_BRANCH"; then
        print_success "Branch $APP_BRANCH exists"
    else
        print_error "Branch $APP_BRANCH does not exist"
    fi
}

verify_shared_workflows_branch() {
    print_step "Verifying shared workflows branch..."
    
    # Switch to shared workflows branch
    if ! git checkout "$SHARED_BRANCH" 2>/dev/null; then
        print_error "Cannot switch to $SHARED_BRANCH branch"
        return 1
    fi
    
    # Check for .github directory
    if [[ -d ".github" ]]; then
        print_success "Found .github directory"
    else
        print_error "Missing .github directory"
    fi
    
    # Check for workflows
    if [[ -d ".github/workflows" ]]; then
        print_success "Found .github/workflows directory"
        
        local workflow_count
        workflow_count=$(find .github/workflows -name "*.yml" -o -name "*.yaml" | wc -l)
        if [[ $workflow_count -gt 0 ]]; then
            print_success "Found $workflow_count workflow files"
        else
            print_warning "No workflow files found"
        fi
    else
        print_error "Missing .github/workflows directory"
    fi
    
    # Check for composite actions
    if [[ -d ".github/actions" ]]; then
        print_success "Found .github/actions directory"
        
        local action_count
        action_count=$(find .github/actions -mindepth 1 -maxdepth 1 -type d | wc -l)
        if [[ $action_count -gt 0 ]]; then
            print_success "Found $action_count composite actions"
        else
            print_warning "No composite actions found"
        fi
    else
        print_warning "Missing .github/actions directory"
    fi
    
    # Check for README
    if [[ -f "README.md" ]]; then
        print_success "Found README.md"
        
        if grep -q "Shared GitHub Actions Workflows" README.md; then
            print_success "README contains shared workflows documentation"
        else
            print_warning "README may not be properly updated for shared workflows"
        fi
    else
        print_error "Missing README.md"
    fi
    
    # Check for documentation
    if [[ -f "CONTRIBUTING.md" ]]; then
        print_success "Found CONTRIBUTING.md"
    else
        print_warning "Missing CONTRIBUTING.md"
    fi
    
    if [[ -d "docs" ]]; then
        print_success "Found docs directory"
    else
        print_warning "Missing docs directory"
    fi
}

verify_app_branch() {
    print_step "Verifying app branch..."
    
    # Switch to app branch
    if ! git checkout "$APP_BRANCH" 2>/dev/null; then
        print_error "Cannot switch to $APP_BRANCH branch"
        return 1
    fi
    
    # Check for Java application files
    if [[ -f "pom.xml" ]]; then
        print_success "Found pom.xml"
    else
        print_error "Missing pom.xml"
    fi
    
    if [[ -f "Dockerfile" ]]; then
        print_success "Found Dockerfile"
    else
        print_error "Missing Dockerfile"
    fi
    
    if [[ -d "src/main/java" ]]; then
        print_success "Found src/main/java directory"
    else
        print_error "Missing src/main/java directory"
    fi
    
    if [[ -f "src/main/resources/application.yml" ]]; then
        print_success "Found application.yml"
    else
        print_error "Missing application.yml"
    fi
    
    # Check for Spring Boot profiles
    local profiles=("dev" "staging" "production")
    for profile in "${profiles[@]}"; do
        if [[ -f "src/main/resources/application-${profile}.yml" ]]; then
            print_success "Found application-${profile}.yml"
        else
            print_warning "Missing application-${profile}.yml"
        fi
    done
    
    # Check for Helm charts
    if [[ -d "helm" ]]; then
        print_success "Found helm directory"
        
        if [[ -f "helm/Chart.yaml" ]]; then
            print_success "Found helm/Chart.yaml"
        else
            print_warning "Missing helm/Chart.yaml"
        fi
        
        if [[ -f "helm/values.yaml" ]]; then
            print_success "Found helm/values.yaml"
        else
            print_warning "Missing helm/values.yaml"
        fi
    else
        print_warning "Missing helm directory"
    fi
    
    # Check for workflow
    if [[ -f ".github/workflows/deploy.yml" ]]; then
        print_success "Found .github/workflows/deploy.yml"
        
        # Check if workflow references shared branch
        if grep -q "@$SHARED_BRANCH" .github/workflows/deploy.yml; then
            print_success "Workflow references $SHARED_BRANCH branch"
        else
            print_error "Workflow does not reference $SHARED_BRANCH branch"
        fi
        
        # Check build context
        if grep -q "build_context: \\." .github/workflows/deploy.yml; then
            print_success "Build context set to current directory"
        else
            print_warning "Build context may not be correctly set"
        fi
    else
        print_error "Missing .github/workflows/deploy.yml"
    fi
    
    # Check for README
    if [[ -f "README.md" ]]; then
        print_success "Found README.md"
        
        if grep -q "$APP_BRANCH" README.md; then
            print_success "README mentions app branch"
        else
            print_warning "README may not be updated for app branch"
        fi
        
        if grep -q "$SHARED_BRANCH" README.md; then
            print_success "README mentions shared workflows branch"
        else
            print_warning "README may not mention shared workflows integration"
        fi
    else
        print_error "Missing README.md"
    fi
}

check_no_apps_directory() {
    print_step "Checking that apps directory is removed from branches..."
    
    # Check shared workflows branch
    git checkout "$SHARED_BRANCH" 2>/dev/null
    if [[ -d "apps" ]]; then
        print_warning "apps directory still exists in $SHARED_BRANCH branch"
    else
        print_success "No apps directory in $SHARED_BRANCH branch (correct)"
    fi
    
    # Check app branch
    git checkout "$APP_BRANCH" 2>/dev/null
    if [[ -d "apps" ]]; then
        print_warning "apps directory still exists in $APP_BRANCH branch"
    else
        print_success "No apps directory in $APP_BRANCH branch (correct)")
    fi
}

test_workflow_syntax() {
    print_step "Testing workflow syntax..."
    
    git checkout "$APP_BRANCH" 2>/dev/null
    
    if [[ -f ".github/workflows/deploy.yml" ]]; then
        if command -v actionlint &> /dev/null; then
            if actionlint .github/workflows/deploy.yml; then
                print_success "Workflow syntax validation passed"
            else
                print_error "Workflow syntax validation failed"
            fi
        else
            print_warning "actionlint not available for syntax validation"
        fi
    fi
}

generate_verification_report() {
    print_step "Generating verification report..."
    
    local report_file="branch-migration-verification-$(date '+%Y%m%d-%H%M%S').md"
    
    cat > "$report_file" << EOF
# Branch Migration Verification Report

**Verification Date**: $(date)  
**Shared Workflows Branch**: $SHARED_BRANCH  
**App Branch**: $APP_BRANCH

## Summary

EOF
    
    local success_count=0
    local warning_count=0
    local error_count=0
    
    for result in "${VERIFICATION_RESULTS[@]}"; do
        if [[ "$result" =~ ^SUCCESS ]]; then
            ((success_count++))
        elif [[ "$result" =~ ^WARNING ]]; then
            ((warning_count++))
        elif [[ "$result" =~ ^ERROR ]]; then
            ((error_count++))
        fi
    done
    
    echo "- **Successful Checks**: $success_count" >> "$report_file"
    echo "- **Warnings**: $warning_count" >> "$report_file"
    echo "- **Errors**: $error_count" >> "$report_file"
    echo "" >> "$report_file"
    
    if [[ $error_count -gt 0 ]]; then
        echo "## ❌ Errors Found" >> "$report_file"
        echo "" >> "$report_file"
        for result in "${VERIFICATION_RESULTS[@]}"; do
            if [[ "$result" =~ ^ERROR ]]; then
                echo "- ${result#ERROR: }" >> "$report_file"
            fi
        done
        echo "" >> "$report_file"
    fi
    
    if [[ $warning_count -gt 0 ]]; then
        echo "## ⚠️ Warnings" >> "$report_file"
        echo "" >> "$report_file"
        for result in "${VERIFICATION_RESULTS[@]}"; do
            if [[ "$result" =~ ^WARNING ]]; then
                echo "- ${result#WARNING: }" >> "$report_file"
            fi
        done
        echo "" >> "$report_file"
    fi
    
    echo "## ✅ Successful Checks" >> "$report_file"
    echo "" >> "$report_file"
    for result in "${VERIFICATION_RESULTS[@]}"; do
        if [[ "$result" =~ ^SUCCESS ]]; then
            echo "- ${result#SUCCESS: }" >> "$report_file"
        fi
    done
    echo "" >> "$report_file"
    
    echo "## Branch Structure Verification" >> "$report_file"
    echo "" >> "$report_file"
    echo "### $SHARED_BRANCH Branch" >> "$report_file"
    echo "Should contain:" >> "$report_file"
    echo "- .github/workflows/ (shared workflows)" >> "$report_file"
    echo "- .github/actions/ (composite actions)" >> "$report_file"
    echo "- README.md (shared workflows documentation)" >> "$report_file"
    echo "- CONTRIBUTING.md (contribution guidelines)" >> "$report_file"
    echo "- docs/ (additional documentation)" >> "$report_file"
    echo "" >> "$report_file"
    
    echo "### $APP_BRANCH Branch" >> "$report_file"
    echo "Should contain:" >> "$report_file"
    echo "- pom.xml (Maven configuration)" >> "$report_file"
    echo "- Dockerfile (container definition)" >> "$report_file"
    echo "- src/ (Java source code)" >> "$report_file"
    echo "- helm/ (Kubernetes charts)" >> "$report_file"
    echo "- .github/workflows/deploy.yml (referencing shared workflows)" >> "$report_file"
    echo "- README.md (service-specific documentation)" >> "$report_file"
    echo "" >> "$report_file"
    
    echo "## Next Steps" >> "$report_file"
    echo "" >> "$report_file"
    
    if [[ $error_count -eq 0 ]]; then
        echo "1. ✅ Branch migration verification passed" >> "$report_file"
        echo "2. 🚀 Test deployment: \`git checkout $APP_BRANCH && gh workflow run deploy.yml -f environment=dev\`" >> "$report_file"
        echo "3. 📊 Monitor workflow execution and deployment" >> "$report_file"
        echo "4. 🔧 Configure any missing repository secrets" >> "$report_file"
        echo "5. 📚 Review and update documentation as needed" >> "$report_file"
    else
        echo "1. ❌ Fix all errors listed above" >> "$report_file"
        echo "2. 🔄 Run verification again: \`./verify-branch-migration.sh\`" >> "$report_file"
        echo "3. 📞 Contact support if issues persist" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "## Usage Examples" >> "$report_file"
    echo "" >> "$report_file"
    echo "\`\`\`bash" >> "$report_file"
    echo "# Work with shared workflows" >> "$report_file"
    echo "git checkout $SHARED_BRANCH" >> "$report_file"
    echo "# Edit workflows or actions" >> "$report_file"
    echo "# Commit and push changes" >> "$report_file"
    echo "" >> "$report_file"
    echo "# Work with application code" >> "$report_file"
    echo "git checkout $APP_BRANCH" >> "$report_file"
    echo "# Edit Spring Boot application" >> "$report_file"
    echo "# Test deployment" >> "$report_file"
    echo "gh workflow run deploy.yml -f environment=dev" >> "$report_file"
    echo "\`\`\`" >> "$report_file"
    
    print_success "Verification report generated: $report_file"
}

print_summary() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  📊 Branch Migration Verification Summary${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
    
    local success_count=0
    local warning_count=0
    local error_count=0
    
    for result in "${VERIFICATION_RESULTS[@]}"; do
        if [[ "$result" =~ ^SUCCESS ]]; then
            ((success_count++))
        elif [[ "$result" =~ ^WARNING ]]; then
            ((warning_count++))
        elif [[ "$result" =~ ^ERROR ]]; then
            ((error_count++))
        fi
    done
    
    if [[ $error_count -eq 0 ]]; then
        echo -e "${GREEN}🎉 Branch Migration Verification Successful!${NC}"
        echo -e "${GREEN}✅ Both branches are properly configured${NC}"
    else
        echo -e "${RED}❌ Branch Migration Issues Found${NC}"
        echo -e "${RED}🔧 Manual fixes required${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📊 Results:${NC}"
    echo -e "   ✅ Successful checks: $success_count"
    echo -e "   ⚠️  Warnings: $warning_count"
    echo -e "   ❌ Errors: $error_count"
    echo ""
    
    if [[ $error_count -gt 0 ]]; then
        echo -e "${RED}Critical Issues:${NC}"
        for result in "${VERIFICATION_RESULTS[@]}"; do
            if [[ "$result" =~ ^ERROR ]]; then
                echo -e "  • ${result#ERROR: }"
            fi
        done
        echo ""
    fi
    
    if [[ $warning_count -gt 0 ]]; then
        echo -e "${YELLOW}Warnings:${NC}"
        for result in "${VERIFICATION_RESULTS[@]}"; do
            if [[ "$result" =~ ^WARNING ]]; then
                echo -e "  • ${result#WARNING: }"
            fi
        done
        echo ""
    fi
    
    echo -e "${BLUE}🔗 Quick Commands:${NC}"
    echo -e "   git checkout $SHARED_BRANCH  # Work with shared workflows"
    echo -e "   git checkout $APP_BRANCH     # Work with application code"
    echo ""
    echo -e "${BLUE}🧪 Test Deployment:${NC}"
    echo -e "   git checkout $APP_BRANCH"
    echo -e "   gh workflow run deploy.yml -f environment=dev"
    echo ""
}

# Main execution
main() {
    print_header
    
    check_branches_exist
    verify_shared_workflows_branch
    verify_app_branch
    check_no_apps_directory
    test_workflow_syntax
    
    generate_verification_report
    print_summary
    
    # Exit with appropriate code
    local error_count=0
    for result in "${VERIFICATION_RESULTS[@]}"; do
        if [[ "$result" =~ ^ERROR ]]; then
            ((error_count++))
        fi
    done
    
    if [[ $error_count -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"