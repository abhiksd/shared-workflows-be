#!/bin/bash

# Blue-Green Deployment Monitoring Script
# Usage: ./scripts/monitor-deployment.sh [refresh_interval]

REFRESH_INTERVAL=${1:-5}
APP_NAME="my-app"
DOMAIN=${DOMAIN:-"api.mydomain.com"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Emojis for better visualization
BLUE_CIRCLE="🔵"
GREEN_CIRCLE="🟢"
RED_CIRCLE="🔴"
YELLOW_CIRCLE="🟡"

# Help function
show_help() {
    cat << EOF
📊 Blue-Green Deployment Monitoring Script

Usage: $0 [REFRESH_INTERVAL]

Parameters:
  REFRESH_INTERVAL    Seconds between status updates (default: 5)

Examples:
  $0                  # Monitor with 5-second refresh
  $0 10               # Monitor with 10-second refresh
  $0 --help           # Show this help

Environment Variables:
  DOMAIN              Application domain (default: api.mydomain.com)

What This Script Monitors:
  ✅ Blue and Green namespace pod status
  ✅ Active ingress routing
  ✅ Canary traffic weight
  ✅ Application health status
  ✅ GitHub Actions workflow status
  ✅ Resource usage (if metrics server available)

Controls:
  Ctrl+C              Stop monitoring
  'q' + Enter         Quit monitoring
  'r' + Enter         Force refresh

Namespaces Monitored:
  - prod-my-app-blue
- prod-my-app-green
  - Default namespace (for ingress)
EOF
}

# Check if help requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    # Check required tools
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    # Check optional tools
    local optional_missing=()
    if ! command -v jq &> /dev/null; then
        optional_missing+=("jq")
    fi
    
    if ! command -v gh &> /dev/null; then
        optional_missing+=("gh (GitHub CLI)")
    fi
    
    # Report missing required tools
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing required tools: ${missing_tools[*]}${NC}"
        exit 1
    fi
    
    # Report missing optional tools
    if [[ ${#optional_missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Missing optional tools: ${optional_missing[*]}${NC}"
        echo "Some features will be limited."
        sleep 2
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
        echo "Ensure kubectl is configured properly"
        exit 1
    fi
}

# Get namespace status
get_namespace_status() {
    local namespace=$1
    local result=""
    
    if kubectl get namespace "$namespace" &> /dev/null; then
        local total_pods=$(kubectl get pods -n "$namespace" -l app="$APP_NAME" --no-headers 2>/dev/null | wc -l)
        local ready_pods=$(kubectl get pods -n "$namespace" -l app="$APP_NAME" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        local pending_pods=$(kubectl get pods -n "$namespace" -l app="$APP_NAME" --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
        
        if [[ $total_pods -eq 0 ]]; then
            result="${YELLOW_CIRCLE} No pods"
        elif [[ $ready_pods -eq $total_pods ]]; then
            result="${GREEN_CIRCLE} $ready_pods/$total_pods ready"
        elif [[ $pending_pods -gt 0 ]]; then
            result="${YELLOW_CIRCLE} $ready_pods/$total_pods ready, $pending_pods pending"
        else
            result="${RED_CIRCLE} $ready_pods/$total_pods ready"
        fi
    else
        result="${RED_CIRCLE} Namespace not found"
    fi
    
    echo "$result"
}

# Get pod details for namespace
get_pod_details() {
    local namespace=$1
    
    if kubectl get namespace "$namespace" &> /dev/null; then
        kubectl get pods -n "$namespace" -l app="$APP_NAME" --no-headers 2>/dev/null | while read -r line; do
            if [[ -n "$line" ]]; then
                local pod_name=$(echo "$line" | awk '{print $1}')
                local ready=$(echo "$line" | awk '{print $2}')
                local status=$(echo "$line" | awk '{print $3}')
                local restarts=$(echo "$line" | awk '{print $4}')
                local age=$(echo "$line" | awk '{print $5}')
                
                local status_icon=""
                case $status in
                    "Running")
                        if [[ "$ready" == "1/1" ]]; then
                            status_icon="${GREEN_CIRCLE}"
                        else
                            status_icon="${YELLOW_CIRCLE}"
                        fi
                        ;;
                    "Pending")
                        status_icon="${YELLOW_CIRCLE}"
                        ;;
                    *)
                        status_icon="${RED_CIRCLE}"
                        ;;
                esac
                
                echo "    $status_icon $pod_name ($ready) - $status - Restarts: $restarts - Age: $age"
            fi
        done
    else
        echo "    ${RED_CIRCLE} Namespace not found"
    fi
}

# Get ingress status
get_ingress_status() {
    local main_ingress_ns=""
    local canary_weight="0"
    local canary_enabled="false"
    
    # Check main ingress
    if kubectl get ingress my-app-ingress -n default &> /dev/null; then
        main_ingress_ns=$(kubectl get ingress my-app-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.namespace}' 2>/dev/null || echo "unknown")
    fi
    
    # Check canary ingress
    if kubectl get ingress my-app-ingress-canary -n default &> /dev/null; then
        canary_weight=$(kubectl get ingress my-app-ingress-canary -n default -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}' 2>/dev/null || echo "0")
        local canary_annotation=$(kubectl get ingress my-app-ingress-canary -n default -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary}' 2>/dev/null || echo "false")
        if [[ "$canary_annotation" == "true" ]]; then
            canary_enabled="true"
        fi
    fi
    
    echo "$main_ingress_ns|$canary_weight|$canary_enabled"
}

# Get application health
get_app_health() {
    local namespace=$1
    local health_status="UNKNOWN"
    local response_time="N/A"
    
    # Try to get health from a running pod
    local pod_name=$(kubectl get pods -n "$namespace" -l app="$APP_NAME" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -n "$pod_name" ]]; then
        local start_time=$(date +%s%N)
        health_status=$(kubectl exec -n "$namespace" "$pod_name" -- curl -s -f http://localhost:8280/my-app/actuator/health 2>/dev/null | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
        local end_time=$(date +%s%N)
        
        if [[ "$health_status" != "UNKNOWN" ]]; then
            response_time="$((($end_time - $start_time) / 1000000))ms"
        fi
    fi
    
    echo "$health_status|$response_time"
}

# Get external application health
get_external_health() {
    local health_status="UNKNOWN"
    local response_time="N/A"
    local http_code="N/A"
    
    if command -v curl &> /dev/null; then
        local start_time=$(date +%s%N)
        local response=$(curl -s -w "%{http_code}" --connect-timeout 5 --max-time 10 "https://$DOMAIN/my-app/actuator/health" 2>/dev/null)
        local end_time=$(date +%s%N)
        
        http_code="${response: -3}"
        local body="${response%???}"
        
        if [[ "$http_code" == "200" ]]; then
            health_status=$(echo "$body" | jq -r '.status' 2>/dev/null || echo "UP")
            response_time="$((($end_time - $start_time) / 1000000))ms"
        elif [[ "$http_code" =~ ^[0-9]{3}$ ]]; then
            health_status="HTTP $http_code"
        fi
    fi
    
    echo "$health_status|$response_time|$http_code"
}

# Get GitHub Actions status
get_github_status() {
    local workflow_status="N/A"
    local run_url=""
    
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        local latest_run=$(gh run list --workflow=deploy.yml --limit=1 --json status,url,conclusion 2>/dev/null)
        if [[ -n "$latest_run" && "$latest_run" != "[]" ]]; then
            workflow_status=$(echo "$latest_run" | jq -r '.[0].status' 2>/dev/null || echo "unknown")
            local conclusion=$(echo "$latest_run" | jq -r '.[0].conclusion' 2>/dev/null || echo "null")
            run_url=$(echo "$latest_run" | jq -r '.[0].url' 2>/dev/null || echo "")
            
            if [[ "$conclusion" != "null" && "$conclusion" != "" ]]; then
                workflow_status="$conclusion"
            fi
        fi
    fi
    
    echo "$workflow_status|$run_url"
}

# Display status
display_status() {
    clear
    
    echo -e "${BLUE}📊 Blue-Green Deployment Monitor - $(date)${NC}"
    echo -e "${BLUE}======================================================${NC}"
    echo ""
    
    # Namespaces status
    echo -e "${CYAN}🏗️  Namespace Status:${NC}"
    echo -n "   Blue:  "
    get_namespace_status "prod-my-app-blue"
    echo -n "   Green: "
    get_namespace_status "prod-my-app-green"
    echo ""
    
    # Pod details
    echo -e "${CYAN}📦 Pod Details:${NC}"
    echo -e "   ${BLUE_CIRCLE} Blue Namespace (prod-my-app-blue):${NC}"
    get_pod_details "prod-my-app-blue"
    echo ""
    echo -e "   ${GREEN_CIRCLE} Green Namespace (prod-my-app-green):${NC}"
    get_pod_details "prod-my-app-green"
    echo ""
    
    # Ingress and traffic routing
    echo -e "${CYAN}🌐 Traffic Routing:${NC}"
    local ingress_info=$(get_ingress_status)
    local active_ns=$(echo "$ingress_info" | cut -d'|' -f1)
    local canary_weight=$(echo "$ingress_info" | cut -d'|' -f2)
    local canary_enabled=$(echo "$ingress_info" | cut -d'|' -f3)
    
    if [[ "$active_ns" == "prod-my-app-blue" ]]; then
        echo -e "   Active Namespace: ${BLUE_CIRCLE} Blue ($active_ns)"
    elif [[ "$active_ns" == "prod-my-app-green" ]]; then
        echo -e "   Active Namespace: ${GREEN_CIRCLE} Green ($active_ns)"
    else
        echo -e "   Active Namespace: ${RED_CIRCLE} Unknown ($active_ns)"
    fi
    
    if [[ "$canary_enabled" == "true" ]]; then
        echo -e "   Canary Traffic: ${YELLOW_CIRCLE} ${canary_weight}% to target namespace"
        
        # Show traffic distribution
        local main_traffic=$((100 - canary_weight))
        echo "   Traffic Distribution:"
        echo "     - Main: ${main_traffic}% → $active_ns"
        echo "     - Canary: ${canary_weight}% → target namespace"
    else
        echo -e "   Canary Traffic: ${RED_CIRCLE} Disabled (100% to active namespace)"
    fi
    echo ""
    
    # Application health
    echo -e "${CYAN}💚 Application Health:${NC}"
    
    # Blue namespace health
    local blue_health_info=$(get_app_health "prod-my-app-blue")
    local blue_health=$(echo "$blue_health_info" | cut -d'|' -f1)
    local blue_response_time=$(echo "$blue_health_info" | cut -d'|' -f2)
    
    if [[ "$blue_health" == "UP" ]]; then
        echo -e "   ${BLUE_CIRCLE} Blue: ${GREEN}$blue_health${NC} (${blue_response_time})"
    else
        echo -e "   ${BLUE_CIRCLE} Blue: ${RED}$blue_health${NC} (${blue_response_time})"
    fi
    
    # Green namespace health
    local green_health_info=$(get_app_health "prod-my-app-green")
    local green_health=$(echo "$green_health_info" | cut -d'|' -f1)
    local green_response_time=$(echo "$green_health_info" | cut -d'|' -f2)
    
    if [[ "$green_health" == "UP" ]]; then
        echo -e "   ${GREEN_CIRCLE} Green: ${GREEN}$green_health${NC} (${green_response_time})"
    else
        echo -e "   ${GREEN_CIRCLE} Green: ${RED}$green_health${NC} (${green_response_time})"
    fi
    
    # External health (via ingress)
    local external_health_info=$(get_external_health)
    local external_health=$(echo "$external_health_info" | cut -d'|' -f1)
    local external_response_time=$(echo "$external_health_info" | cut -d'|' -f2)
    local external_http_code=$(echo "$external_health_info" | cut -d'|' -f3)
    
    if [[ "$external_health" == "UP" ]]; then
        echo -e "   🌍 External: ${GREEN}$external_health${NC} (${external_response_time}) - HTTP $external_http_code"
    else
        echo -e "   🌍 External: ${RED}$external_health${NC} (${external_response_time}) - HTTP $external_http_code"
    fi
    echo ""
    
    # GitHub Actions status
    echo -e "${CYAN}🔄 GitHub Actions:${NC}"
    local github_info=$(get_github_status)
    local workflow_status=$(echo "$github_info" | cut -d'|' -f1)
    local run_url=$(echo "$github_info" | cut -d'|' -f2)
    
    case $workflow_status in
        "success")
            echo -e "   Latest Workflow: ${GREEN}✅ $workflow_status${NC}"
            ;;
        "failure")
            echo -e "   Latest Workflow: ${RED}❌ $workflow_status${NC}"
            ;;
        "in_progress"|"queued")
            echo -e "   Latest Workflow: ${YELLOW}⏳ $workflow_status${NC}"
            ;;
        *)
            echo -e "   Latest Workflow: ${RED}❓ $workflow_status${NC}"
            ;;
    esac
    
    if [[ -n "$run_url" ]]; then
        echo "   URL: $run_url"
    fi
    echo ""
    
    # Resource usage (if metrics server available)
    echo -e "${CYAN}📊 Resource Usage:${NC}"
    if kubectl top node &> /dev/null; then
        echo "   Blue Namespace:"
        kubectl top pod -n prod-my-app-blue --no-headers 2>/dev/null | head -3 | while read -r line; do
            if [[ -n "$line" ]]; then
                echo "     $line"
            fi
        done
        
        echo "   Green Namespace:"
        kubectl top pod -n prod-my-app-green --no-headers 2>/dev/null | head -3 | while read -r line; do
            if [[ -n "$line" ]]; then
                echo "     $line"
            fi
        done
    else
        echo -e "   ${YELLOW}⚠️  Metrics server not available${NC}"
    fi
    echo ""
    
    # Instructions
    echo -e "${PURPLE}🎮 Controls: Ctrl+C to stop | 'q' + Enter to quit | 'r' + Enter to refresh${NC}"
    echo -e "${PURPLE}📱 App URL: https://$DOMAIN${NC}"
    echo -e "${PURPLE}⏱️  Refresh: ${REFRESH_INTERVAL}s | Next update: $(date -d "+${REFRESH_INTERVAL} seconds" +%H:%M:%S)${NC}"
}

# Handle user input
handle_input() {
    read -t 1 -n 1 input
    case $input in
        'q'|'Q')
            echo ""
            echo "👋 Monitoring stopped by user"
            exit 0
            ;;
        'r'|'R')
            echo ""
            echo "🔄 Forcing refresh..."
            return 0
            ;;
    esac
}

# Main monitoring loop
main() {
    echo "🚀 Starting Blue-Green Deployment Monitor"
    echo "========================================"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    echo "✅ Prerequisites check passed"
    echo "🔍 Monitoring refresh interval: ${REFRESH_INTERVAL}s"
    echo "🌍 Application domain: $DOMAIN"
    echo ""
    echo "Starting monitoring in 3 seconds..."
    sleep 3
    
    # Setup signal handlers
    trap 'echo ""; echo "👋 Monitoring interrupted"; exit 0' INT TERM
    
    # Main monitoring loop
    while true; do
        display_status
        
        # Wait with input handling
        for i in $(seq 1 $REFRESH_INTERVAL); do
            handle_input
        done
    done
}

# Run main function
main "$@"