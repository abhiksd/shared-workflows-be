#!/bin/bash
# 🔍 Azure Key Vault Integration Verification Script
# Verifies Key Vault integration in Kubernetes namespace

set -e

NAMESPACE=""
APP_NAME="java-backend1"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo -e "${BLUE}🔍 Azure Key Vault Integration Verification Script${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo ""
    echo "Usage: $0 -n <namespace> [-a <app-name>]"
    echo ""
    echo "Parameters:"
    echo "  -n: Kubernetes namespace (e.g., sqe-java-backend1)"
    echo "  -a: Application name (default: java-backend1)"
    echo "  -h: Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -n sqe-java-backend1"
    echo "  $0 -n prod-java-backend1-blue -a java-backend1"
    echo ""
    exit 1
}

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to log warnings
warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

# Function to log errors
error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# Function to log info
info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

# Parse command line arguments
while getopts "n:a:h" opt; do
    case $opt in
        n) NAMESPACE="$OPTARG" ;;
        a) APP_NAME="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [[ -z "$NAMESPACE" ]]; then
    error "Missing required parameter: namespace"
    usage
fi

log "🔍 Verifying Key Vault integration in namespace: $NAMESPACE"
log "📱 Application name: $APP_NAME"
echo ""
echo "============================================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    error "Namespace '$NAMESPACE' does not exist"
    exit 1
fi

log "✅ Namespace '$NAMESPACE' exists"

# Check SecretProviderClass
echo ""
info "📋 Checking SecretProviderClass..."
SPC_NAME="${APP_NAME}-keyvault"

if kubectl get secretproviderclass -n "$NAMESPACE" "$SPC_NAME" >/dev/null 2>&1; then
    log "✅ SecretProviderClass '$SPC_NAME' exists"
    
    echo ""
    echo "📄 SecretProviderClass Details:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    kubectl get secretproviderclass -n "$NAMESPACE" "$SPC_NAME" -o yaml | grep -A 20 "spec:"
    
    echo ""
    echo "🔍 SecretProviderClass Status:"
    kubectl describe secretproviderclass -n "$NAMESPACE" "$SPC_NAME" | tail -10
else
    warn "SecretProviderClass '$SPC_NAME' not found"
fi

echo ""

# Check CSI Secret Store Driver
info "🔧 Checking CSI Secret Store Driver..."
CSI_PODS=$(kubectl get pods -n kube-system -l app=secrets-store-csi-driver --no-headers 2>/dev/null | wc -l)

if [[ $CSI_PODS -gt 0 ]]; then
    log "✅ CSI Secret Store Driver is running ($CSI_PODS pods)"
    
    # Check driver version
    kubectl get pods -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].spec.containers[0].image}'
    echo ""
else
    warn "CSI Secret Store Driver not found in kube-system namespace"
fi

echo ""

# Check Azure Key Vault Provider
info "🔑 Checking Azure Key Vault Provider..."
KV_PROVIDER_PODS=$(kubectl get pods -n kube-system -l app=secrets-store-provider-azure --no-headers 2>/dev/null | wc -l)

if [[ $KV_PROVIDER_PODS -gt 0 ]]; then
    log "✅ Azure Key Vault Provider is running ($KV_PROVIDER_PODS pods)"
else
    warn "Azure Key Vault Provider not found"
fi

echo ""

# Check application pods
info "📦 Checking application pods..."
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$POD_NAME" ]]; then
    log "✅ Found application pod: $POD_NAME"
    
    echo ""
    echo "📊 Pod Status:"
    kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o wide
    
    echo ""
    info "🔍 Checking secret mount in pod..."
    
    # Check if secrets-store volume is mounted
    if kubectl describe pod -n "$NAMESPACE" "$POD_NAME" | grep -q "secrets-store"; then
        log "✅ Secrets-store volume is mounted"
        
        # Check mounted secrets
        echo ""
        echo "📁 Mounted Secret Files:"
        kubectl exec -n "$NAMESPACE" "$POD_NAME" -- ls -la /mnt/secrets-store/ 2>/dev/null || warn "Cannot access secret mount directory"
        
        # Check specific secret files
        echo ""
        echo "🔍 Checking individual secret files:"
        SECRET_FILES=("mongodb-connection-string" "redis-password" "jwt-secret" "api-key")
        
        for secret in "${SECRET_FILES[@]}"; do
            if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- test -f "/mnt/secrets-store/$secret" 2>/dev/null; then
                log "✅ Secret file '$secret' exists"
            else
                warn "Secret file '$secret' not found"
            fi
        done
        
    else
        warn "Secrets-store volume not found in pod"
    fi
    
    echo ""
    info "🌍 Checking environment variables..."
    
    # Check secret-related environment variables
    SECRET_ENV_VARS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- env 2>/dev/null | grep -E "(MONGODB|REDIS|JWT|API)" || echo "")
    
    if [[ -n "$SECRET_ENV_VARS" ]]; then
        log "✅ Secret-related environment variables found:"
        echo "$SECRET_ENV_VARS" | sed 's/^/    /'
    else
        warn "No secret-related environment variables found"
    fi
    
else
    warn "No application pods found with label app.kubernetes.io/name=$APP_NAME"
fi

echo ""

# Check Kubernetes secrets
info "🔐 Checking Kubernetes secrets..."
K8S_SECRET_NAME="app-secrets"

if kubectl get secret -n "$NAMESPACE" "$K8S_SECRET_NAME" >/dev/null 2>&1; then
    log "✅ Kubernetes secret '$K8S_SECRET_NAME' exists"
    
    echo ""
    echo "📋 Secret Details:"
    kubectl describe secret -n "$NAMESPACE" "$K8S_SECRET_NAME"
    
    echo ""
    echo "🔍 Secret Keys:"
    kubectl get secret -n "$NAMESPACE" "$K8S_SECRET_NAME" -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || kubectl get secret -n "$NAMESPACE" "$K8S_SECRET_NAME" -o jsonpath='{.data}' | sed 's/[{}"]//g' | tr ',' '\n' | cut -d: -f1
    
else
    warn "Kubernetes secret '$K8S_SECRET_NAME' not found"
fi

echo ""

# Check events for any issues
info "📊 Checking recent events for issues..."
EVENTS=$(kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | grep -i "secret\|vault\|csi" | tail -5)

if [[ -n "$EVENTS" ]]; then
    echo ""
    echo "📰 Recent Key Vault related events:"
    echo "$EVENTS"
else
    log "✅ No recent Key Vault related events found"
fi

echo ""

# Final health check
echo ""
echo "🎯 VERIFICATION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Count checks
TOTAL_CHECKS=0
PASSED_CHECKS=0

# SecretProviderClass check
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if kubectl get secretproviderclass -n "$NAMESPACE" "$SPC_NAME" >/dev/null 2>&1; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "✅ SecretProviderClass: PASS"
else
    echo "❌ SecretProviderClass: FAIL"
fi

# CSI Driver check
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [[ $CSI_PODS -gt 0 ]]; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "✅ CSI Secret Store Driver: PASS"
else
    echo "❌ CSI Secret Store Driver: FAIL"
fi

# Application pod check
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [[ -n "$POD_NAME" ]]; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "✅ Application Pod: PASS"
else
    echo "❌ Application Pod: FAIL"
fi

# Kubernetes secret check
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if kubectl get secret -n "$NAMESPACE" "$K8S_SECRET_NAME" >/dev/null 2>&1; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "✅ Kubernetes Secret: PASS"
else
    echo "❌ Kubernetes Secret: FAIL"
fi

echo ""
echo "📊 Overall Status: $PASSED_CHECKS/$TOTAL_CHECKS checks passed"

if [[ $PASSED_CHECKS -eq $TOTAL_CHECKS ]]; then
    log "🎉 All checks passed! Key Vault integration is working correctly."
    exit 0
else
    warn "⚠️  Some checks failed. Please review the issues above."
    exit 1
fi