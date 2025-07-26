# 🔄 Rollback Procedures Guide

Comprehensive guide for rollback procedures across all environments with step-by-step instructions for emergency recovery.

## 📋 **Table of Contents**

- [Overview](#overview)
- [Environment-Specific Rollback Strategies](#environment-specific-rollback-strategies)
- [Rolling Deployment Rollback (Dev/SQE)](#rolling-deployment-rollback-devsqe)
- [Blue-Green Deployment Rollback (PPR/Prod)](#blue-green-deployment-rollback-pprprod)
- [Emergency Rollback Procedures](#emergency-rollback-procedures)
- [Database Rollback Procedures](#database-rollback-procedures)
- [Automated Rollback Scripts](#automated-rollback-scripts)
- [Verification and Validation](#verification-and-validation)
- [Post-Rollback Analysis](#post-rollback-analysis)
- [Prevention and Best Practices](#prevention-and-best-practices)

## 🎯 **Overview**

### **Rollback Strategy by Environment**

| Environment | Deployment Type | Rollback Method | RTO* | Impact |
|-------------|----------------|-----------------|------|--------|
| **Dev** | Rolling | Kubectl/Helm rollback | ~2 minutes | Low |
| **SQE** | Rolling | Kubectl/Helm rollback | ~3 minutes | Low |
| **PPR** | Blue-Green | Traffic switch + cleanup | ~30 seconds | Medium |
| **Prod** | Blue-Green | Traffic switch + cleanup | ~30 seconds | High |

*RTO = Recovery Time Objective

### **Rollback Triggers**
- ❌ Application crashes or fails to start
- ❌ Critical functionality not working
- ❌ Performance degradation > 50%
- ❌ Security vulnerabilities discovered
- ❌ Data corruption or integrity issues
- ❌ External service integration failures
- ❌ User-reported critical bugs

## 📊 **Environment-Specific Rollback Strategies**

### **Development & SQE Environments**
```yaml
Strategy: Rolling Deployment Rollback
- Method: Helm rollback command
- Downtime: 1-3 minutes
- Risk: Low (isolated environments)
- Automation: Fully automated
```

### **Pre-Production Environment**
```yaml
Strategy: Blue-Green Traffic Switch
- Method: Ingress traffic redirection
- Downtime: <30 seconds
- Risk: Medium (production-like)
- Automation: Semi-automated with approval
```

### **Production Environment**
```yaml
Strategy: Blue-Green Traffic Switch + Database considerations
- Method: Ingress traffic redirection + data sync
- Downtime: <30 seconds
- Risk: High (customer-facing)
- Automation: Manual approval required
```

## 🔄 **Rolling Deployment Rollback (Dev/SQE)**

### **Prerequisites**
```bash
# Ensure you have access to the environment
kubectl config current-context

# Verify Helm is installed and accessible
helm version

# Check current deployment status
kubectl get deployments -n default
helm list -n default
```

### **Method 1: Helm Rollback (Recommended)**

#### **1. Check Release History**
```bash
# Get current environment context
ENV="dev"  # or "sqe"
APP_NAME="java-backend1"

# Get AKS context
az aks get-credentials --resource-group "rg-${APP_NAME}-${ENV}" --name "aks-${APP_NAME}-${ENV}" --overwrite-existing

# List Helm releases
helm list -n default

# Check release history
helm history ${APP_NAME} -n default
```

#### **2. Identify Target Revision**
```bash
# Show detailed history with status
helm history ${APP_NAME} -n default --max 10

# Example output:
# REVISION  UPDATED                   STATUS      CHART               APP VERSION  DESCRIPTION
# 1         Mon Jan 15 10:00:00 2024  superseded  java-backend1-1.0.0  1.0.0       Install complete
# 2         Mon Jan 15 11:00:00 2024  superseded  java-backend1-1.1.0  1.1.0       Upgrade complete
# 3         Mon Jan 15 12:00:00 2024  failed      java-backend1-1.2.0  1.2.0       Upgrade failed
```

#### **3. Execute Rollback**
```bash
# Rollback to previous working version (revision 2 in example above)
PREVIOUS_REVISION=2

echo "🔄 Starting rollback to revision ${PREVIOUS_REVISION}..."
helm rollback ${APP_NAME} ${PREVIOUS_REVISION} -n default

# Monitor rollback progress
kubectl rollout status deployment/${APP_NAME} -n default --timeout=300s
```

#### **4. Verify Rollback**
```bash
# Check deployment status
kubectl get pods -n default -l app=${APP_NAME}

# Check application health
kubectl exec -n default deployment/${APP_NAME} -- curl -f http://localhost:8080/backend1/actuator/health

# Verify version
curl -k https://${ENV}.mydomain.com/backend1/api/deployment/info
```

### **Method 2: Kubernetes Rollback**

#### **1. Check Deployment History**
```bash
# Check rollout history
kubectl rollout history deployment/${APP_NAME} -n default

# Get specific revision details
kubectl rollout history deployment/${APP_NAME} -n default --revision=2
```

#### **2. Execute Kubernetes Rollback**
```bash
# Rollback to previous revision
kubectl rollout undo deployment/${APP_NAME} -n default

# Or rollback to specific revision
kubectl rollout undo deployment/${APP_NAME} -n default --to-revision=2

# Monitor rollback
kubectl rollout status deployment/${APP_NAME} -n default
```

### **Method 3: Manual Image Rollback**

#### **1. Get Previous Image Tag**
```bash
# List recent images in ACR
ACR_NAME="your-acr-name"
az acr repository show-tags --name ${ACR_NAME} --repository ${APP_NAME} --top 10 --orderby time_desc

# Example output:
# 2024-01-15-12-00-abc123  (failed deployment)
# 2024-01-15-11-00-def456  (working version)
# 2024-01-15-10-00-ghi789
```

#### **2. Update Deployment with Previous Image**
```bash
# Set previous working image
PREVIOUS_IMAGE="${ACR_NAME}.azurecr.io/${APP_NAME}:2024-01-15-11-00-def456"

# Update deployment
kubectl set image deployment/${APP_NAME} ${APP_NAME}=${PREVIOUS_IMAGE} -n default

# Monitor rollout
kubectl rollout status deployment/${APP_NAME} -n default
```

## 🟦🟩 **Blue-Green Deployment Rollback (PPR/Prod)**

### **Understanding Blue-Green State**

#### **1. Check Current Traffic Routing**
```bash
# Set environment
ENV="ppr"  # or "prod"
APP_NAME="java-backend1"

# Get AKS context
az aks get-credentials --resource-group "rg-${APP_NAME}-${ENV}" --name "aks-${APP_NAME}-${ENV}" --overwrite-existing

# Check current ingress configuration
kubectl get ingress ${APP_NAME}-ingress -n default -o yaml

# Check active slot label
kubectl get ingress ${APP_NAME}-ingress -n default -o jsonpath='{.metadata.labels.active-slot}'

# Check namespace pods
kubectl get pods -n ${ENV}-${APP_NAME}-blue
kubectl get pods -n ${ENV}-${APP_NAME}-green
```

#### **2. Identify Current and Previous Slots**
```bash
# Get current active slot
CURRENT_SLOT=$(kubectl get ingress ${APP_NAME}-ingress -n default -o jsonpath='{.metadata.labels.active-slot}')
echo "Current active slot: ${CURRENT_SLOT}"

# Determine previous slot
if [ "$CURRENT_SLOT" = "blue" ]; then
    PREVIOUS_SLOT="green"
else
    PREVIOUS_SLOT="blue"
fi

echo "Previous slot: ${PREVIOUS_SLOT}"

# Check if previous slot has healthy deployment
PREVIOUS_NS="${ENV}-${APP_NAME}-${PREVIOUS_SLOT}"
kubectl get pods -n ${PREVIOUS_NS} --field-selector=status.phase=Running
```

### **Immediate Traffic Switch Rollback**

#### **1. Pre-Rollback Verification**
```bash
# Verify previous slot health
PREVIOUS_NS="${ENV}-${APP_NAME}-${PREVIOUS_SLOT}"

echo "🔍 Verifying previous slot health..."

# Check pod status
HEALTHY_PODS=$(kubectl get pods -n ${PREVIOUS_NS} --field-selector=status.phase=Running --no-headers | wc -l)
TOTAL_PODS=$(kubectl get pods -n ${PREVIOUS_NS} --no-headers | wc -l)

echo "Healthy pods in ${PREVIOUS_SLOT} slot: ${HEALTHY_PODS}/${TOTAL_PODS}"

if [ ${HEALTHY_PODS} -eq 0 ]; then
    echo "❌ ERROR: No healthy pods in previous slot. Cannot rollback via traffic switch."
    exit 1
fi

# Test previous slot health endpoint
kubectl exec -n ${PREVIOUS_NS} deployment/${APP_NAME} -- curl -f http://localhost:8080/backend1/actuator/health || {
    echo "❌ ERROR: Previous slot health check failed"
    exit 1
}
```

#### **2. Execute Traffic Switch**
```bash
# Prepare rollback
echo "🔄 Starting Blue-Green rollback..."
echo "   Current slot: ${CURRENT_SLOT}"
echo "   Rolling back to: ${PREVIOUS_SLOT}"

# Update ingress to point to previous slot
INGRESS_HOST=""
if [ "$ENV" = "ppr" ]; then
    INGRESS_HOST="preprod.mydomain.com"
else
    INGRESS_HOST="api.mydomain.com"
fi

# Switch traffic to previous slot
kubectl patch ingress ${APP_NAME}-ingress -n default --type='merge' \
  -p='{"spec":{"rules":[{"host":"'${INGRESS_HOST}'","http":{"paths":[{"path":"/(backend1/|$)(.*)","pathType":"ImplementationSpecific","backend":{"service":{"name":"'${APP_NAME}'","namespace":"'${PREVIOUS_NS}'","port":{"number":8080}}}}]}}]}}'

# Update active slot label
kubectl label ingress ${APP_NAME}-ingress -n default active-slot=${PREVIOUS_SLOT} --overwrite

echo "✅ Traffic switched to ${PREVIOUS_SLOT} slot"
```

#### **3. Verify Rollback**
```bash
# Wait for traffic switch to propagate
echo "⏳ Waiting for traffic switch to propagate..."
sleep 30

# Test endpoint
ENDPOINT_URL=""
if [ "$ENV" = "ppr" ]; then
    ENDPOINT_URL="https://preprod.mydomain.com/backend1/api/deployment/info"
else
    ENDPOINT_URL="https://api.mydomain.com/backend1/api/deployment/info"
fi

# Verify rollback
RESPONSE=$(curl -s ${ENDPOINT_URL} | jq -r '.deploymentSlot')
if [ "$RESPONSE" = "$PREVIOUS_SLOT" ]; then
    echo "✅ Rollback successful - now serving from ${PREVIOUS_SLOT} slot"
else
    echo "❌ Rollback verification failed - received: ${RESPONSE}"
fi
```

### **Full Environment Rollback (If Traffic Switch Fails)**

#### **1. Redeploy Previous Version**
```bash
# Get previous working image from ACR
ACR_NAME="your-acr-name"
PREVIOUS_IMAGE_TAG=$(az acr repository show-tags --name ${ACR_NAME} --repository ${APP_NAME} --top 5 --orderby time_desc | jq -r '.[1]')
PREVIOUS_IMAGE="${ACR_NAME}.azurecr.io/${APP_NAME}:${PREVIOUS_IMAGE_TAG}"

echo "🔄 Redeploying previous version: ${PREVIOUS_IMAGE}"

# Use the deployment script with force deploy
cd /path/to/your/scripts
./deploy.sh -e ${ENV} -i ${PREVIOUS_IMAGE} -f
```

#### **2. Monitor Full Redeployment**
```bash
# Monitor both slots
watch -n 5 "echo 'Blue Slot:' && kubectl get pods -n ${ENV}-${APP_NAME}-blue && echo 'Green Slot:' && kubectl get pods -n ${ENV}-${APP_NAME}-green"
```

## 🚨 **Emergency Rollback Procedures**

### **Critical Incident Response**

#### **1. Immediate Assessment (0-2 minutes)**
```bash
#!/bin/bash
# emergency-assessment.sh

ENV=$1
APP_NAME="java-backend1"

echo "🚨 EMERGENCY ROLLBACK ASSESSMENT"
echo "================================"

# Quick health check
echo "1. Checking application health..."
curl -f https://${ENV}.mydomain.com/backend1/actuator/health || echo "❌ Health check FAILED"

# Check pod status
echo "2. Checking pod status..."
kubectl get pods -l app=${APP_NAME} --all-namespaces

# Check recent events
echo "3. Checking recent events..."
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -10

# Check resource usage
echo "4. Checking resource usage..."
kubectl top pods -l app=${APP_NAME} --all-namespaces 2>/dev/null || echo "Metrics not available"

echo "Assessment complete."
```

#### **2. Automated Emergency Rollback**
```bash
#!/bin/bash
# emergency-rollback.sh

ENV=$1
APP_NAME="java-backend1"

if [ -z "$ENV" ]; then
    echo "Usage: $0 <environment>"
    echo "Environments: dev, sqe, ppr, prod"
    exit 1
fi

echo "🚨 EXECUTING EMERGENCY ROLLBACK FOR ${ENV}"

# Get AKS context
az aks get-credentials --resource-group "rg-${APP_NAME}-${ENV}" --name "aks-${APP_NAME}-${ENV}" --overwrite-existing

case $ENV in
    "dev"|"sqe")
        echo "Rolling deployment rollback..."
        helm rollback ${APP_NAME} 0 -n default  # 0 = previous revision
        kubectl rollout status deployment/${APP_NAME} -n default --timeout=300s
        ;;
    "ppr"|"prod")
        echo "Blue-Green traffic switch rollback..."
        
        # Get current and previous slots
        CURRENT_SLOT=$(kubectl get ingress ${APP_NAME}-ingress -n default -o jsonpath='{.metadata.labels.active-slot}')
        PREVIOUS_SLOT=$( [ "$CURRENT_SLOT" = "blue" ] && echo "green" || echo "blue" )
        
        # Switch traffic
        PREVIOUS_NS="${ENV}-${APP_NAME}-${PREVIOUS_SLOT}"
        INGRESS_HOST=$( [ "$ENV" = "ppr" ] && echo "preprod.mydomain.com" || echo "api.mydomain.com" )
        
        kubectl patch ingress ${APP_NAME}-ingress -n default --type='merge' \
          -p='{"spec":{"rules":[{"host":"'${INGRESS_HOST}'","http":{"paths":[{"path":"/(backend1/|$)(.*)","pathType":"ImplementationSpecific","backend":{"service":{"name":"'${APP_NAME}'","namespace":"'${PREVIOUS_NS}'","port":{"number":8080}}}}]}}]}}'
        
        kubectl label ingress ${APP_NAME}-ingress -n default active-slot=${PREVIOUS_SLOT} --overwrite
        ;;
esac

# Verify rollback
sleep 30
./health-check.sh ${ENV}

echo "✅ Emergency rollback completed for ${ENV}"
```

## 🗄️ **Database Rollback Procedures**

### **Database Migration Rollback**

#### **1. Check Migration Status**
```bash
# Connect to database and check Flyway schema history
ENVIRONMENT=$1  # dev, sqe, ppr, prod

# Get database connection details from Key Vault
# (This would be automated in practice)
DB_HOST="db-${ENVIRONMENT}.postgres.database.azure.com"
DB_NAME="java-backend1_${ENVIRONMENT}"
DB_USER="java-backend1_user_${ENVIRONMENT}"

# Check current schema version
kubectl exec -it deployment/java-backend1 -n default -- \
  psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} \
  -c "SELECT version, description, installed_on FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;"
```

#### **2. Create Database Backup**
```bash
# Create backup before rollback
BACKUP_FILE="backup_${ENVIRONMENT}_$(date +%Y%m%d_%H%M%S).sql"

kubectl exec -it deployment/java-backend1 -n default -- \
  pg_dump -h ${DB_HOST} -U ${DB_USER} ${DB_NAME} > ${BACKUP_FILE}

echo "Database backup created: ${BACKUP_FILE}"
```

#### **3. Execute Database Rollback**
```bash
# Method 1: Using Flyway undo migrations (if available)
kubectl exec -it deployment/java-backend1 -n default -- \
  java -jar flyway.jar undo -url=jdbc:postgresql://${DB_HOST}:5432/${DB_NAME} -user=${DB_USER}

# Method 2: Manual rollback script
kubectl exec -it deployment/java-backend1 -n default -- \
  psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} \
  -f /app/db/rollback/V2_to_V1_rollback.sql
```

### **Data Consistency Verification**
```bash
# Verify data integrity after database rollback
kubectl exec -it deployment/java-backend1 -n default -- \
  psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} \
  -c "SELECT COUNT(*) FROM users; SELECT COUNT(*) FROM transactions;"

# Run application data validation
curl -X POST https://${ENVIRONMENT}.mydomain.com/backend1/api/admin/validate-data
```

## 🤖 **Automated Rollback Scripts**

### **Smart Rollback Decision Script**
```bash
#!/bin/bash
# smart-rollback.sh

ENV=$1
ISSUE_TYPE=$2  # application, database, performance, security

APP_NAME="java-backend1"

echo "🤖 Smart Rollback Analysis for ${ENV}"
echo "Issue Type: ${ISSUE_TYPE}"

# Get AKS context
az aks get-credentials --resource-group "rg-${APP_NAME}-${ENV}" --name "aks-${APP_NAME}-${ENV}" --overwrite-existing

# Health assessment
HEALTH_STATUS=$(curl -s -w "%{http_code}" -o /dev/null https://${ENV}.mydomain.com/backend1/actuator/health)

# Performance check
RESPONSE_TIME=$(curl -w "%{time_total}" -s -o /dev/null https://${ENV}.mydomain.com/backend1/api/deployment/info)

# Error rate check (last 5 minutes)
ERROR_COUNT=$(kubectl logs deployment/${APP_NAME} -n default --since=5m | grep -i error | wc -l)

echo "Health Status: ${HEALTH_STATUS}"
echo "Response Time: ${RESPONSE_TIME}s"
echo "Error Count (5min): ${ERROR_COUNT}"

# Decision logic
ROLLBACK_NEEDED=false

if [ ${HEALTH_STATUS} -ne 200 ]; then
    echo "❌ Health check failed"
    ROLLBACK_NEEDED=true
fi

if (( $(echo "${RESPONSE_TIME} > 5.0" | bc -l) )); then
    echo "❌ Response time degraded"
    ROLLBACK_NEEDED=true
fi

if [ ${ERROR_COUNT} -gt 10 ]; then
    echo "❌ High error rate detected"
    ROLLBACK_NEEDED=true
fi

if [ "$ROLLBACK_NEEDED" = true ]; then
    echo "🔄 Initiating automated rollback..."
    ./emergency-rollback.sh ${ENV}
else
    echo "✅ System appears stable, no rollback needed"
fi
```

### **Rollback Validation Script**
```bash
#!/bin/bash
# validate-rollback.sh

ENV=$1
APP_NAME="java-backend1"

echo "✅ Validating rollback for ${ENV}..."

# 1. Health endpoint test
echo "1. Testing health endpoint..."
if curl -f https://${ENV}.mydomain.com/backend1/actuator/health; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# 2. Functional test
echo "2. Testing core functionality..."
if curl -f https://${ENV}.mydomain.com/backend1/api/deployment/info; then
    echo "✅ Deployment info endpoint working"
else
    echo "❌ Core functionality test failed"
    exit 1
fi

# 3. Database connectivity test
echo "3. Testing database connectivity..."
kubectl exec deployment/${APP_NAME} -n default -- \
  curl -f http://localhost:8080/backend1/actuator/health/db || {
    echo "❌ Database connectivity test failed"
    exit 1
}

# 4. Performance baseline test
echo "4. Testing performance baseline..."
RESPONSE_TIME=$(curl -w "%{time_total}" -s -o /dev/null https://${ENV}.mydomain.com/backend1/api/deployment/info)
if (( $(echo "${RESPONSE_TIME} < 2.0" | bc -l) )); then
    echo "✅ Performance within acceptable limits: ${RESPONSE_TIME}s"
else
    echo "⚠️  Performance degraded: ${RESPONSE_TIME}s"
fi

# 5. Check for errors in logs
echo "5. Checking error logs..."
ERROR_COUNT=$(kubectl logs deployment/${APP_NAME} -n default --since=2m | grep -i error | wc -l)
if [ ${ERROR_COUNT} -eq 0 ]; then
    echo "✅ No errors found in recent logs"
else
    echo "⚠️  Found ${ERROR_COUNT} errors in logs"
fi

echo "✅ Rollback validation completed successfully"
```

## 🔍 **Verification and Validation**

### **Post-Rollback Checklist**

#### **Application Level Verification**
```bash
# Application health verification script
verify_application_health() {
    local ENV=$1
    
    echo "🔍 Verifying Application Health for ${ENV}"
    
    # Health endpoints
    curl -f https://${ENV}.mydomain.com/backend1/actuator/health
    curl -f https://${ENV}.mydomain.com/backend1/actuator/health/liveness
    curl -f https://${ENV}.mydomain.com/backend1/actuator/health/readiness
    
    # Core API endpoints
    curl -f https://${ENV}.mydomain.com/backend1/api/deployment/info
    
    # Performance test
    ab -n 100 -c 10 https://${ENV}.mydomain.com/backend1/api/deployment/info
}
```

#### **Infrastructure Level Verification**
```bash
# Infrastructure verification script
verify_infrastructure() {
    local ENV=$1
    local APP_NAME="java-backend1"
    
    echo "🔍 Verifying Infrastructure for ${ENV}"
    
    # Pod status
    kubectl get pods -l app=${APP_NAME} --all-namespaces
    
    # Service status
    kubectl get svc -l app=${APP_NAME} --all-namespaces
    
    # Ingress status
    kubectl get ingress --all-namespaces
    
    # Resource usage
    kubectl top pods -l app=${APP_NAME} --all-namespaces
    
    # Recent events
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
}
```

### **Monitoring and Alerting Verification**
```bash
# Check monitoring systems
verify_monitoring() {
    local ENV=$1
    
    echo "🔍 Verifying Monitoring Systems"
    
    # Prometheus metrics
    curl -f https://${ENV}.mydomain.com/backend1/actuator/prometheus
    
    # Application Insights (if configured)
    # Check Azure portal for telemetry data
    
    # Log aggregation verification
    kubectl logs deployment/java-backend1 -n default --tail=50
}
```

## 📊 **Post-Rollback Analysis**

### **Incident Report Template**
```markdown
# Incident Report: Rollback Executed

## Incident Summary
- **Date/Time**: [YYYY-MM-DD HH:MM UTC]
- **Environment**: [dev/sqe/ppr/prod]
- **Duration**: [Minutes from issue detection to resolution]
- **Impact**: [User impact description]

## Root Cause Analysis
- **Primary Cause**: [What caused the need for rollback]
- **Contributing Factors**: [Secondary issues that escalated the problem]
- **Detection Method**: [How was the issue discovered]

## Rollback Details
- **Rollback Method**: [Blue-Green switch / Helm rollback / Manual]
- **Previous Version**: [Version/image tag rolled back to]
- **Rollback Duration**: [Time taken for rollback execution]
- **Verification Results**: [Post-rollback validation results]

## Action Items
- [ ] Fix root cause in development
- [ ] Update monitoring/alerting
- [ ] Improve deployment validation
- [ ] Update documentation
- [ ] Team training needs

## Lessons Learned
- [What went well during the rollback]
- [What could be improved]
- [Process improvements needed]
```

### **Automated Post-Rollback Report**
```bash
#!/bin/bash
# generate-rollback-report.sh

ENV=$1
ROLLBACK_TIME=$2
APP_NAME="java-backend1"

echo "📊 Generating Post-Rollback Report for ${ENV}"

# Collect data
CURRENT_VERSION=$(curl -s https://${ENV}.mydomain.com/backend1/api/deployment/info | jq -r '.version')
CURRENT_SLOT=$(kubectl get ingress ${APP_NAME}-ingress -n default -o jsonpath='{.metadata.labels.active-slot}' 2>/dev/null || echo "N/A")

# Performance metrics
RESPONSE_TIME=$(curl -w "%{time_total}" -s -o /dev/null https://${ENV}.mydomain.com/backend1/api/deployment/info)
ERROR_COUNT=$(kubectl logs deployment/${APP_NAME} -n default --since=10m | grep -i error | wc -l)

# Generate report
cat << EOF > rollback-report-${ENV}-$(date +%Y%m%d_%H%M%S).md
# Rollback Report - ${ENV} Environment

## Rollback Summary
- **Environment**: ${ENV}
- **Rollback Time**: ${ROLLBACK_TIME}
- **Current Version**: ${CURRENT_VERSION}
- **Current Slot**: ${CURRENT_SLOT}

## Post-Rollback Metrics
- **Response Time**: ${RESPONSE_TIME}s
- **Error Count (10min)**: ${ERROR_COUNT}
- **Health Status**: $(curl -s -w "%{http_code}" -o /dev/null https://${ENV}.mydomain.com/backend1/actuator/health)

## Pod Status
\`\`\`
$(kubectl get pods -l app=${APP_NAME} --all-namespaces)
\`\`\`

## Recent Events
\`\`\`
$(kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -10)
\`\`\`

Generated at: $(date)
EOF

echo "Report generated: rollback-report-${ENV}-$(date +%Y%m%d_%H%M%S).md"
```

## 🛡️ **Prevention and Best Practices**

### **Pre-Deployment Validation**
```bash
# Enhanced pre-deployment validation
validate_before_deploy() {
    local ENV=$1
    local IMAGE_TAG=$2
    
    echo "🛡️ Pre-deployment validation for ${ENV}"
    
    # 1. Image security scan
    trivy image ${ACR_NAME}.azurecr.io/${APP_NAME}:${IMAGE_TAG}
    
    # 2. Configuration validation
    helm template ${APP_NAME} ./helm -f ./helm/values-${ENV}.yaml --dry-run
    
    # 3. Resource validation
    kubectl apply --dry-run=client -f <(helm template ${APP_NAME} ./helm -f ./helm/values-${ENV}.yaml)
    
    # 4. Smoke test on staging slot (for Blue-Green)
    if [[ "$ENV" == "ppr" || "$ENV" == "prod" ]]; then
        # Deploy to staging slot and run tests
        echo "Running staging slot validation..."
    fi
}
```

### **Automated Rollback Triggers**
```yaml
# alerts.yaml - Example Prometheus alerts for automatic rollback
groups:
  - name: rollback-triggers
    rules:
      - alert: HighErrorRate
        expr: (rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])) > 0.1
        for: 2m
        annotations:
          summary: "High error rate detected - consider rollback"
          
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 5
        for: 3m
        annotations:
          summary: "High response time detected - consider rollback"
          
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 1m
        annotations:
          summary: "Pod crash loop detected - immediate rollback needed"
```

### **Blue-Green Deployment Best Practices**
```yaml
Best Practices:
1. Always maintain the previous slot in ready state
2. Implement comprehensive health checks
3. Use feature flags for risky changes
4. Implement automated canary analysis (future enhancement)
5. Maintain database backward compatibility
6. Test rollback procedures regularly
7. Monitor both slots during deployment
8. Keep detailed deployment logs
9. Implement circuit breakers for external dependencies
10. Use gradual traffic shifting for high-risk deployments
```

### **Rollback Testing Schedule**
```bash
# Monthly rollback drill script
#!/bin/bash
# rollback-drill.sh

ENVIRONMENTS=("dev" "sqe" "ppr")

for ENV in "${ENVIRONMENTS[@]}"; do
    echo "🔄 Starting rollback drill for ${ENV}"
    
    # Record current state
    CURRENT_STATE=$(kubectl get deployment java-backend1 -n default -o jsonpath='{.spec.template.spec.containers[0].image}')
    
    # Simulate deployment
    echo "Deploying test version..."
    kubectl set image deployment/java-backend1 java-backend1=nginx:latest -n default
    
    # Wait for deployment
    kubectl rollout status deployment/java-backend1 -n default
    
    # Execute rollback
    echo "Executing rollback..."
    ./emergency-rollback.sh ${ENV}
    
    # Verify rollback
    ./validate-rollback.sh ${ENV}
    
    echo "✅ Rollback drill completed for ${ENV}"
done

echo "🎯 All rollback drills completed successfully"
```

This comprehensive rollback guide provides detailed procedures for all scenarios and environments, ensuring rapid recovery when issues occur!