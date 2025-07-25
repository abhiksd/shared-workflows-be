#!/bin/bash

# Prerequisites Check Script for Backend Migration
# Validates all required tools, access permissions, and environment setup

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
ISSUES_FOUND=()
WARNINGS_FOUND=()

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  🔍 Migration Prerequisites Checker${NC}"
    echo -e "${BLUE}============================================================${NC}"
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
    WARNINGS_FOUND+=("$1")
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    ISSUES_FOUND+=("$1")
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

check_tool() {
    local tool=$1
    local version_flag=${2:-"--version"}
    local required_version=${3:-""}
    
    if command -v "$tool" &> /dev/null; then
        local version_output
        version_output=$($tool $version_flag 2>&1 | head -1)
        print_success "$tool is installed: $version_output"
        
        if [[ -n "$required_version" ]]; then
            # Extract version number for comparison
            local current_version
            current_version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
            
            if [[ -n "$current_version" ]]; then
                if version_compare "$current_version" "$required_version"; then
                    print_success "$tool version $current_version meets requirement ($required_version+)"
                else
                    print_warning "$tool version $current_version is below recommended $required_version"
                fi
            fi
        fi
    else
        print_error "$tool is not installed or not in PATH"
        case "$tool" in
            "gh")
                echo "  Install: https://cli.github.com/"
                echo "  macOS: brew install gh"
                echo "  Ubuntu: sudo apt install gh"
                ;;
            "git")
                echo "  Install: https://git-scm.com/"
                echo "  macOS: brew install git"
                echo "  Ubuntu: sudo apt install git"
                ;;
            "docker")
                echo "  Install: https://docs.docker.com/get-docker/"
                echo "  macOS: brew install --cask docker"
                echo "  Ubuntu: sudo apt install docker.io"
                ;;
            "mvn")
                echo "  Install: https://maven.apache.org/install.html"
                echo "  macOS: brew install maven"
                echo "  Ubuntu: sudo apt install maven"
                ;;
            "helm")
                echo "  Install: https://helm.sh/docs/intro/install/"
                echo "  macOS: brew install helm"
                echo "  Linux: curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz"
                ;;
        esac
        echo ""
    fi
}

version_compare() {
    local version1=$1
    local version2=$2
    
    # Simple version comparison (major.minor.patch)
    local v1_major v1_minor v1_patch
    local v2_major v2_minor v2_patch
    
    IFS='.' read -r v1_major v1_minor v1_patch <<< "$version1"
    IFS='.' read -r v2_major v2_minor v2_patch <<< "$version2"
    
    # Default patch to 0 if not provided
    v1_patch=${v1_patch:-0}
    v2_patch=${v2_patch:-0}
    
    # Compare versions
    if (( v1_major > v2_major )); then
        return 0
    elif (( v1_major == v2_major )); then
        if (( v1_minor > v2_minor )); then
            return 0
        elif (( v1_minor == v2_minor )); then
            if (( v1_patch >= v2_patch )); then
                return 0
            fi
        fi
    fi
    
    return 1
}

check_required_tools() {
    print_step "Checking required tools..."
    
    check_tool "gh" "--version" "2.0"
    check_tool "git" "--version" "2.25"
    check_tool "docker" "--version" "20.0"
    check_tool "mvn" "--version" "3.6"
    check_tool "helm" "version --short" "3.8"
    
    # Optional but recommended tools
    echo ""
    print_info "Checking optional tools..."
    
    if command -v "actionlint" &> /dev/null; then
        print_success "actionlint is available for workflow validation"
    else
        print_warning "actionlint not found - workflow validation will be skipped"
        echo "  Install: go install github.com/rhymond/actionlint/cmd/actionlint@latest"
    fi
    
    if command -v "kubectl" &> /dev/null; then
        print_success "kubectl is available for Kubernetes operations"
    else
        print_warning "kubectl not found - Kubernetes operations will be limited"
        echo "  Install: https://kubernetes.io/docs/tasks/tools/"
    fi
    
    if command -v "yq" &> /dev/null; then
        print_success "yq is available for YAML processing"
    else
        print_warning "yq not found - YAML processing will use sed instead"
        echo "  Install: brew install yq"
    fi
}

check_github_authentication() {
    print_step "Checking GitHub authentication..."
    
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            local username
            username=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
            print_success "GitHub CLI authenticated as: $username"
            
            # Check permissions
            print_info "Checking GitHub permissions..."
            
            # Try to list organizations
            local orgs
            orgs=$(gh api user/orgs --jq '.[].login' 2>/dev/null || echo "")
            if [[ -n "$orgs" ]]; then
                print_success "Available organizations: $(echo "$orgs" | tr '\n' ', ' | sed 's/,$//')"
            else
                print_warning "No organizations found or limited access"
            fi
            
            # Check if user can create repositories
            if gh repo create --help &> /dev/null; then
                print_success "Repository creation permissions verified"
            else
                print_error "Cannot access repository creation functionality"
            fi
        else
            print_error "GitHub CLI not authenticated"
            echo "  Run: gh auth login"
            echo "  Choose HTTPS for protocol"
            echo "  Authenticate via web browser"
        fi
    else
        print_error "GitHub CLI not installed"
    fi
}

check_docker_access() {
    print_step "Checking Docker access..."
    
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            print_success "Docker daemon is running and accessible"
            
            # Check if user can run docker without sudo
            if docker ps &> /dev/null; then
                print_success "Docker can be run without sudo"
            else
                print_warning "Docker may require sudo - this could cause issues"
                echo "  Add user to docker group: sudo usermod -aG docker \$USER"
                echo "  Then logout and login again"
            fi
            
            # Check available space
            local available_space
            available_space=$(df -h /var/lib/docker 2>/dev/null | awk 'NR==2 {print $4}' || echo "unknown")
            print_info "Docker storage available: $available_space"
            
        else
            print_error "Docker daemon not running or not accessible"
            echo "  Start Docker: sudo systemctl start docker"
            echo "  macOS: Start Docker Desktop"
        fi
    else
        print_error "Docker not installed"
    fi
}

check_maven_setup() {
    print_step "Checking Maven setup..."
    
    if command -v mvn &> /dev/null; then
        # Check Maven version
        local mvn_version
        mvn_version=$(mvn --version | head -1)
        print_success "Maven found: $mvn_version"
        
        # Check Java version
        local java_version
        java_version=$(mvn --version | grep "Java version" | cut -d' ' -f3)
        print_info "Java version used by Maven: $java_version"
        
        # Check Maven settings
        local settings_file
        settings_file="$HOME/.m2/settings.xml"
        if [[ -f "$settings_file" ]]; then
            print_success "Maven settings file found: $settings_file"
        else
            print_info "No custom Maven settings file found (using defaults)"
        fi
        
        # Check local repository
        local repo_size
        repo_size=$(du -sh "$HOME/.m2/repository" 2>/dev/null | cut -f1 || echo "0")
        print_info "Local Maven repository size: $repo_size"
        
    else
        print_error "Maven not installed"
    fi
}

check_workspace_structure() {
    print_step "Checking workspace structure..."
    
    # Check if we're in the correct directory
    if [[ ! -d "$ROOT_DIR/apps" ]]; then
        print_error "apps directory not found - are you in the correct workspace?"
        return 1
    fi
    
    if [[ ! -d "$ROOT_DIR/.github/workflows" ]]; then
        print_error ".github/workflows directory not found"
        return 1
    fi
    
    if [[ ! -d "$ROOT_DIR/.github/actions" ]]; then
        print_error ".github/actions directory not found"
        return 1
    fi
    
    print_success "Workspace structure is correct"
    
    # Check available services
    print_info "Checking available services..."
    local java_services=()
    local nodejs_services=()
    
    for app_dir in "$ROOT_DIR/apps"/*; do
        if [[ -d "$app_dir" ]]; then
            local app_name
            app_name=$(basename "$app_dir")
            
            if [[ -f "$app_dir/pom.xml" ]]; then
                java_services+=("$app_name")
            elif [[ -f "$app_dir/package.json" ]]; then
                nodejs_services+=("$app_name")
            fi
        fi
    done
    
    if [[ ${#java_services[@]} -gt 0 ]]; then
        print_success "Java services found: ${java_services[*]}"
    fi
    
    if [[ ${#nodejs_services[@]} -gt 0 ]]; then
        print_success "Node.js services found: ${nodejs_services[*]}"
    fi
    
    if [[ ${#java_services[@]} -eq 0 && ${#nodejs_services[@]} -eq 0 ]]; then
        print_warning "No recognizable services found in apps directory"
    fi
}

check_service_health() {
    print_step "Checking service configurations..."
    
    # Check each Java service
    for service_dir in "$ROOT_DIR/apps"/java-*; do
        if [[ -d "$service_dir" ]]; then
            local service_name
            service_name=$(basename "$service_dir")
            
            print_info "Checking $service_name..."
            
            # Check Maven project
            cd "$service_dir"
            if mvn validate -q &> /dev/null; then
                print_success "  Maven project is valid"
            else
                print_error "  Maven project validation failed"
            fi
            
            # Check required files
            local required_files=("Dockerfile" "src/main/java" "src/main/resources/application.yml")
            for file in "${required_files[@]}"; do
                if [[ -e "$file" ]]; then
                    print_success "  $file exists"
                else
                    print_warning "  $file missing"
                fi
            done
            
            # Check Spring Boot profiles
            local profiles_dir="src/main/resources"
            local found_profiles=()
            for profile in application-*.yml; do
                if [[ -f "$profiles_dir/$profile" ]]; then
                    found_profiles+=("$profile")
                fi
            done
            
            if [[ ${#found_profiles[@]} -gt 0 ]]; then
                print_success "  Spring Boot profiles: ${found_profiles[*]}"
            else
                print_warning "  No Spring Boot profiles found"
            fi
            
            cd "$ROOT_DIR"
        fi
    done
}

check_helm_setup() {
    print_step "Checking Helm setup..."
    
    if command -v helm &> /dev/null; then
        # Check Helm version
        local helm_version
        helm_version=$(helm version --short 2>/dev/null || echo "unknown")
        print_success "Helm version: $helm_version"
        
        # Check if we can connect to a cluster
        if kubectl cluster-info &> /dev/null; then
            print_success "Kubernetes cluster is accessible"
            
            # Check Helm repositories
            local repos
            repos=$(helm repo list 2>/dev/null | wc -l)
            if [[ $repos -gt 1 ]]; then  # Header line counts as 1
                print_success "Helm repositories configured: $((repos - 1))"
            else
                print_info "No Helm repositories configured (will use local charts)"
            fi
        else
            print_warning "No Kubernetes cluster accessible - Helm operations will be limited"
        fi
        
        # Check for existing Helm charts
        local helm_charts=()
        for chart_dir in "$ROOT_DIR/apps"/*/helm; do
            if [[ -d "$chart_dir" ]]; then
                local service_name
                service_name=$(basename "$(dirname "$chart_dir")")
                helm_charts+=("$service_name")
            fi
        done
        
        if [[ ${#helm_charts[@]} -gt 0 ]]; then
            print_success "Services with Helm charts: ${helm_charts[*]}"
        else
            print_warning "No Helm charts found in services"
        fi
        
    else
        print_error "Helm not installed"
    fi
}

check_network_connectivity() {
    print_step "Checking network connectivity..."
    
    # Check GitHub connectivity
    if curl -s --connect-timeout 5 https://api.github.com/status &> /dev/null; then
        print_success "GitHub API is accessible"
    else
        print_error "Cannot connect to GitHub API"
    fi
    
    # Check Docker Hub connectivity
    if curl -s --connect-timeout 5 https://hub.docker.com &> /dev/null; then
        print_success "Docker Hub is accessible"
    else
        print_warning "Cannot connect to Docker Hub - may affect image pulls"
    fi
    
    # Check if behind corporate proxy
    if [[ -n "$HTTP_PROXY" || -n "$HTTPS_PROXY" ]]; then
        print_info "Corporate proxy detected:"
        [[ -n "$HTTP_PROXY" ]] && echo "  HTTP_PROXY: $HTTP_PROXY"
        [[ -n "$HTTPS_PROXY" ]] && echo "  HTTPS_PROXY: $HTTPS_PROXY"
    fi
}

check_disk_space() {
    print_step "Checking disk space..."
    
    local available_space
    available_space=$(df -h "$ROOT_DIR" | awk 'NR==2 {print $4}')
    print_info "Available disk space: $available_space"
    
    # Extract numeric value for comparison
    local space_gb
    space_gb=$(echo "$available_space" | sed 's/G.*//' | sed 's/[^0-9.]//g')
    
    if [[ -n "$space_gb" ]]; then
        if (( $(echo "$space_gb > 5" | bc -l 2>/dev/null || echo "1") )); then
            print_success "Sufficient disk space available"
        else
            print_warning "Low disk space - migration may fail"
        fi
    fi
    
    # Check temp directory space
    local temp_space
    temp_space=$(df -h /tmp | awk 'NR==2 {print $4}')
    print_info "Temporary directory space: $temp_space"
}

generate_prerequisite_report() {
    print_step "Generating prerequisite report..."
    
    local report_file="prerequisite-check-$(date '+%Y%m%d-%H%M%S').md"
    
    cat > "$report_file" << EOF
# Migration Prerequisites Check Report

**Date**: $(date)  
**Workspace**: $ROOT_DIR

## Summary

EOF
    
    if [[ ${#ISSUES_FOUND[@]} -eq 0 ]]; then
        echo "✅ **Status**: All prerequisites met - migration can proceed" >> "$report_file"
    else
        echo "❌ **Status**: Issues found - resolve before migration" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "- **Issues Found**: ${#ISSUES_FOUND[@]}" >> "$report_file"
    echo "- **Warnings**: ${#WARNINGS_FOUND[@]}" >> "$report_file"
    echo "" >> "$report_file"
    
    if [[ ${#ISSUES_FOUND[@]} -gt 0 ]]; then
        echo "## ❌ Issues That Must Be Resolved" >> "$report_file"
        echo "" >> "$report_file"
        for issue in "${ISSUES_FOUND[@]}"; do
            echo "- $issue" >> "$report_file"
        done
        echo "" >> "$report_file"
    fi
    
    if [[ ${#WARNINGS_FOUND[@]} -gt 0 ]]; then
        echo "## ⚠️ Warnings" >> "$report_file"
        echo "" >> "$report_file"
        for warning in "${WARNINGS_FOUND[@]}"; do
            echo "- $warning" >> "$report_file"
        done
        echo "" >> "$report_file"
    fi
    
    echo "## Next Steps" >> "$report_file"
    echo "" >> "$report_file"
    
    if [[ ${#ISSUES_FOUND[@]} -eq 0 ]]; then
        echo "1. ✅ All prerequisites are met" >> "$report_file"
        echo "2. 🚀 You can proceed with migration using:" >> "$report_file"
        echo "   \`./scripts/migrate-java-service.sh <service-name> <org/repo-name>\`" >> "$report_file"
        echo "3. 📚 Review the migration guide: BACKEND_MIGRATION_COMPREHENSIVE_GUIDE.md" >> "$report_file"
    else
        echo "1. ❌ Resolve all critical issues listed above" >> "$report_file"
        echo "2. 🔄 Run this check again: \`./scripts/check-migration-prerequisites.sh\`" >> "$report_file"
        echo "3. 📚 Refer to installation guides in the tool-specific sections above" >> "$report_file"
    fi
    
    print_success "Report generated: $report_file"
    
    # Copy to logs directory
    mkdir -p "$ROOT_DIR/logs"
    cp "$report_file" "$ROOT_DIR/logs/"
    rm "$report_file"
}

print_summary() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  📊 Prerequisites Check Summary${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
    
    if [[ ${#ISSUES_FOUND[@]} -eq 0 ]]; then
        echo -e "${GREEN}🎉 All Prerequisites Met!${NC}"
        echo -e "${GREEN}✅ Migration can proceed safely${NC}"
        echo ""
        echo -e "${BLUE}Next Steps:${NC}"
        echo -e "1. 📚 Review: BACKEND_MIGRATION_COMPREHENSIVE_GUIDE.md"
        echo -e "2. 🚀 Start migration: ./scripts/migrate-java-service.sh java-backend1 org/repo-name"
        echo -e "3. 🔍 Monitor progress in logs/ directory"
    else
        echo -e "${RED}❌ Issues Found: ${#ISSUES_FOUND[@]}${NC}"
        echo -e "${YELLOW}⚠️  Warnings: ${#WARNINGS_FOUND[@]}${NC}"
        echo ""
        echo -e "${RED}Critical Issues to Resolve:${NC}"
        for issue in "${ISSUES_FOUND[@]}"; do
            echo -e "  • $issue"
        done
        echo ""
        echo -e "${BLUE}Next Steps:${NC}"
        echo -e "1. ❌ Resolve all critical issues above"
        echo -e "2. 🔄 Run this check again"
        echo -e "3. 📞 Contact support if needed"
    fi
    
    if [[ ${#WARNINGS_FOUND[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Warnings (can proceed but recommend fixing):${NC}"
        for warning in "${WARNINGS_FOUND[@]}"; do
            echo -e "  • $warning"
        done
    fi
    
    echo ""
    echo -e "${BLUE}📄 Detailed report: logs/prerequisite-check-*.md${NC}"
    echo ""
}

# Main execution
main() {
    print_header
    
    check_required_tools
    echo ""
    
    check_github_authentication
    echo ""
    
    check_docker_access
    echo ""
    
    check_maven_setup
    echo ""
    
    check_workspace_structure
    echo ""
    
    check_service_health
    echo ""
    
    check_helm_setup
    echo ""
    
    check_network_connectivity
    echo ""
    
    check_disk_space
    echo ""
    
    generate_prerequisite_report
    print_summary
    
    # Exit with appropriate code
    if [[ ${#ISSUES_FOUND[@]} -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"