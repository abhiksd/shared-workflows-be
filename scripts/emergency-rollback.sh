#!/bin/bash
set -e

# Emergency Rollback Script for My App Blue-Green Deployment
# Usage: ./scripts/emergency-rollback.sh [environment]

ENVIRONMENT=${1:-"prod"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Application configuration
APP_NAME="my-app"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
🚨 Emergency Rollback Script for My App

Usage: $0 [ENVIRONMENT]

Environments:
  dev       Development environment (rolling rollback)
  sqe       System Quality Engineering (rolling rollback)
  ppr       Pre-production environment (Blue-Green rollback)
  prod      Production environment (Blue-Green rollback)

This script performs immediate rollback without safety checks.
Use only in emergency situations.

Examples:
  $0 prod                    # Emergency rollback production
  $0 ppr                     # Emergency rollback pre-production
  $0 --help                  # Show this help

⚠️  WARNING: This is an emergency script that bypasses safety checks!
EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to Kubernetes
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get current active slot
get_active_slot() {
    local env=$1
    local namespace_prefix="${env}-${APP_NAME}"
    
    # Check if Blue-Green is enabled for this environment
    if [[ "$env" == "ppr" || "$env" == "prod" ]]; then
        # Check ingress to see which slot is active
        local active_ns=$(kubectl get ingress ${APP_NAME}-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.namespace}' 2>/dev/null || echo "")
        
        if [[ "$active_ns" == "${namespace_prefix}-blue" ]]; then
            echo "blue"
        elif [[ "$active_ns" == "${namespace_prefix}-green" ]]; then
            echo "green"
        else
            echo "unknown"
        fi
    else
        echo "none"  # Non Blue-Green environments
    fi
}

# Get inactive slot
get_inactive_slot() {
    local active_slot=$1
    
    if [[ "$active_slot" == "blue" ]]; then
        echo "green"
    elif [[ "$active_slot" == "green" ]]; then
        echo "blue"
    else
        echo "unknown"
    fi
}

# Perform Blue-Green emergency rollback
perform_blue_green_rollback() {
    local env=$1
    local active_slot=$2
    local inactive_slot=$3
    local namespace_prefix="${env}-${APP_NAME}"
    local inactive_namespace="${namespace_prefix}-${inactive_slot}"
    
    log_warn "🚨 EMERGENCY BLUE-GREEN ROLLBACK"
    log_info "Environment: $env"
    log_info "Current active slot: $active_slot"
    log_info "Rolling back to: $inactive_slot"
    log_info "Target namespace: $inactive_namespace"
    
    # Check if inactive namespace exists and has deployments
    if ! kubectl get namespace "$inactive_namespace" &> /dev/null; then
        log_error "Inactive namespace $inactive_namespace does not exist"
        exit 1
    fi
    
    local pod_count=$(kubectl get pods -n "$inactive_namespace" --no-headers 2>/dev/null | wc -l)
    if [[ $pod_count -eq 0 ]]; then
        log_error "No pods found in inactive namespace $inactive_namespace"
        exit 1
    fi
    
    # Quick health check on inactive slot
    local ready_pods=$(kubectl get pods -n "$inactive_namespace" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    if [[ $ready_pods -eq 0 ]]; then
        log_error "No running pods found in inactive namespace $inactive_namespace"
        exit 1
    fi
    
    log_info "Found $ready_pods running pods in $inactive_namespace"
    
    # Determine ingress host
    local ingress_host
    if [[ "$env" == "ppr" ]]; then
        ingress_host="preprod.mydomain.com"
    else
        ingress_host="api.mydomain.com"
    fi
    
    # Immediate traffic switch
    log_info "🔄 Switching traffic to $inactive_slot slot..."
    kubectl patch ingress ${APP_NAME}-ingress -n default --type='merge' \
        -p='{"spec":{"rules":[{"host":"'${ingress_host}'","http":{"paths":[{"path":"/(my-app/|$)(.*)","pathType":"ImplementationSpecific","backend":{"service":{"name":"'${APP_NAME}'","namespace":"'${inactive_namespace}'","port":{"number":8280}}}}]}}]}}'
    
    if [[ $? -eq 0 ]]; then
        log_success "✅ Traffic switched to $inactive_slot slot"
    else
        log_error "❌ Failed to switch traffic"
        exit 1
    fi
    
    # Update active slot label
    kubectl label ingress ${APP_NAME}-ingress -n default active-slot=${inactive_slot} --overwrite
    
    log_success "🎯 Emergency rollback completed successfully"
    log_info "Active slot is now: $inactive_slot"
    log_info "Namespace: $inactive_namespace"
}

# Perform rolling deployment rollback
perform_rolling_rollback() {
    local env=$1
    local namespace="default"
    
    if [[ "$env" == "dev" ]]; then
        namespace="dev-${APP_NAME}"
    elif [[ "$env" == "sqe" ]]; then
        namespace="sqe-${APP_NAME}"
    fi
    
    log_warn "🚨 EMERGENCY ROLLING ROLLBACK"
    log_info "Environment: $env"
    log_info "Namespace: $namespace"
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_error "Namespace $namespace does not exist"
        exit 1
    fi
    
    # Get deployment
    if ! kubectl get deployment ${APP_NAME} -n "$namespace" &> /dev/null; then
        log_error "Deployment ${APP_NAME} not found in namespace $namespace"
        exit 1
    fi
    
    # Rollback to previous revision
    log_info "🔄 Rolling back deployment to previous revision..."
    kubectl rollout undo deployment/${APP_NAME} -n "$namespace"
    
    if [[ $? -eq 0 ]]; then
        log_success "✅ Rollback initiated"
    else
        log_error "❌ Failed to initiate rollback"
        exit 1
    fi
    
    # Wait for rollback to complete
    log_info "⏳ Waiting for rollback to complete..."
    kubectl rollout status deployment/${APP_NAME} -n "$namespace" --timeout=300s
    
    if [[ $? -eq 0 ]]; then
        log_success "🎯 Emergency rollback completed successfully"
    else
        log_error "❌ Rollback timed out or failed"
        exit 1
    fi
}

# Validate rollback
validate_rollback() {
    local env=$1
    
    log_info "🔍 Validating rollback..."
    
    if [[ "$env" == "ppr" || "$env" == "prod" ]]; then
        # Blue-Green validation
        local active_slot=$(get_active_slot "$env")
        local namespace="${env}-${APP_NAME}-${active_slot}"
        
        log_info "Checking health of active slot: $active_slot"
        log_info "Namespace: $namespace"
        
        # Check pod status
        local ready_pods=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        log_info "Running pods: $ready_pods"
        
        # Quick health check
        local pod_name=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -n "$pod_name" ]]; then
            log_info "Testing health endpoint..."
            if kubectl exec -n "$namespace" "$pod_name" -- curl -f http://localhost:8280/my-app/actuator/health &> /dev/null; then
                log_success "✅ Health check passed"
            else
                log_warn "⚠️ Health check failed - manual verification needed"
            fi
        fi
    else
        # Rolling deployment validation
        local namespace="default"
        if [[ "$env" == "dev" ]]; then
            namespace="dev-${APP_NAME}"
        elif [[ "$env" == "sqe" ]]; then
            namespace="sqe-${APP_NAME}"
        fi
        
        log_info "Checking deployment status in namespace: $namespace"
        
        # Check deployment status
        local ready_replicas=$(kubectl get deployment ${APP_NAME} -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment ${APP_NAME} -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        log_info "Ready replicas: $ready_replicas/$desired_replicas"
        
        if [[ "$ready_replicas" == "$desired_replicas" && "$ready_replicas" -gt 0 ]]; then
            log_success "✅ Deployment is healthy"
        else
            log_warn "⚠️ Deployment may not be fully healthy - manual verification needed"
        fi
    fi
}

# Main execution
main() {
    echo "🚨 EMERGENCY ROLLBACK FOR MY APP"
    echo "================================="
    echo ""
    
    # Parse arguments
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(dev|sqe|ppr|prod)$ ]]; then
        log_error "Invalid environment: $ENVIRONMENT"
        log_info "Valid environments: dev, sqe, ppr, prod"
        exit 1
    fi
    
    log_warn "⚠️  EMERGENCY ROLLBACK MODE ACTIVATED"
    log_warn "Environment: $ENVIRONMENT"
    echo ""
    
    # Confirmation prompt
    echo -e "${RED}WARNING: This will perform an immediate rollback bypassing safety checks!${NC}"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Operation cancelled"
        exit 0
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Perform rollback based on environment
    if [[ "$ENVIRONMENT" == "ppr" || "$ENVIRONMENT" == "prod" ]]; then
        # Blue-Green rollback
        local active_slot=$(get_active_slot "$ENVIRONMENT")
        
        if [[ "$active_slot" == "unknown" ]]; then
            log_error "Cannot determine active slot for environment $ENVIRONMENT"
            exit 1
        fi
        
        local inactive_slot=$(get_inactive_slot "$active_slot")
        
        if [[ "$inactive_slot" == "unknown" ]]; then
            log_error "Cannot determine inactive slot"
            exit 1
        fi
        
        perform_blue_green_rollback "$ENVIRONMENT" "$active_slot" "$inactive_slot"
    else
        # Rolling deployment rollback
        perform_rolling_rollback "$ENVIRONMENT"
    fi
    
    # Validate rollback
    validate_rollback "$ENVIRONMENT"
    
    echo ""
    log_success "🎯 Emergency rollback completed for $ENVIRONMENT environment"
    log_info "Please monitor the application and perform additional verification as needed"
}

# Execute main function
main "$@"