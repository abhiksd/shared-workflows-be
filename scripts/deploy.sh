#!/bin/bash
set -e

# Blue-Green Deployment Script for My App
# Usage: ./scripts/deploy.sh [environment] [force_deploy]

ENVIRONMENT=${1:-"dev"}
FORCE_DEPLOY=${2:-"false"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Help function
show_help() {
    cat << EOF
🚀 Blue-Green Deployment Script for My App

Usage: $0 [ENVIRONMENT] [FORCE_DEPLOY]

Environments:
  dev       Development environment (rolling deployment)
  sqe       System Quality Engineering (rolling deployment)  
  ppr       Pre-production (rolling deployment)
  prod      Production (Blue-Green + Canary deployment)

Options:
  FORCE_DEPLOY  true/false - Deploy even if no changes detected (default: false)

Examples:
  $0 dev                    # Deploy to development
  $0 prod                   # Deploy to production with Blue-Green
  $0 prod true              # Force deploy to production
  $0 --help                 # Show this help

Prerequisites:
  - GitHub CLI (gh) installed and authenticated
  - Git repository with proper branches/tags
  - Access to GitHub Actions workflows

Environment Strategy:
  dev  ← develop branch (automatic)
  sqe  ← main branch (automatic)
  ppr  ← release/* branches (automatic)
  prod ← tags (manual approval + Blue-Green)
EOF
}

# Check if help requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Validate environment
validate_environment() {
    case $ENVIRONMENT in
        dev|sqe|ppr|prod)
            log_success "Valid environment: $ENVIRONMENT"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT"
            echo "Valid options: dev, sqe, ppr, prod"
            echo "Use --help for more information"
            exit 1
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    # Check if authenticated with GitHub
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI"
        echo "Run: gh auth login"
        exit 1
    fi
    
    # Check if in git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get deployment strategy info
get_deployment_info() {
    case $ENVIRONMENT in
        dev)
            echo "🔄 Rolling deployment to development environment"
            echo "📋 Triggered by: develop branch"
            ;;
        sqe)
            echo "🔄 Rolling deployment to SQE environment"
            echo "📋 Triggered by: main branch"
            ;;
        ppr)
            echo "🔄 Rolling deployment to pre-production environment"
            echo "📋 Triggered by: release/* branches"
            ;;
        prod)
            echo "🛡️  Blue-Green + Canary deployment to production"
            echo "📋 Triggered by: tags (requires manual approval)"
            echo "⚠️  This will require manual approval in GitHub Actions"
            ;;
    esac
}

# Trigger deployment
trigger_deployment() {
    log_info "Triggering GitHub Actions workflow..."
    
    # Build workflow run command
    local cmd="gh workflow run deploy.yml -f environment=$ENVIRONMENT"
    
    if [[ "$FORCE_DEPLOY" == "true" ]]; then
        cmd="$cmd -f force_deploy=true"
        log_warning "Force deployment enabled - will deploy even if no changes detected"
    fi
    
    # Execute deployment
    if eval $cmd; then
        log_success "Deployment triggered successfully!"
        
        # Get workflow run URL
        sleep 2  # Wait a moment for the run to be created
        local run_url=$(gh run list --workflow=deploy.yml --limit=1 --json url --jq '.[0].url')
        
        if [[ -n "$run_url" ]]; then
            log_info "Monitor progress: $run_url"
        else
            log_info "Monitor progress in GitHub Actions tab"
        fi
        
        # Show environment-specific next steps
        show_next_steps
        
    else
        log_error "Failed to trigger deployment"
        exit 1
    fi
}

# Show next steps based on environment
show_next_steps() {
    echo ""
    log_info "Next steps:"
    
    case $ENVIRONMENT in
        dev|sqe|ppr)
            echo "  1. Monitor the deployment in GitHub Actions"
            echo "  2. Wait for quality gates to pass (SonarQube, Checkmarx)"
            echo "  3. Verify deployment success in the environment"
            ;;
        prod)
            echo "  1. Monitor the deployment in GitHub Actions"
            echo "  2. Wait for quality gates to pass (SonarQube, Checkmarx)"
            echo "  3. ⚠️  MANUAL APPROVAL REQUIRED - Check GitHub Actions for approval request"
            echo "  4. After approval, monitor Blue-Green canary deployment"
            echo "  5. Traffic will gradually shift: 5% → 10% → 25% → 50% → 100%"
            echo "  6. Verify production deployment success"
            echo ""
            log_warning "Production deployment requires manual approval!"
            echo "Navigate to GitHub Actions and approve when ready."
            ;;
    esac
    
    echo ""
    echo "📊 Useful commands:"
    echo "  gh run list --workflow=deploy.yml           # List recent runs"
    echo "  gh run watch                                # Watch current run"
    echo "  ./scripts/monitor-deployment.sh             # Monitor Blue-Green status"
    echo "  ./scripts/health-check.sh                   # Check application health"
}

# Main execution
main() {
    echo "🚀 Blue-Green Deployment Script"
    echo "==============================="
    echo ""
    
    # Run checks
    validate_environment
    check_prerequisites
    
    echo ""
    log_info "Deployment Configuration:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Force Deploy: $FORCE_DEPLOY"
    echo ""
    
    # Show deployment info
    get_deployment_info
    echo ""
    
    # Confirm for production
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        log_warning "You are about to deploy to PRODUCTION"
        echo "This will trigger a Blue-Green deployment with manual approval."
        echo ""
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled"
            exit 0
        fi
        echo ""
    fi
    
    # Trigger deployment
    trigger_deployment
}

# Run main function
main "$@"