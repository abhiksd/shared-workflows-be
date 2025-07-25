# 🚀 Blue-Green Deployment Guide

Comprehensive guide for deploying Java Backend1 using Blue-Green deployment strategy with namespace-based approach.

## 📋 **Table of Contents**

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Environment Strategy](#environment-strategy)
- [Deployment Procedures](#deployment-procedures)
- [Blue-Green Production Flow](#blue-green-production-flow)
- [Commands Reference](#commands-reference)
- [Monitoring & Validation](#monitoring--validation)
- [Rollback Procedures](#rollback-procedures)
- [Troubleshooting](#troubleshooting)
- [Scripts & Automation](#scripts--automation)

## 🎯 **Overview**

This service implements **Blue-Green deployment** with the following architecture:
- **Single AKS Cluster**: Cost-effective namespace-based approach
- **Zero-Downtime**: Instant traffic switching via ingress routing
- **Canary Validation**: Gradual traffic increase with health monitoring
- **Instant Rollback**: < 30 seconds rollback capability
- **Automated Quality Gates**: SonarQube, Checkmarx, health checks

## ✅ **Prerequisites**

### **Required Tools**
```bash
# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update && sudo apt-get install helm
```

### **Azure Setup**
```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "<your-subscription-id>"

# Get AKS credentials
az aks get-credentials --resource-group rg-aks-prod --name aks-prod-cluster
```

### **GitHub Authentication**
```bash
# Login to GitHub CLI
gh auth login

# Set repository context
cd /path/to/your/repository
gh repo set-default
```

## 🏗️ **Environment Strategy**

### **Environment Mapping**
| Environment | Branch/Tag | Deployment Type | Purpose |
|-------------|------------|-----------------|---------|
| **dev** | `develop` | Rolling | Fast development iteration |
| **sqe** | `main` | Rolling | System Quality Engineering |
| **ppr** | `release/*` | Rolling | Pre-production validation |
| **prod** | `tags` | Blue-Green + Canary | Production with safety |

### **Branch Strategy**
```bash
# Development workflow
develop ────→ dev environment (automatic)
    │
    └─→ main ────→ sqe environment (automatic)
            │
            └─→ release/v1.2.0 ────→ ppr environment (automatic)
                    │
                    └─→ tag v1.2.0 ────→ prod environment (manual approval)
```

## 🚀 **Deployment Procedures**

### **1. Development Deployment**
```bash
# Make changes
git checkout develop
git add .
git commit -m "feat: add new feature"
git push origin develop

# Automatic deployment to dev environment
# Monitor: https://github.com/your-org/your-repo/actions
```

### **2. SQE Deployment**
```bash
# Merge to main
git checkout main
git merge develop
git push origin main

# Automatic deployment to sqe environment
# Validation: Run integration tests
```

### **3. Pre-Production Deployment**
```bash
# Create release branch
git checkout main
git checkout -b release/v2.1.0
git push origin release/v2.1.0

# Automatic deployment to ppr environment
# Validation: End-to-end testing
```

### **4. Production Deployment** (Blue-Green)
```bash
# Create and push tag
git checkout main
git tag v2.1.0
git push origin v2.1.0

# Manual approval required in GitHub Actions
# Navigate to: Actions → Approve production deployment
```

## 🛡️ **Blue-Green Production Flow**

### **Phase 1: Quality Gates (Automatic)**
```bash
# 1. Triggered by tag push
git tag v2.1.0 && git push origin v2.1.0

# 2. Quality checks run automatically:
# ✅ Maven build and tests
# ✅ SonarQube analysis
# ✅ Checkmarx security scan
# ✅ Docker image build and push
```

### **Phase 2: Blue-Green Strategy (Automatic)**
```bash
# 3. Slot detection
# - Checks current active namespace (blue/green)
# - Determines target namespace for deployment

# 4. Deploy to target namespace
# - Deploys new version to inactive namespace
# - Waits for pods to be ready
# - Runs health checks
```

### **Phase 3: Manual Approval Gate**
```bash
# 5. Production approval required
# Navigate to: GitHub Actions → Production Approval
# Review deployment details:
# - Application version and image tag
# - Quality gate status (SonarQube, Checkmarx)
# - Current vs target deployment slots
# - AKS cluster information

# 6. Click "Approve" to continue
```

### **Phase 4: Canary Validation (Automatic)**
```bash
# 7. Canary traffic starts at 5%
# - Updates canary ingress weight
# - Monitors for 5 minutes (configurable)
# - Auto-rollback if thresholds exceeded

# 8. Progressive traffic increase:
# 5% → 10% (monitor 5 min) → 25% (monitor 5 min) → 50% (monitor 5 min) → 100%

# 9. Health monitoring at each step:
# - Error rate < 0.1%
# - Response time < 2x baseline
# - Pod health and restart count
```

### **Phase 5: Production Switch (Automatic)**
```bash
# 10. Full traffic switch
# - Updates main ingress to point to new namespace
# - Updates namespace labels (active: true/false)
# - Previous namespace becomes standby
# - Deployment complete
```

## 📋 **Commands Reference**

### **GitHub Actions Workflows**
```bash
# List workflows
gh workflow list

# Run deployment workflow
gh workflow run deploy.yml -f environment=dev
gh workflow run deploy.yml -f environment=sqe
gh workflow run deploy.yml -f environment=ppr
gh workflow run deploy.yml -f environment=prod

# Force deployment (skip change detection)
gh workflow run deploy.yml -f environment=prod -f force_deploy=true

# View workflow runs
gh run list --workflow=deploy.yml

# View specific run
gh run view <run-id>

# Download logs
gh run download <run-id>
```

### **Kubernetes Commands**

#### **Blue-Green Monitoring**
```bash
# Check current active slot
kubectl get ingress prod-java-backend1-ingress -n default -o yaml | grep namespace

# Check both namespaces
kubectl get pods -n prod-java-backend1-blue
kubectl get pods -n prod-java-backend1-green

# Check ingress status
kubectl get ingress -n default
kubectl describe ingress prod-java-backend1-ingress -n default
kubectl describe ingress prod-java-backend1-ingress-canary -n default

# Check canary weight
kubectl get ingress prod-java-backend1-ingress-canary -n default -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}'
```

#### **Health Checks**
```bash
# Check pod health
kubectl get pods -n prod-java-backend1-blue -o wide
kubectl get pods -n prod-java-backend1-green -o wide

# Describe problematic pods
kubectl describe pod <pod-name> -n <namespace>

# View pod logs
kubectl logs <pod-name> -n <namespace> --tail=100 -f

# Port forward for testing
kubectl port-forward pod/<pod-name> 8080:8080 -n <namespace>
curl http://localhost:8080/actuator/health
```

#### **Service and Ingress**
```bash
# Check services
kubectl get svc -n prod-java-backend1-blue
kubectl get svc -n prod-java-backend1-green

# Test service connectivity
kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- /bin/sh
# Inside pod:
curl http://java-backend1-service.prod-java-backend1-blue.svc.cluster.local/actuator/health
```

### **Azure CLI Commands**
```bash
# Check AKS cluster
az aks show --resource-group rg-aks-prod --name aks-prod-cluster

# Get cluster credentials
az aks get-credentials --resource-group rg-aks-prod --name aks-prod-cluster --overwrite-existing

# Check node status
az aks nodepool show --cluster-name aks-prod-cluster --resource-group rg-aks-prod --name <nodepool-name>
```

## 📊 **Monitoring & Validation**

### **Health Check URLs**
```bash
# Production endpoints (adjust domain)
curl https://api.mydomain.com/actuator/health
curl https://api.mydomain.com/actuator/health/liveness
curl https://api.mydomain.com/actuator/health/readiness
curl https://api.mydomain.com/actuator/info

# Metrics endpoint
curl https://api.mydomain.com/actuator/prometheus

# Test canary deployment (header-based)
curl -H "X-Canary-Deploy: green" https://api.mydomain.com/actuator/health
```

### **Validation Scripts**
```bash
# Quick health validation
#!/bin/bash
echo "🔍 Validating deployment health..."

BLUE_HEALTH=$(kubectl exec -n prod-java-backend1-blue deployment/java-backend1 -- curl -s http://localhost:8080/actuator/health | jq -r '.status')
GREEN_HEALTH=$(kubectl exec -n prod-java-backend1-green deployment/java-backend1 -- curl -s http://localhost:8080/actuator/health | jq -r '.status')

echo "Blue namespace health: $BLUE_HEALTH"
echo "Green namespace health: $GREEN_HEALTH"

# Check current traffic routing
ACTIVE_NS=$(kubectl get ingress prod-java-backend1-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.namespace}')
echo "Active namespace: $ACTIVE_NS"
```

## 🔄 **Rollback Procedures**

### **Method 1: GitHub Actions Rollback** (Recommended)
```bash
# Trigger rollback workflow
gh workflow run rollback.yml -f environment=prod -f target_version=v2.0.0

# Or manual workflow dispatch:
# 1. Go to Actions tab
# 2. Select "Rollback Deployment" workflow
# 3. Click "Run workflow"
# 4. Select environment: prod
# 5. Enter target version: v2.0.0
```

### **Method 2: Emergency Kubectl Rollback**
```bash
# Emergency rollback - switch traffic back to previous namespace
# If green is currently active, switch back to blue:

kubectl patch ingress prod-java-backend1-ingress -n default \
  --type='merge' \
  -p='{"spec":{"rules":[{"host":"api.mydomain.com","http":{"paths":[{"path":"/(backend1/|$)(.*)","pathType":"ImplementationSpecific","backend":{"service":{"name":"java-backend1-service","namespace":"prod-java-backend1-blue","port":{"number":80}}}}]}}]}}'

# Verify rollback
kubectl get ingress prod-java-backend1-ingress -n default -o yaml | grep namespace
```

### **Method 3: Helm Rollback**
```bash
# List helm releases
helm list -A

# Check release history
helm history java-backend1-prod -n prod-java-backend1-blue

# Rollback to specific revision
helm rollback java-backend1-prod 1 -n prod-java-backend1-blue
```

### **Rollback Validation**
```bash
# Validate rollback success
#!/bin/bash
echo "🔄 Validating rollback..."

# Check active namespace
ACTIVE_NS=$(kubectl get ingress prod-java-backend1-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.namespace}')
echo "Current active namespace: $ACTIVE_NS"

# Test application health
HEALTH_STATUS=$(curl -s https://api.mydomain.com/actuator/health | jq -r '.status')
echo "Application health: $HEALTH_STATUS"

# Check application version
APP_VERSION=$(curl -s https://api.mydomain.com/actuator/info | jq -r '.build.version')
echo "Application version: $APP_VERSION"

if [[ "$HEALTH_STATUS" == "UP" ]]; then
    echo "✅ Rollback successful - Application is healthy"
else
    echo "❌ Rollback may have failed - Application health check failed"
fi
```

## 🛠️ **Troubleshooting**

### **Common Issues & Solutions**

#### **1. Deployment Stuck in Quality Gates**
```bash
# Check SonarQube scan
gh run view <run-id> --log | grep -i sonar

# Check Checkmarx scan
gh run view <run-id> --log | grep -i checkmarx

# Re-trigger workflow if transient failure
gh workflow run deploy.yml -f environment=prod -f force_deploy=true
```

#### **2. Blue-Green Slot Detection Failed**
```bash
# Check namespace labels
kubectl get namespace prod-java-backend1-blue -o yaml
kubectl get namespace prod-java-backend1-green -o yaml

# Manually set active namespace
kubectl label namespace prod-java-backend1-blue active=true --overwrite
kubectl label namespace prod-java-backend1-green active=false --overwrite
```

#### **3. Canary Traffic Not Working**
```bash
# Check canary ingress
kubectl describe ingress prod-java-backend1-ingress-canary -n default

# Check NGINX ingress controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | tail -50

# Manually set canary weight
kubectl patch ingress prod-java-backend1-ingress-canary -n default \
  -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"10"}}}'
```

#### **4. Health Checks Failing**
```bash
# Check pod status
kubectl get pods -n <namespace> -o wide

# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check application logs
kubectl logs <pod-name> -n <namespace> --tail=100

# Test health endpoint directly
kubectl exec -it <pod-name> -n <namespace> -- curl http://localhost:8080/actuator/health

# Check Spring Boot actuator endpoints
kubectl exec -it <pod-name> -n <namespace> -- curl http://localhost:8080/actuator/info
kubectl exec -it <pod-name> -n <namespace> -- curl http://localhost:8080/actuator/env
```

#### **5. Manual Approval Timeout**
```bash
# Check approval environment settings
gh api repos/:owner/:repo/environments/production-approval

# Re-trigger workflow if approval expired
gh workflow run deploy.yml -f environment=prod
```

### **Debug Commands**
```bash
# Complete deployment status
#!/bin/bash
echo "🔍 Complete Deployment Status Check"
echo "================================="

echo "📋 GitHub Workflow Status:"
gh run list --workflow=deploy.yml --limit=3

echo ""
echo "📋 Kubernetes Namespaces:"
kubectl get namespace | grep prod-java-backend1

echo ""
echo "📋 Pod Status:"
kubectl get pods -n prod-java-backend1-blue -o wide
kubectl get pods -n prod-java-backend1-green -o wide

echo ""
echo "📋 Ingress Status:"
kubectl get ingress -n default | grep java-backend1

echo ""
echo "📋 Current Active Namespace:"
kubectl get ingress prod-java-backend1-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.namespace}'

echo ""
echo "📋 Canary Weight:"
kubectl get ingress prod-java-backend1-ingress-canary -n default -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}'

echo ""
echo "📋 Application Health:"
curl -s https://api.mydomain.com/actuator/health | jq '.status'
```

## 🤖 **Scripts & Automation**

### **Deployment Script**
Create `scripts/deploy.sh`:
```bash
#!/bin/bash
set -e

ENVIRONMENT=${1:-"dev"}
FORCE_DEPLOY=${2:-"false"}

echo "🚀 Deploying to $ENVIRONMENT environment..."

# Validate environment
case $ENVIRONMENT in
    dev|sqe|ppr|prod)
        echo "✅ Valid environment: $ENVIRONMENT"
        ;;
    *)
        echo "❌ Invalid environment: $ENVIRONMENT"
        echo "Valid options: dev, sqe, ppr, prod"
        exit 1
        ;;
esac

# Trigger deployment
echo "📤 Triggering GitHub Actions workflow..."
gh workflow run deploy.yml \
    -f environment=$ENVIRONMENT \
    -f force_deploy=$FORCE_DEPLOY

echo "✅ Deployment triggered successfully!"
echo "🔗 Monitor progress: $(gh browse --no-browser 2>&1 | grep -o 'https://[^"]*')/actions"
```

### **Health Check Script**
Create `scripts/health-check.sh`:
```bash
#!/bin/bash

NAMESPACE=${1:-"prod-java-backend1-blue"}
MAX_RETRIES=30
RETRY_INTERVAL=10

echo "🔍 Health checking namespace: $NAMESPACE"

for i in $(seq 1 $MAX_RETRIES); do
    echo "Attempt $i/$MAX_RETRIES..."
    
    # Check pod readiness
    READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=java-backend1 --field-selector=status.phase=Running -o json | jq '.items | length')
    TOTAL_PODS=$(kubectl get pods -n $NAMESPACE -l app=java-backend1 -o json | jq '.items | length')
    
    if [ "$READY_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
        echo "✅ All pods are ready ($READY_PODS/$TOTAL_PODS)"
        
        # Test application health
        kubectl exec -n $NAMESPACE deployment/java-backend1 -- curl -f http://localhost:8080/actuator/health > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ Application health check passed"
            exit 0
        else
            echo "❌ Application health check failed"
        fi
    else
        echo "⏳ Waiting for pods to be ready ($READY_PODS/$TOTAL_PODS)..."
    fi
    
    sleep $RETRY_INTERVAL
done

echo "❌ Health check failed after $MAX_RETRIES attempts"
exit 1
```

### **Monitoring Script**
Create `scripts/monitor-deployment.sh`:
```bash
#!/bin/bash

echo "📊 Monitoring Blue-Green Deployment"
echo "================================="

while true; do
    clear
    echo "📊 Blue-Green Deployment Status - $(date)"
    echo "========================================"
    
    echo ""
    echo "🔵 Blue Namespace Status:"
    kubectl get pods -n prod-java-backend1-blue -o wide 2>/dev/null || echo "Namespace not found"
    
    echo ""
    echo "🟢 Green Namespace Status:"
    kubectl get pods -n prod-java-backend1-green -o wide 2>/dev/null || echo "Namespace not found"
    
    echo ""
    echo "🌐 Ingress Status:"
    ACTIVE_NS=$(kubectl get ingress prod-java-backend1-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.namespace}' 2>/dev/null || echo "Not found")
    CANARY_WEIGHT=$(kubectl get ingress prod-java-backend1-ingress-canary -n default -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}' 2>/dev/null || echo "0")
    
    echo "Active Namespace: $ACTIVE_NS"
    echo "Canary Weight: $CANARY_WEIGHT%"
    
    echo ""
    echo "💚 Application Health:"
    HEALTH=$(curl -s --connect-timeout 5 https://api.mydomain.com/actuator/health 2>/dev/null | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
    echo "Status: $HEALTH"
    
    echo ""
    echo "Press Ctrl+C to stop monitoring..."
    sleep 5
done
```

Make scripts executable:
```bash
chmod +x scripts/*.sh
```

## 📚 **Additional Resources**

- **[Blue-Green Strategy Deep Dive](./docs/BLUE-GREEN.md)** - Technical implementation details
- **[Runbooks](./docs/RUNBOOKS.md)** - Operational procedures for incidents
- **[Monitoring Guide](./docs/MONITORING.md)** - Observability and alerting setup
- **[Security Guide](./docs/SECURITY.md)** - Security considerations and best practices

## 🎯 **Quick Reference**

### **Emergency Contacts & Links**
- **GitHub Repository**: [Your Repository URL]
- **Azure Portal**: [AKS Cluster URL]
- **Monitoring Dashboard**: [Grafana/Azure Monitor URL]
- **Incident Response**: [Your incident response process]

### **Key Metrics to Monitor**
- **Error Rate**: < 0.1%
- **Response Time**: < 500ms (P95)
- **Pod Restart Count**: < 3 per hour
- **Memory Usage**: < 90%
- **CPU Usage**: < 80%

### **Deployment Checklist**
- [ ] Quality gates passed (SonarQube, Checkmarx)
- [ ] Health checks successful
- [ ] Canary validation completed
- [ ] Manual approval obtained
- [ ] Traffic switch successful
- [ ] Post-deployment validation passed
- [ ] Monitoring alerts configured
- [ ] Rollback plan ready

Your Blue-Green deployment is now fully documented and ready for production use! 🚀