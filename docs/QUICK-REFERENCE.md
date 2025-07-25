# 🚀 Blue-Green Deployment Quick Reference

## 📋 **Common Commands**

### **Deployment Commands**
```bash
# Deploy to development
./scripts/deploy.sh dev

# Deploy to SQE
./scripts/deploy.sh sqe

# Deploy to pre-production
./scripts/deploy.sh ppr

# Deploy to production (with approval)
./scripts/deploy.sh prod

# Force deployment
./scripts/deploy.sh prod true
```

### **Monitoring & Health Checks**
```bash
# Monitor Blue-Green deployment
./scripts/monitor-deployment.sh

# Check application health
./scripts/health-check.sh

# Check specific namespace
./scripts/health-check.sh prod-java-backend1-green

# GitHub Actions status
gh run list --workflow=deploy.yml
gh run watch
```

### **Kubernetes Commands**
```bash
# Check namespaces
kubectl get namespace | grep java-backend1

# Check pods in blue namespace
kubectl get pods -n prod-java-backend1-blue

# Check pods in green namespace
kubectl get pods -n prod-java-backend1-green

# Check ingress status
kubectl get ingress -n default

# Check canary weight
kubectl get ingress prod-java-backend1-ingress-canary -n default \
  -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}'
```

## 🛡️ **Emergency Procedures**

### **Instant Rollback**
```bash
# Switch traffic back to blue namespace
kubectl patch ingress prod-java-backend1-ingress -n default \
  --type='merge' \
  -p='{"spec":{"rules":[{"host":"api.mydomain.com","http":{"paths":[{"path":"/(backend1/|$)(.*)","pathType":"ImplementationSpecific","backend":{"service":{"name":"java-backend1-service","namespace":"prod-java-backend1-blue","port":{"number":80}}}}]}}]}}'

# Verify rollback
kubectl get ingress prod-java-backend1-ingress -n default -o yaml | grep namespace
```

### **Stop Canary Deployment**
```bash
# Set canary weight to 0
kubectl patch ingress prod-java-backend1-ingress-canary -n default \
  -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"0"}}}'
```

## 📊 **Health Check URLs**
```bash
# External health checks
curl https://api.mydomain.com/actuator/health
curl https://api.mydomain.com/actuator/health/readiness
curl https://api.mydomain.com/actuator/health/liveness

# Test canary deployment
curl -H "X-Canary-Deploy: green" https://api.mydomain.com/actuator/health
```

## 🔍 **Troubleshooting**

### **Check Pod Issues**
```bash
# Describe problematic pods
kubectl describe pods -n prod-java-backend1-green

# View pod logs
kubectl logs -n prod-java-backend1-green deployment/java-backend1 --tail=50

# Check events
kubectl get events -n prod-java-backend1-green --sort-by='.lastTimestamp'
```

### **Debug Ingress**
```bash
# Check NGINX ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | tail -50

# Test service connectivity
kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- /bin/sh
```

## 🎯 **Environment Mapping**

| Environment | Branch/Tag | Automatic | Approval Required |
|-------------|------------|-----------|-------------------|
| **dev** | `develop` | ✅ | ❌ |
| **sqe** | `main` | ✅ | ❌ |
| **ppr** | `release/*` | ✅ | ❌ |
| **prod** | `tags` | ✅ | ✅ Manual |

## 📱 **Useful Aliases**
Add to your `.bashrc` or `.zshrc`:
```bash
# Blue-Green deployment aliases
alias bg-deploy="./scripts/deploy.sh"
alias bg-monitor="./scripts/monitor-deployment.sh"
alias bg-health="./scripts/health-check.sh"

# Kubernetes shortcuts
alias k="kubectl"
alias kgp="kubectl get pods"
alias kgi="kubectl get ingress"
alias kd="kubectl describe"

# Blue-Green specific
alias blue-pods="kubectl get pods -n prod-java-backend1-blue"
alias green-pods="kubectl get pods -n prod-java-backend1-green"
alias canary-weight="kubectl get ingress prod-java-backend1-ingress-canary -n default -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}'"
```

## 🚨 **Emergency Contacts**
- **GitHub Repository**: [Your Repository URL]
- **Azure Portal**: [AKS Cluster URL]
- **Monitoring**: [Grafana/Azure Monitor URL]
- **Incident Response**: [Your process URL]

## 📊 **Key Metrics**
- **Error Rate**: < 0.1%
- **Response Time**: < 500ms (P95)
- **Pod Restart Count**: < 3 per hour
- **Memory Usage**: < 90%
- **CPU Usage**: < 80%