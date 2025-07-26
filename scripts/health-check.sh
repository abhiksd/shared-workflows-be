#!/bin/bash

# Health Check Script for My App Blue-Green Deployment
# Usage: ./scripts/health-check.sh [namespace] [timeout]

NAMESPACE=${1:-"prod-my-app-blue"}
MAX_RETRIES=${2:-30}
RETRY_INTERVAL=10
APP_NAME="my-app"

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
🔍 Health Check Script for My App

Usage: $0 [NAMESPACE] [MAX_RETRIES]

Parameters:
  NAMESPACE     Kubernetes namespace to check (default: prod-my-app-blue)
  MAX_RETRIES   Maximum number of health check attempts (default: 30)

Examples:
  $0                                          # Check blue namespace with default retries
  $0 prod-my-app-green                 # Check green namespace
  $0 prod-my-app-blue 60              # Check blue namespace with 60 retries
  $0 --help                                   # Show this help

Health Checks Performed:
  1. Pod readiness status
  2. Pod restart count
  3. Spring Boot actuator health endpoint
  4. Application version verification
  5. Resource usage monitoring

Environment Options:
  prod-my-app-blue     Production blue namespace
prod-my-app-green    Production green namespace
sqe-my-app          SQE environment
ppr-my-app          Pre-production environment
dev-my-app          Development environment
EOF
}

# Check if help requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        echo "Install it from: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    # Check if jq is installed (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed - some features will be limited"
        echo "Install it with: sudo apt-get install jq (Ubuntu) or brew install jq (macOS)"
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        echo "Ensure kubectl is configured and you have access to the cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Check if namespace exists
check_namespace() {
    log_info "Checking namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_success "Namespace $NAMESPACE exists"
        return 0
    else
        log_error "Namespace $NAMESPACE does not exist"
        
        # Show available namespaces
        echo ""
        echo "Available namespaces:"
        kubectl get namespaces | grep -E "(NAME|my-app|default)"
        
        return 1
    fi
}

# Get pod information
get_pod_info() {
    local pods_json
    pods_json=$(kubectl get pods -n "$NAMESPACE" -l app="$APP_NAME" -o json 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get pod information"
        return 1
    fi
    
    # Extract pod information
    TOTAL_PODS=$(echo "$pods_json" | jq '.items | length' 2>/dev/null || echo "0")
    READY_PODS=$(echo "$pods_json" | jq '[.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="True"))] | length' 2>/dev/null || echo "0")
    RUNNING_PODS=$(echo "$pods_json" | jq '[.items[] | select(.status.phase=="Running")] | length' 2>/dev/null || echo "0")
    
    return 0
}

# Check pod health
check_pod_health() {
    local attempt=$1
    
    echo ""
    log_info "Health check attempt $attempt/$MAX_RETRIES for namespace: $NAMESPACE"
    echo "$(date)"
    echo "----------------------------------------"
    
    # Get pod information
    if ! get_pod_info; then
        return 1
    fi
    
    # Display pod status
    echo "📊 Pod Status Summary:"
    echo "  Total Pods: $TOTAL_PODS"
    echo "  Running Pods: $RUNNING_PODS"
    echo "  Ready Pods: $READY_PODS"
    
    # Check if we have any pods
    if [[ "$TOTAL_PODS" -eq 0 ]]; then
        log_warning "No pods found in namespace $NAMESPACE"
        echo "Checking for deployment..."
        kubectl get deployment -n "$NAMESPACE" 2>/dev/null || echo "No deployments found"
        return 1
    fi
    
    # Display detailed pod information
    echo ""
    echo "📋 Detailed Pod Information:"
    kubectl get pods -n "$NAMESPACE" -l app="$APP_NAME" -o wide
    
    # Check for pod issues
    echo ""
    echo "🔍 Pod Events (last 10):"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' --field-selector involvedObject.kind=Pod | tail -10
    
    # Check if all pods are ready
    if [[ "$READY_PODS" -eq "$TOTAL_PODS" ]] && [[ "$TOTAL_PODS" -gt 0 ]]; then
        log_success "All pods are ready ($READY_PODS/$TOTAL_PODS)"
        
        # Test application health endpoint
        check_application_health
        return $?
    else
        log_warning "Not all pods are ready ($READY_PODS/$TOTAL_PODS ready, $RUNNING_PODS/$TOTAL_PODS running)"
        
        # Show problematic pods
        echo ""
        echo "🔍 Problematic Pods:"
        kubectl get pods -n "$NAMESPACE" -l app="$APP_NAME" --field-selector=status.phase!=Running
        
        return 1
    fi
}

# Check application health endpoint
check_application_health() {
    log_info "Testing application health endpoints..."
    
    # Get a running pod
    local pod_name
    pod_name=$(kubectl get pods -n "$NAMESPACE" -l app="$APP_NAME" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$pod_name" ]]; then
        log_error "No running pods found to test health endpoint"
        return 1
    fi
    
    echo "Testing pod: $pod_name"
    
    # Test health endpoint
    local health_status
    health_status=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s -f http://localhost:8280/my-app/actuator/health 2>/dev/null | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
    
    echo "  Health Status: $health_status"
    
    # Test readiness endpoint
    local readiness_status
    readiness_status=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s -f http://localhost:8280/my-app/actuator/health/readiness 2>/dev/null | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
    
    echo "  Readiness Status: $readiness_status"
    
    # Test liveness endpoint
    local liveness_status
    liveness_status=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s -f http://localhost:8280/my-app/actuator/health/liveness 2>/dev/null | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
    
    echo "  Liveness Status: $liveness_status"
    
    # Get application info
    local app_version
    app_version=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s http://localhost:8280/my-app/actuator/info 2>/dev/null | jq -r '.build.version // .git.commit.id // "unknown"' 2>/dev/null || echo "unknown")
    
    echo "  Application Version: $app_version"
    
    # Check if health is UP
    if [[ "$health_status" == "UP" ]]; then
        log_success "Application health check passed"
        
        # Additional checks
        check_resource_usage "$pod_name"
        
        return 0
    else
        log_error "Application health check failed (status: $health_status)"
        
        # Show application logs for debugging
        echo ""
        echo "🔍 Recent application logs:"
        kubectl logs -n "$NAMESPACE" "$pod_name" --tail=20
        
        return 1
    fi
}

# Check resource usage
check_resource_usage() {
    local pod_name=$1
    
    log_info "Checking resource usage for pod: $pod_name"
    
    # Get pod metrics if metrics server is available
    local metrics_output
    metrics_output=$(kubectl top pod -n "$NAMESPACE" "$pod_name" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        echo "📊 Resource Usage:"
        echo "$metrics_output"
    else
        log_warning "Metrics server not available - skipping resource usage check"
    fi
    
    # Check pod resource limits and requests
    echo ""
    echo "📊 Resource Limits and Requests:"
    kubectl get pod -n "$NAMESPACE" "$pod_name" -o jsonpath='{.spec.containers[0].resources}' | jq '.' 2>/dev/null || echo "No resource limits/requests defined"
}

# Show final summary
show_summary() {
    local final_status=$1
    
    echo ""
    echo "========================================"
    echo "📊 Health Check Summary"
    echo "========================================"
    echo "Namespace: $NAMESPACE"
    echo "Application: $APP_NAME"
    echo "Check Duration: $((SECONDS))s"
    echo "Attempts Made: $attempt_count"
    
    if [[ $final_status -eq 0 ]]; then
        log_success "Health check PASSED - Application is healthy and ready"
        echo ""
        echo "✅ All pods are running and ready"
        echo "✅ Application health endpoints responding"
        echo "✅ Application is serving traffic"
    else
        log_error "Health check FAILED - Application is not healthy"
        echo ""
        echo "❌ Some pods may not be ready"
        echo "❌ Application health endpoints may be failing"
        echo "❌ Application may not be ready to serve traffic"
        
        # Provide troubleshooting tips
        echo ""
        echo "🛠️  Troubleshooting tips:"
        echo "  1. Check pod logs: kubectl logs -n $NAMESPACE -l app=$APP_NAME"
        echo "  2. Describe pods: kubectl describe pods -n $NAMESPACE -l app=$APP_NAME"
        echo "  3. Check events: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
        echo "  4. Verify deployment: kubectl get deployment -n $NAMESPACE"
    fi
}

# Main execution
main() {
    echo "🔍 My App Health Check"
    echo "=============================="
    echo ""
    
    # Track start time
    SECONDS=0
    attempt_count=0
    
    # Run checks
    check_prerequisites
    
    if ! check_namespace; then
        exit 1
    fi
    
    echo ""
    log_info "Starting health check monitoring..."
    echo "Namespace: $NAMESPACE"
    echo "Max Attempts: $MAX_RETRIES"
    echo "Retry Interval: ${RETRY_INTERVAL}s"
    echo ""
    
    # Health check loop
    for i in $(seq 1 $MAX_RETRIES); do
        attempt_count=$i
        
        if check_pod_health $i; then
            show_summary 0
            exit 0
        fi
        
        if [[ $i -lt $MAX_RETRIES ]]; then
            log_warning "Health check failed, retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
    done
    
    # All attempts failed
    show_summary 1
    exit 1
}

# Run main function
main "$@"