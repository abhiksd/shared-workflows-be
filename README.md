# Java Backend1 - Blue-Green Deployment Ready

A Spring Boot microservice with advanced Blue-Green deployment strategy for zero-downtime production releases.

## 🎯 **Overview**

This service implements a **Blue-Green deployment strategy** using namespace-based approach within a single AKS cluster, providing:
- ✅ **Zero-downtime deployments**
- ✅ **Instant rollback capability** (< 30 seconds)
- ✅ **Canary traffic validation** (5% → 100%)
- ✅ **Production approval gates**
- ✅ **Automated quality checks**

## 🏗️ **Deployment Architecture**

### **Environment Strategy**
```yaml
dev:  Rolling Deployment     # Fast iteration
sqe:  Rolling Deployment     # System Quality Engineering  
ppr:  Rolling Deployment     # Pre-Production validation
prod: Blue-Green + Canary    # Maximum safety
```

### **Production Blue-Green Architecture**
```
Single AKS Cluster: aks-prod-cluster
├── Namespace: prod-java-backend1-blue (Active)
│   ├── Deployment: java-backend1 v1.0
│   ├── Service: java-backend1-service  
│   └── Pods: 3 replicas
└── Namespace: prod-java-backend1-green (Target)
    ├── Deployment: java-backend1 v2.0
    ├── Service: java-backend1-service
    └── Pods: 3 replicas

Traffic Manager:
├── Main Ingress → Blue (100% traffic)
└── Canary Ingress → Green (0% → 100%)
```

## 🚀 **Quick Start**

### **Local Development**
```bash
# Build and run locally
mvn clean spring-boot:run

# Run with environment profile
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# Docker development
docker build -t java-backend1 .
docker run -p 8080:8080 java-backend1
```

### **Deployment Commands**

#### **Automatic Deployment (Branch-based)**
```bash
# Development deployment
git push origin develop

# SQE deployment  
git push origin main

# Pre-production deployment
git checkout -b release/v2.0.0
git push origin release/v2.0.0

# Production deployment (with approval)
git tag v2.0.0
git push origin v2.0.0
```

#### **Manual Deployment**
```bash
# GitHub CLI deployment
gh workflow run deploy.yml -f environment=dev
gh workflow run deploy.yml -f environment=sqe  
gh workflow run deploy.yml -f environment=ppr
gh workflow run deploy.yml -f environment=prod

# Force deployment (skip change detection)
gh workflow run deploy.yml -f environment=prod -f force_deploy=true
```

## 🛡️ **Production Deployment Flow**

### **Phase 1: Quality Gates**
```yaml
1. Code pushed to tag (refs/tags/v*)
2. Maven build and testing
3. SonarQube quality analysis (must pass)
4. Checkmarx security scan (must pass)
5. Docker image build and push
```

### **Phase 2: Blue-Green Preparation**
```yaml
6. Detect current active slot (blue/green)
7. Deploy new version to inactive slot
8. Health checks on new deployment
9. Smoke tests and validation
```

### **Phase 3: Manual Approval**
```yaml
10. Manual approval required in GitHub Actions
11. Approval shows:
    - Application version and details
    - Quality gate status
    - Deployment slot information
    - AKS cluster details
```

### **Phase 4: Canary Validation**
```yaml
12. Start canary traffic: 5% to new version
13. Monitor for 5 minutes (configurable)
14. Increase traffic: 5% → 10% → 25% → 50%
15. Monitor health metrics at each step
16. Auto-rollback if thresholds exceeded
```

### **Phase 5: Production Switch**
```yaml
17. Full traffic switch: 100% to new version
18. Update ingress and labels
19. Previous version kept as standby
20. Deployment complete
```

## 🔧 **Configuration**

### **Environment Files**
```
helm/
├── values-dev.yaml   # Development environment
├── values-sqe.yaml   # System Quality Engineering
├── values-ppr.yaml   # Pre-production
└── values-prod.yaml  # Production (Blue-Green enabled)
```

### **Blue-Green Configuration (Production)**
```yaml
global:
  environment: prod
  blueGreenEnabled: true
  deploymentSlot: "blue"  # Set by workflow

ingress:
  hosts:
    - host: api.mydomain.com
  blueGreen:
    canaryWeight: 0
    canaryHeader: "X-Canary-Deploy"
    canaryHeaderValue: "green"
```

### **Environment Variables**
| Variable | Description | Example |
|----------|-------------|---------|
| `ENVIRONMENT` | Deployment environment | `prod` |
| `DEPLOYMENT_SLOT` | Blue-Green slot | `blue`/`green` |
| `APPLICATION_NAME` | Service identifier | `java-backend1` |
| `SPRING_PROFILES_ACTIVE` | Spring profile | `prod` |

## 📊 **Monitoring & Health Checks**

### **Health Endpoints**
- **Liveness**: `/actuator/health/liveness`
- **Readiness**: `/actuator/health/readiness`  
- **Health**: `/actuator/health`
- **Metrics**: `/actuator/prometheus`

### **Auto-Rollback Triggers**
```yaml
Error Rate: > 0.1%
Response Time: > 2x baseline
CPU Usage: > 80%
Memory Usage: > 90%
Pod Restart Count: > 3
Custom Business Metrics: Configurable
```

### **Monitoring Stack**
- **Prometheus**: Metrics collection
- **Grafana**: Dashboards and alerting
- **Azure Monitor**: Infrastructure monitoring
- **Application Insights**: APM and logging

## 🔄 **Rollback Procedures**

### **Instant Rollback (Production)**
```bash
# Option 1: GitHub Actions manual trigger
gh workflow run deploy.yml -f environment=prod -f rollback=true

# Option 2: kubectl direct (emergency)
kubectl patch ingress prod-java-backend1-ingress -n default \
  -p '{"spec":{"rules":[{"host":"api.mydomain.com","http":{"paths":[{"backend":{"service":{"namespace":"prod-java-backend1-blue"}}}]}}]}}'
```

### **Rollback Verification**
```bash
# Check active namespace
kubectl get ingress prod-java-backend1-ingress -n default -o yaml

# Verify pod health
kubectl get pods -n prod-java-backend1-blue
kubectl get pods -n prod-java-backend1-green

# Test application health
curl https://api.mydomain.com/actuator/health
```

## 🛠️ **Troubleshooting**

### **Common Issues**

#### **Deployment Stuck in Canary**
```bash
# Check canary ingress weight
kubectl get ingress prod-java-backend1-ingress-canary -n default -o yaml

# Check target namespace pods
kubectl get pods -n prod-java-backend1-green

# View deployment logs
kubectl logs deployment/java-backend1 -n prod-java-backend1-green
```

#### **Health Check Failures**
```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# View application logs
kubectl logs <pod-name> -n <namespace> --tail=100

# Test health endpoint
kubectl port-forward pod/<pod-name> 8080:8080 -n <namespace>
curl http://localhost:8080/actuator/health
```

#### **Ingress Issues**
```bash
# Check ingress status
kubectl get ingress -n default
kubectl describe ingress prod-java-backend1-ingress -n default

# View nginx ingress logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## 📚 **Additional Resources**

- **[Deployment Guide](./docs/DEPLOYMENT.md)** - Detailed deployment procedures
- **[Blue-Green Strategy](./docs/BLUE-GREEN.md)** - In-depth Blue-Green explanation
- **[Runbooks](./docs/RUNBOOKS.md)** - Operational procedures
- **[Scripts](./scripts/)** - Automation scripts and utilities

## 🔗 **Repository Structure**
```
├── .github/workflows/deploy.yml    # Caller workflow
├── helm/                           # Helm charts
│   ├── templates/                  # K8s templates (Blue-Green ready)
│   ├── values-dev.yaml            # Development config
│   ├── values-sqe.yaml            # SQE config  
│   ├── values-ppr.yaml            # Pre-production config
│   └── values-prod.yaml           # Production config (Blue-Green)
├── src/                           # Application source
├── scripts/                       # Deployment utilities
├── docs/                          # Documentation
└── Dockerfile                     # Container definition
```

## 🎯 **Getting Started**

1. **Clone the repository**
2. **Set up local development** with `mvn spring-boot:run`
3. **Make changes** and push to `develop` for automatic dev deployment
4. **Create release branch** for pre-production testing
5. **Tag for production** deployment with manual approval
6. **Monitor deployment** through GitHub Actions and Azure Portal

Your application is now ready for **enterprise-grade Blue-Green deployments** with **zero-downtime** and **instant rollback** capabilities! 🚀
