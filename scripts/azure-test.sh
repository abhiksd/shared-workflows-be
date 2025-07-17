#!/bin/bash

# Azure Authentication and Access Testing Script
# This script tests Azure managed identity setup, ACR access, AKS access, and Key Vault integration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_test "Running: $test_name"
    
    if eval "$test_command" &> /dev/null; then
        log_success "✅ $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "❌ $test_name"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to run a test with output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    log_test "Running: $test_name"
    
    if output=$(eval "$test_command" 2>&1); then
        log_success "✅ $test_name"
        echo "$output" | head -5
        ((TESTS_PASSED++))
        return 0
    else
        log_error "❌ $test_name"
        echo "$output" | head -3
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_warning "kubectl is not installed - AKS tests will be skipped"
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_warning "docker is not installed - ACR push tests will be skipped"
    fi
    
    log_success "Prerequisites check completed"
}

# Test basic Azure authentication
test_azure_authentication() {
    log_info "Testing Azure Authentication..."
    
    run_test_with_output "Azure CLI login status" "az account show"
    
    # Test tenant and subscription access
    local tenant_id=$(az account show --query tenantId -o tsv 2>/dev/null)
    local subscription_id=$(az account show --query id -o tsv 2>/dev/null)
    
    if [ -n "$tenant_id" ] && [ -n "$subscription_id" ]; then
        log_success "✅ Tenant ID: $tenant_id"
        log_success "✅ Subscription ID: $subscription_id"
    else
        log_error "❌ Failed to get tenant or subscription information"
    fi
    
    # Test token acquisition (simulating GitHub Actions OIDC)
    run_test "Azure token acquisition" "az account get-access-token --output none"
}

# Test Azure Container Registry access
test_acr_access() {
    local acr_name="$1"
    
    if [ -z "$acr_name" ]; then
        log_warning "ACR name not provided, skipping ACR tests"
        return
    fi
    
    log_info "Testing Azure Container Registry Access: $acr_name"
    
    # Test ACR login with managed identity
    run_test "ACR login with managed identity" "az acr login --name $acr_name"
    
    # Test ACR token acquisition
    run_test "ACR access token acquisition" "az acr login --name $acr_name --expose-token --output none"
    
    # Test repository listing
    run_test_with_output "ACR repository listing" "az acr repository list --name $acr_name"
    
    # Test ACR build capabilities (if available)
    if run_test "ACR build capability check" "az acr task list --registry $acr_name --output none"; then
        log_success "✅ ACR build capabilities available"
    fi
    
    # Test Docker login with ACR token
    if command -v docker &> /dev/null; then
        log_test "Testing Docker login with ACR token"
        local access_token=$(az acr login --name "$acr_name" --expose-token --output tsv --query accessToken 2>/dev/null)
        if [ -n "$access_token" ]; then
            if echo "$access_token" | docker login "${acr_name}.azurecr.io" --username 00000000-0000-0000-0000-000000000000 --password-stdin &> /dev/null; then
                log_success "✅ Docker login with ACR token"
                ((TESTS_PASSED++))
            else
                log_error "❌ Docker login with ACR token"
                FAILED_TESTS+=("Docker login with ACR token")
                ((TESTS_FAILED++))
            fi
        else
            log_error "❌ Failed to get ACR access token for Docker login"
            FAILED_TESTS+=("ACR token for Docker login")
            ((TESTS_FAILED++))
        fi
    fi
}

# Test Azure Kubernetes Service access
test_aks_access() {
    local cluster_name="$1"
    local resource_group="$2"
    
    if [ -z "$cluster_name" ] || [ -z "$resource_group" ]; then
        log_warning "AKS cluster name or resource group not provided, skipping AKS tests"
        return
    fi
    
    log_info "Testing AKS Access: $cluster_name in $resource_group"
    
    # Test AKS cluster access
    run_test "AKS cluster show" "az aks show --name $cluster_name --resource-group $resource_group --output none"
    
    # Test getting AKS credentials
    run_test "AKS get credentials" "az aks get-credentials --name $cluster_name --resource-group $resource_group --overwrite-existing"
    
    if command -v kubectl &> /dev/null; then
        # Test kubectl access
        run_test_with_output "kubectl cluster info" "kubectl cluster-info --request-timeout=10s"
        
        # Test node access
        run_test_with_output "kubectl get nodes" "kubectl get nodes --request-timeout=10s"
        
        # Test namespace listing
        run_test_with_output "kubectl get namespaces" "kubectl get namespaces --request-timeout=10s"
        
        # Test OIDC issuer (for Workload Identity)
        local oidc_issuer=$(az aks show --name "$cluster_name" --resource-group "$resource_group" --query "oidcIssuerProfile.issuerUrl" -o tsv 2>/dev/null)
        if [ -n "$oidc_issuer" ]; then
            log_success "✅ OIDC Issuer URL: $oidc_issuer"
            
            # Test OIDC endpoint accessibility
            if curl -s "$oidc_issuer/.well-known/openid-configuration" > /dev/null; then
                log_success "✅ OIDC endpoint accessible"
            else
                log_warning "⚠️ OIDC endpoint not accessible"
            fi
        else
            log_warning "⚠️ OIDC Issuer not configured (Workload Identity may not be enabled)"
        fi
        
        # Test Workload Identity configuration
        local workload_identity=$(az aks show --name "$cluster_name" --resource-group "$resource_group" --query "securityProfile.workloadIdentity.enabled" -o tsv 2>/dev/null)
        if [ "$workload_identity" = "true" ]; then
            log_success "✅ Workload Identity enabled on cluster"
        else
            log_warning "⚠️ Workload Identity not enabled on cluster"
        fi
    else
        log_warning "kubectl not available, skipping Kubernetes API tests"
    fi
}

# Test Azure Key Vault access
test_keyvault_access() {
    local keyvault_name="$1"
    
    if [ -z "$keyvault_name" ]; then
        log_warning "Key Vault name not provided, skipping Key Vault tests"
        return
    fi
    
    log_info "Testing Key Vault Access: $keyvault_name"
    
    # Test Key Vault access
    run_test "Key Vault show" "az keyvault show --name $keyvault_name --output none"
    
    # Test secret listing
    run_test_with_output "Key Vault secret list" "az keyvault secret list --vault-name $keyvault_name"
    
    # Test creating a test secret
    local test_secret_name="github-actions-test-$(date +%s)"
    local test_secret_value="test-value-$(date +%s)"
    
    if az keyvault secret set --vault-name "$keyvault_name" --name "$test_secret_name" --value "$test_secret_value" > /dev/null 2>&1; then
        log_success "✅ Key Vault secret creation"
        ((TESTS_PASSED++))
        
        # Test reading the secret back
        if secret_value=$(az keyvault secret show --vault-name "$keyvault_name" --name "$test_secret_name" --query "value" -o tsv 2>/dev/null); then
            if [ "$secret_value" = "$test_secret_value" ]; then
                log_success "✅ Key Vault secret retrieval"
                ((TESTS_PASSED++))
            else
                log_error "❌ Key Vault secret value mismatch"
                FAILED_TESTS+=("Key Vault secret value mismatch")
                ((TESTS_FAILED++))
            fi
        else
            log_error "❌ Key Vault secret retrieval"
            FAILED_TESTS+=("Key Vault secret retrieval")
            ((TESTS_FAILED++))
        fi
        
        # Clean up test secret
        if az keyvault secret delete --vault-name "$keyvault_name" --name "$test_secret_name" > /dev/null 2>&1; then
            log_success "✅ Key Vault secret cleanup"
        else
            log_warning "⚠️ Failed to clean up test secret: $test_secret_name"
        fi
    else
        log_error "❌ Key Vault secret creation"
        FAILED_TESTS+=("Key Vault secret creation")
        ((TESTS_FAILED++))
    fi
}

# Test GitHub Actions OIDC token simulation
test_github_oidc_simulation() {
    log_info "Testing GitHub Actions OIDC Token Simulation..."
    
    # This would be more complex in a real scenario, but we can test the components
    
    # Test Azure AD token endpoint accessibility
    local tenant_id=$(az account show --query tenantId -o tsv 2>/dev/null)
    if [ -n "$tenant_id" ]; then
        local token_endpoint="https://login.microsoftonline.com/$tenant_id/oauth2/v2.0/token"
        if curl -s "$token_endpoint" > /dev/null; then
            log_success "✅ Azure AD token endpoint accessible"
        else
            log_warning "⚠️ Azure AD token endpoint not accessible"
        fi
    fi
    
    # Test current token validity
    if az account get-access-token --output none > /dev/null 2>&1; then
        log_success "✅ Current Azure token is valid"
        
        # Get token expiration info
        local token_info=$(az account get-access-token --query "{expiresOn: expiresOn}" -o json 2>/dev/null)
        if [ -n "$token_info" ]; then
            log_info "Token info: $token_info"
        fi
    else
        log_error "❌ Current Azure token is invalid"
    fi
}

# Test Azure resource permissions
test_azure_permissions() {
    log_info "Testing Azure Resource Permissions..."
    
    local subscription_id=$(az account show --query id -o tsv 2>/dev/null)
    
    # Test subscription access
    run_test "Subscription read access" "az account list-locations --output none"
    
    # Test resource group listing
    run_test_with_output "Resource group listing" "az group list --query '[].{Name:name,Location:location}' --output table"
    
    # Test role assignments (if accessible)
    if run_test "Role assignment listing" "az role assignment list --assignee \$(az account show --query user.name -o tsv) --output none"; then
        log_success "✅ Can list role assignments"
    fi
}

# Generate test report
generate_test_report() {
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    
    echo ""
    echo "=================================================="
    log_info "Azure Authentication and Access Test Report"
    echo "=================================================="
    
    log_info "Total tests run: $total_tests"
    log_success "Tests passed: $TESTS_PASSED"
    log_error "Tests failed: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo ""
        log_error "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
    fi
    
    echo ""
    local pass_rate=$(( (TESTS_PASSED * 100) / total_tests ))
    if [ $pass_rate -ge 90 ]; then
        log_success "Overall status: EXCELLENT ($pass_rate% pass rate)"
    elif [ $pass_rate -ge 70 ]; then
        log_warning "Overall status: GOOD ($pass_rate% pass rate)"
    elif [ $pass_rate -ge 50 ]; then
        log_warning "Overall status: NEEDS IMPROVEMENT ($pass_rate% pass rate)"
    else
        log_error "Overall status: POOR ($pass_rate% pass rate)"
    fi
    
    # Generate detailed report file
    cat > azure-test-report.md << EOF
# Azure Authentication and Access Test Report

Generated on: $(date)

## Summary
- **Total tests:** $total_tests
- **Passed:** $TESTS_PASSED
- **Failed:** $TESTS_FAILED
- **Pass rate:** $pass_rate%

## Failed Tests
$(if [ $TESTS_FAILED -gt 0 ]; then
    for test in "${FAILED_TESTS[@]}"; do
        echo "- $test"
    done
else
    echo "None"
fi)

## Recommendations
$(if [ $TESTS_FAILED -gt 0 ]; then
    echo "1. Review failed tests and check Azure permissions"
    echo "2. Verify Azure AD App Registration and federated credentials"
    echo "3. Check resource availability and naming"
    echo "4. Ensure all required Azure services are provisioned"
else
    echo "All tests passed! Your Azure setup is ready for GitHub Actions."
fi)

## Next Steps
1. Configure GitHub repository variables and secrets
2. Test actual GitHub Actions workflow execution
3. Monitor deployment logs for any authentication issues
4. Set up Key Vault secrets using the keyvault-setup.sh script
EOF
    
    log_success "Detailed report saved to: azure-test-report.md"
}

# Main test execution
main() {
    log_info "Starting Azure Authentication and Access Tests"
    echo "=================================================="
    
    check_prerequisites
    
    # Parse environment variables or use defaults
    ACR_NAME=${ACR_NAME:-""}
    AKS_CLUSTER_NAME=${AKS_CLUSTER_NAME:-""}
    AKS_RESOURCE_GROUP=${AKS_RESOURCE_GROUP:-""}
    KEYVAULT_NAME=${KEYVAULT_NAME:-""}
    
    # Run core tests
    test_azure_authentication
    test_azure_permissions
    test_github_oidc_simulation
    
    # Run service-specific tests
    if [ -n "$ACR_NAME" ]; then
        test_acr_access "$ACR_NAME"
    fi
    
    if [ -n "$AKS_CLUSTER_NAME" ] && [ -n "$AKS_RESOURCE_GROUP" ]; then
        test_aks_access "$AKS_CLUSTER_NAME" "$AKS_RESOURCE_GROUP"
    fi
    
    if [ -n "$KEYVAULT_NAME" ]; then
        test_keyvault_access "$KEYVAULT_NAME"
    fi
    
    generate_test_report
}

# Help function
show_help() {
    cat << EOF
Azure Authentication and Access Testing Script

Usage: $0 [OPTIONS]

Options:
    -h, --help                          Show this help message
    --acr-name ACR_NAME                 Azure Container Registry name to test
    --aks-cluster AKS_NAME              AKS cluster name to test
    --aks-rg RESOURCE_GROUP             AKS resource group name
    --keyvault KV_NAME                  Key Vault name to test

Environment Variables:
    ACR_NAME                            Azure Container Registry name
    AKS_CLUSTER_NAME                    AKS cluster name
    AKS_RESOURCE_GROUP                  AKS resource group name
    KEYVAULT_NAME                       Key Vault name

Examples:
    $0 --acr-name myregistry --aks-cluster mycluster --aks-rg mygroup --keyvault myvault
    ACR_NAME=myregistry AKS_CLUSTER_NAME=mycluster AKS_RESOURCE_GROUP=mygroup $0

Prerequisites:
    - Azure CLI installed and logged in
    - kubectl installed (for AKS tests)
    - docker installed (for ACR push tests)
    - Appropriate Azure permissions configured
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --acr-name)
            ACR_NAME="$2"
            shift 2
            ;;
        --aks-cluster)
            AKS_CLUSTER_NAME="$2"
            shift 2
            ;;
        --aks-rg)
            AKS_RESOURCE_GROUP="$2"
            shift 2
            ;;
        --keyvault)
            KEYVAULT_NAME="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main