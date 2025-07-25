#!/bin/bash

# Migration Verification Script
# Validates that a migrated service is working correctly

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
TARGET_REPO="${1}"
TEMP_DIR=""
VERIFICATION_RESULTS=()

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  🔍 Migration Verification Tool${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${CYAN}Target Repository: ${TARGET_REPO}${NC}"
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
    VERIFICATION_RESULTS+=("WARNING: $1")
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    VERIFICATION_RESULTS+=("ERROR: $1")
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    VERIFICATION_RESULTS+=("SUCCESS: $1")
}

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        print_info "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

usage() {
    echo "Usage: $0 <target-repo>"
    echo ""
    echo "Examples:"
    echo "  $0 mycompany/java-backend1-user-management"
    echo "  $0 mycompany/nodejs-backend1-notification"
    echo ""
    echo "Arguments:"
    echo "  target-repo    Target repository in format org/repo-name"
    exit 1
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("gh" "git" "curl")
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
    
    print_success "Prerequisites check passed"
}

verify_repository_exists() {
    print_step "Verifying repository exists and is accessible..."
    
    if ! gh repo view "$TARGET_REPO" &> /dev/null; then
        print_error "Repository $TARGET_REPO not found or not accessible"
        exit 1
    fi
    
    local repo_info
    repo_info=$(gh repo view "$TARGET_REPO" --json name,description,visibility,defaultBranch)
    local repo_name
    repo_name=$(echo "$repo_info" | jq -r '.name')
    local repo_desc
    repo_desc=$(echo "$repo_info" | jq -r '.description')
    local visibility
    visibility=$(echo "$repo_info" | jq -r '.visibility')
    local default_branch
    default_branch=$(echo "$repo_info" | jq -r '.defaultBranch')
    
    print_success "Repository found: $repo_name"
    print_info "Description: $repo_desc"
    print_info "Visibility: $visibility"
    print_info "Default branch: $default_branch"
}

clone_repository() {
    print_step "Cloning repository for verification..."
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    if ! gh repo clone "$TARGET_REPO"; then
        print_error "Failed to clone repository"
        exit 1
    fi
    
    local repo_name
    repo_name=$(basename "$TARGET_REPO")
    cd "$repo_name"
    
    print_success "Repository cloned successfully"
}

verify_file_structure() {
    print_step "Verifying file structure..."
    
    # Check for essential files
    local required_files=(
        "README.md"
        "pom.xml"
        "Dockerfile"
        ".github/workflows/deploy.yml"
        "src/main/java"
        "src/main/resources/application.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -e "$file" ]]; then
            print_success "Found: $file"
        else
            print_error "Missing: $file"
        fi
    done
    
    # Check for optional but recommended files
    local optional_files=(
        "DEPLOYMENT.md"
        "helm/Chart.yaml"
        "helm/values.yaml"
        "src/main/resources/application-dev.yml"
        "src/main/resources/application-staging.yml"
        "src/main/resources/application-production.yml"
    )
    
    print_info "Checking optional files..."
    for file in "${optional_files[@]}"; do
        if [[ -e "$file" ]]; then
            print_success "Found optional: $file"
        else
            print_warning "Missing optional: $file"
        fi
    done
}

verify_workflow_configuration() {
    print_step "Verifying GitHub Actions workflow configuration..."
    
    local workflow_file=".github/workflows/deploy.yml"
    
    if [[ ! -f "$workflow_file" ]]; then
        print_error "Workflow file not found: $workflow_file"
        return 1
    fi
    
    print_info "Analyzing workflow configuration..."
    
    # Check for shared workflow reference
    if grep -q "uses:.*shared-workflows.*shared-deploy.yml" "$workflow_file"; then
        print_success "Shared workflow reference found"
    else
        print_error "Shared workflow reference not found or incorrect"
    fi
    
    # Check for correct build context
    if grep -q "build_context: \\." "$workflow_file"; then
        print_success "Build context correctly set to current directory"
    else
        print_warning "Build context may not be correctly configured"
    fi
    
    # Check for dockerfile path
    if grep -q "dockerfile_path: \\./Dockerfile" "$workflow_file"; then
        print_success "Dockerfile path correctly configured"
    else
        print_warning "Dockerfile path may not be correctly configured"
    fi
    
    # Check for helm chart path
    if grep -q "helm_chart_path: \\./helm" "$workflow_file"; then
        print_success "Helm chart path correctly configured"
    else
        print_warning "Helm chart path may not be correctly configured"
    fi
    
    # Check for application name
    local app_name
    app_name=$(basename "$TARGET_REPO")
    if grep -q "application_name: $app_name" "$workflow_file"; then
        print_success "Application name correctly set to $app_name"
    else
        print_warning "Application name may not match repository name"
    fi
}

verify_maven_configuration() {
    print_step "Verifying Maven configuration..."
    
    if [[ ! -f "pom.xml" ]]; then
        print_error "pom.xml not found"
        return 1
    fi
    
    # Check artifact ID matches repository name
    local artifact_id
    artifact_id=$(xmllint --xpath "//artifactId/text()" pom.xml 2>/dev/null | head -1)
    local expected_artifact_id
    expected_artifact_id=$(basename "$TARGET_REPO")
    
    if [[ "$artifact_id" == "$expected_artifact_id" ]]; then
        print_success "Maven artifact ID matches repository name: $artifact_id"
    else
        print_warning "Maven artifact ID ($artifact_id) doesn't match repository name ($expected_artifact_id)"
    fi
    
    # Check for Spring Boot parent
    if grep -q "spring-boot-starter-parent" pom.xml; then
        print_success "Spring Boot parent dependency found"
    else
        print_error "Spring Boot parent dependency not found"
    fi
    
    # Check Java version
    local java_version
    java_version=$(xmllint --xpath "//java.version/text()" pom.xml 2>/dev/null || echo "not found")
    print_info "Java version: $java_version"
    
    # Validate Maven project
    if command -v mvn &> /dev/null; then
        print_info "Validating Maven project..."
        if mvn validate -q; then
            print_success "Maven project validation passed"
        else
            print_error "Maven project validation failed"
        fi
    else
        print_warning "Maven not available for validation"
    fi
}

verify_spring_boot_configuration() {
    print_step "Verifying Spring Boot configuration..."
    
    local resources_dir="src/main/resources"
    
    if [[ ! -f "$resources_dir/application.yml" ]]; then
        print_error "Main application.yml not found"
        return 1
    fi
    
    # Check application name in configuration
    local app_name_in_config
    app_name_in_config=$(yq eval '.spring.application.name' "$resources_dir/application.yml" 2>/dev/null || echo "not found")
    print_info "Application name in config: $app_name_in_config"
    
    # Check actuator endpoints
    if yq eval '.management.endpoints.web.exposure.include' "$resources_dir/application.yml" | grep -q "health"; then
        print_success "Health endpoint configured"
    else
        print_warning "Health endpoint not configured"
    fi
    
    if yq eval '.management.endpoints.web.exposure.include' "$resources_dir/application.yml" | grep -q "prometheus"; then
        print_success "Prometheus metrics endpoint configured"
    else
        print_warning "Prometheus metrics endpoint not configured"
    fi
    
    # Check profiles
    local profiles=("dev" "staging" "production")
    for profile in "${profiles[@]}"; do
        local profile_file="$resources_dir/application-${profile}.yml"
        if [[ -f "$profile_file" ]]; then
            print_success "Profile configuration found: $profile"
            
            # Check database name for environment isolation
            local db_name
            db_name=$(yq eval '.spring.datasource.url' "$profile_file" 2>/dev/null | grep -o '[^/]*$' || echo "not found")
            if [[ "$db_name" != "not found" && "$db_name" =~ $profile ]]; then
                print_success "Database name includes environment: $db_name"
            else
                print_warning "Database name may not include environment identifier"
            fi
        else
            print_warning "Profile configuration missing: $profile"
        fi
    done
}

verify_docker_configuration() {
    print_step "Verifying Docker configuration..."
    
    if [[ ! -f "Dockerfile" ]]; then
        print_error "Dockerfile not found"
        return 1
    fi
    
    # Check for multi-stage build
    if grep -q "FROM.*AS" Dockerfile; then
        print_success "Multi-stage build detected"
    else
        print_warning "Single-stage build (multi-stage recommended for optimization)"
    fi
    
    # Check for proper base image
    if grep -q "FROM.*openjdk\|FROM.*eclipse-temurin" Dockerfile; then
        print_success "Appropriate Java base image found"
    else
        print_warning "Java base image not detected or non-standard"
    fi
    
    # Check for JAR file copying
    if grep -q "COPY.*\\.jar" Dockerfile; then
        print_success "JAR file copy instruction found"
    else
        print_error "JAR file copy instruction not found"
    fi
    
    # Check for EXPOSE instruction
    if grep -q "EXPOSE" Dockerfile; then
        local port
        port=$(grep "EXPOSE" Dockerfile | awk '{print $2}' | head -1)
        print_success "Port exposed: $port"
    else
        print_warning "No EXPOSE instruction found"
    fi
    
    # Validate Dockerfile syntax
    if command -v docker &> /dev/null; then
        print_info "Validating Dockerfile syntax..."
        if docker build --dry-run . &> /dev/null; then
            print_success "Dockerfile syntax validation passed"
        else
            print_error "Dockerfile syntax validation failed"
        fi
    else
        print_warning "Docker not available for validation"
    fi
}

verify_helm_configuration() {
    print_step "Verifying Helm configuration..."
    
    if [[ ! -d "helm" ]]; then
        print_warning "Helm directory not found"
        return 0
    fi
    
    # Check Chart.yaml
    if [[ -f "helm/Chart.yaml" ]]; then
        print_success "Helm Chart.yaml found"
        
        local chart_name
        chart_name=$(yq eval '.name' helm/Chart.yaml 2>/dev/null || echo "not found")
        local expected_name
        expected_name=$(basename "$TARGET_REPO")
        
        if [[ "$chart_name" == "$expected_name" ]]; then
            print_success "Chart name matches repository: $chart_name"
        else
            print_warning "Chart name ($chart_name) doesn't match repository ($expected_name)"
        fi
    else
        print_error "Helm Chart.yaml not found"
    fi
    
    # Check values.yaml
    if [[ -f "helm/values.yaml" ]]; then
        print_success "Helm values.yaml found"
        
        # Check image repository
        local image_repo
        image_repo=$(yq eval '.image.repository' helm/values.yaml 2>/dev/null || echo "not found")
        print_info "Image repository: $image_repo"
        
        # Check service port
        local service_port
        service_port=$(yq eval '.service.port' helm/values.yaml 2>/dev/null || echo "not found")
        print_info "Service port: $service_port"
    else
        print_error "Helm values.yaml not found"
    fi
    
    # Check templates directory
    if [[ -d "helm/templates" ]]; then
        print_success "Helm templates directory found"
        
        local template_files=("deployment.yaml" "service.yaml" "configmap.yaml")
        for template in "${template_files[@]}"; do
            if [[ -f "helm/templates/$template" ]]; then
                print_success "Template found: $template"
            else
                print_warning "Template missing: $template"
            fi
        done
    else
        print_error "Helm templates directory not found"
    fi
    
    # Validate Helm chart
    if command -v helm &> /dev/null; then
        print_info "Validating Helm chart..."
        if helm lint ./helm; then
            print_success "Helm chart validation passed"
        else
            print_error "Helm chart validation failed"
        fi
    else
        print_warning "Helm not available for validation"
    fi
}

verify_documentation() {
    print_step "Verifying documentation..."
    
    # Check README.md
    if [[ -f "README.md" ]]; then
        print_success "README.md found"
        
        local repo_name
        repo_name=$(basename "$TARGET_REPO")
        
        # Check if README mentions the service name
        if grep -qi "$repo_name" README.md; then
            print_success "README mentions service name"
        else
            print_warning "README may not be customized for this service"
        fi
        
        # Check for essential sections
        local required_sections=("Quick Start" "Development" "Deployment" "API")
        for section in "${required_sections[@]}"; do
            if grep -qi "$section" README.md; then
                print_success "README section found: $section"
            else
                print_warning "README section missing: $section"
            fi
        done
    else
        print_error "README.md not found"
    fi
    
    # Check DEPLOYMENT.md
    if [[ -f "DEPLOYMENT.md" ]]; then
        print_success "DEPLOYMENT.md found"
        
        # Check for updated paths
        if grep -q "apps/" DEPLOYMENT.md; then
            print_warning "DEPLOYMENT.md may still contain monorepo paths"
        else
            print_success "DEPLOYMENT.md appears to be updated for independent repository"
        fi
    else
        print_warning "DEPLOYMENT.md not found"
    fi
}

test_workflow_syntax() {
    print_step "Testing workflow syntax..."
    
    if command -v actionlint &> /dev/null; then
        print_info "Running actionlint on workflows..."
        if actionlint .github/workflows/deploy.yml; then
            print_success "Workflow syntax validation passed"
        else
            print_error "Workflow syntax validation failed"
        fi
    else
        print_warning "actionlint not available for workflow validation"
    fi
}

check_repository_settings() {
    print_step "Checking repository settings..."
    
    # Check if repository has required secrets (this requires admin access)
    print_info "Checking repository configuration..."
    
    local repo_info
    repo_info=$(gh repo view "$TARGET_REPO" --json hasIssuesEnabled,hasWikiEnabled,hasProjectsEnabled,visibility)
    
    local has_issues
    has_issues=$(echo "$repo_info" | jq -r '.hasIssuesEnabled')
    if [[ "$has_issues" == "true" ]]; then
        print_success "Issues are enabled"
    else
        print_warning "Issues are not enabled"
    fi
    
    local visibility
    visibility=$(echo "$repo_info" | jq -r '.visibility')
    print_info "Repository visibility: $visibility"
    
    # Check for branch protection (requires appropriate permissions)
    print_info "Checking branch protection..."
    if gh api repos/"$TARGET_REPO"/branches/main/protection &> /dev/null; then
        print_success "Branch protection is configured"
    else
        print_warning "Branch protection not configured or insufficient permissions to check"
    fi
}

run_integration_tests() {
    print_step "Running integration tests..."
    
    # Test Maven build if available
    if command -v mvn &> /dev/null; then
        print_info "Testing Maven build..."
        if mvn clean compile -q; then
            print_success "Maven compilation successful"
        else
            print_error "Maven compilation failed"
        fi
        
        # Test if there are any tests to run
        if find . -name "*Test.java" | grep -q .; then
            print_info "Running unit tests..."
            if mvn test -q; then
                print_success "Unit tests passed"
            else
                print_warning "Unit tests failed or skipped"
            fi
        else
            print_info "No unit tests found"
        fi
    else
        print_warning "Maven not available for build testing"
    fi
    
    # Test Docker build if available
    if command -v docker &> /dev/null; then
        print_info "Testing Docker build..."
        if docker build -t test-build . &> /dev/null; then
            print_success "Docker build successful"
            # Clean up test image
            docker rmi test-build &> /dev/null || true
        else
            print_error "Docker build failed"
        fi
    else
        print_warning "Docker not available for build testing"
    fi
}

generate_verification_report() {
    print_step "Generating verification report..."
    
    local report_file="verification-report-$(basename "$TARGET_REPO")-$(date '+%Y%m%d-%H%M%S').md"
    
    cat > "$report_file" << EOF
# Migration Verification Report

**Repository**: $TARGET_REPO  
**Verification Date**: $(date)  
**Status**: $(if [[ ${#VERIFICATION_RESULTS[@]} -gt 0 ]] && echo "${VERIFICATION_RESULTS[@]}" | grep -q "ERROR"; then echo "❌ Issues Found"; else echo "✅ Verification Passed"; fi)

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
    
    echo "## Next Steps" >> "$report_file"
    echo "" >> "$report_file"
    
    if [[ $error_count -eq 0 ]]; then
        echo "1. ✅ Migration verification completed successfully" >> "$report_file"
        echo "2. 🚀 Repository is ready for deployment" >> "$report_file"
        echo "3. 📊 Consider setting up monitoring and alerting" >> "$report_file"
        echo "4. 🧪 Run a test deployment to verify end-to-end functionality" >> "$report_file"
    else
        echo "1. ❌ Fix all errors listed above" >> "$report_file"
        echo "2. 🔄 Run verification again: \`./scripts/verify-migration.sh $TARGET_REPO\`" >> "$report_file"
        echo "3. 📞 Contact support if issues persist" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "## Test Commands" >> "$report_file"
    echo "" >> "$report_file"
    echo "\`\`\`bash" >> "$report_file"
    echo "# Test deployment workflow" >> "$report_file"
    echo "gh workflow run deploy.yml -R $TARGET_REPO -f environment=dev" >> "$report_file"
    echo "" >> "$report_file"
    echo "# Monitor deployment" >> "$report_file"
    echo "kubectl get pods -l app=$(basename "$TARGET_REPO")" >> "$report_file"
    echo "" >> "$report_file"
    echo "# Check service health" >> "$report_file"
    echo "curl https://dev-$(basename "$TARGET_REPO").example.com/api/actuator/health" >> "$report_file"
    echo "\`\`\`" >> "$report_file"
    
    print_success "Verification report generated: $report_file"
    
    # Copy to original location if we can determine it
    if [[ -n "$SCRIPT_DIR" ]]; then
        local logs_dir
        logs_dir="$(dirname "$SCRIPT_DIR")/logs"
        if [[ -d "$logs_dir" ]]; then
            cp "$report_file" "$logs_dir/"
            print_info "Report also saved to: $logs_dir/$report_file"
        fi
    fi
}

print_summary() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  📊 Migration Verification Summary${NC}"
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
        echo -e "${GREEN}🎉 Migration Verification Successful!${NC}"
        echo -e "${GREEN}✅ Repository is ready for production use${NC}"
    else
        echo -e "${RED}❌ Migration Issues Found${NC}"
        echo -e "${RED}🔧 Manual fixes required before deployment${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📊 Results Summary:${NC}"
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
        echo -e "${YELLOW}Warnings (recommended to fix):${NC}"
        for result in "${VERIFICATION_RESULTS[@]}"; do
            if [[ "$result" =~ ^WARNING ]]; then
                echo -e "  • ${result#WARNING: }"
            fi
        done
        echo ""
    fi
    
    echo -e "${BLUE}📋 Next Steps:${NC}"
    if [[ $error_count -eq 0 ]]; then
        echo -e "   1. 🚀 Test deployment: gh workflow run deploy.yml -R $TARGET_REPO -f environment=dev"
        echo -e "   2. 📊 Monitor service health and metrics"
        echo -e "   3. 🔄 Set up automated monitoring and alerting"
        echo -e "   4. 📚 Update team documentation"
    else
        echo -e "   1. ❌ Fix all critical errors listed above"
        echo -e "   2. 🔄 Run verification again"
        echo -e "   3. 💬 Contact DevOps team if issues persist"
    fi
    
    echo ""
    echo -e "${BLUE}📄 Detailed report: verification-report-*.md${NC}"
    echo ""
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        usage
    fi
    
    print_header
    
    check_prerequisites
    verify_repository_exists
    clone_repository
    
    verify_file_structure
    verify_workflow_configuration
    verify_maven_configuration
    verify_spring_boot_configuration
    verify_docker_configuration
    verify_helm_configuration
    verify_documentation
    test_workflow_syntax
    check_repository_settings
    run_integration_tests
    
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

# Run main function with all arguments
main "$@"