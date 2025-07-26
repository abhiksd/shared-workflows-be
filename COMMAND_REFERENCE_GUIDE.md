# Command Reference Guide

## 🎯 Overview

This guide provides a quick reference for all commonly used commands in the deployment pipeline. Instead of searching through extensive documentation, you can quickly find the exact command you need here.

## 🚨 **Emergency Curl Commands (Quick Reference)**

### **SonarQube Quick Check**
```bash
# Check status and quality gate
curl -u admin:admin http://sonar-server:9000/api/system/status
curl -u admin:admin "http://sonar-server:9000/api/qualitygates/project_status?projectKey=my-project"
```

### **Checkmarx Quick Check**
```bash
# Get token and check status
curl -X POST "https://checkmarx-server/cxrestapi/auth/identity/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=user&password=pass&grant_type=password&scope=sast_rest_api&client_id=resource_owner_client&client_secret=014DF517-39D1-4453-B7B3-9930C563627C"

curl -X GET "https://checkmarx-server/cxrestapi/sast/scans/scan-id" \
  -H "Authorization: Bearer your-token"
```

### **Application Health Quick Check**
```bash
# Spring Boot Actuator
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/health/readiness
```

### **GitHub API Quick Check**
```bash
# Check workflow status
curl -H "Authorization: token your-token" \
  https://api.github.com/repos/owner/repo/actions/runs

# Check repository variables
curl -H "Authorization: token your-token" \
  https://api.github.com/repos/owner/repo/actions/variables
```

## 📋 Quick Navigation

- [🐳 Docker Commands](#-docker-commands)
- [⎈ Kubernetes (kubectl) Commands](#-kubernetes-kubectl-commands)
- [🚢 Helm Commands](#-helm-commands)
- [☁️ Azure CLI Commands](#️-azure-cli-commands)
- [🔧 Git Commands](#-git-commands)
- [🐙 GitHub CLI Commands](#-github-cli-commands)
- [🏗️ Maven Commands](#️-maven-commands)
- [📊 Monitoring Commands](#-monitoring-commands)
- [🔍 Troubleshooting Commands](#-troubleshooting-commands)
  - [SonarQube Troubleshooting](#sonarqube-troubleshooting)
  - [Checkmarx Troubleshooting](#checkmarx-troubleshooting)
  - [Application Health & API Testing](#application-health-and-api-troubleshooting)
  - [GitHub API Troubleshooting](#github-api-troubleshooting)
  - [Azure Services Troubleshooting](#azure-services-troubleshooting)
  - [Emergency Debugging](#emergency-debugging-commands)
  - [Pipeline Debugging](#pipeline-debugging-workflows)

## 🐳 Docker Commands

### **Basic Docker Operations**
```bash
# Build image
docker build -t my-app:latest .
docker build -t my-app:v1.0.0 -f Dockerfile .

# Run container
docker run -d -p 8080:8080 my-app:latest
docker run -it --rm my-app:latest /bin/bash

# List images and containers
docker images
docker ps
docker ps -a

# Remove images and containers
docker rmi my-app:latest
docker rm container-id
docker system prune -a
```

### **Registry Operations**
```bash
# Login to registry
docker login myregistry.azurecr.io

# Tag and push
docker tag my-app:latest myregistry.azurecr.io/my-app:latest
docker push myregistry.azurecr.io/my-app:latest

# Pull image
docker pull myregistry.azurecr.io/my-app:latest

# List registry repositories
az acr repository list --name myregistry
```

### **Docker Compose**
```bash
# Start services
docker-compose up -d
docker-compose up --build

# Stop services  
docker-compose down
docker-compose down -v

# View logs
docker-compose logs -f
docker-compose logs app
```

## ⎈ Kubernetes (kubectl) Commands

### **Cluster and Context**
```bash
# Get current context
kubectl config current-context
kubectl config get-contexts

# Switch context
kubectl config use-context my-cluster

# Set namespace
kubectl config set-context --current --namespace=my-namespace
```

### **Deployments and Pods**
```bash
# Get resources
kubectl get pods
kubectl get deployments
kubectl get services
kubectl get ingress
kubectl get all

# Describe resources
kubectl describe pod pod-name
kubectl describe deployment deployment-name
kubectl describe service service-name

# Get pod logs
kubectl logs pod-name
kubectl logs -f deployment-name
kubectl logs pod-name -c container-name

# Execute commands in pod
kubectl exec -it pod-name -- /bin/bash
kubectl exec -it pod-name -- sh
```

### **Resource Management**
```bash
# Apply configurations
kubectl apply -f deployment.yaml
kubectl apply -f .
kubectl apply -k .

# Delete resources
kubectl delete -f deployment.yaml
kubectl delete pod pod-name
kubectl delete deployment deployment-name

# Scale deployments
kubectl scale deployment deployment-name --replicas=3
kubectl autoscale deployment deployment-name --min=2 --max=10 --cpu-percent=80
```

### **Debugging and Troubleshooting**
```bash
# Get events
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector involvedObject.name=pod-name

# Port forwarding
kubectl port-forward pod/pod-name 8080:8080
kubectl port-forward service/service-name 8080:80

# Copy files
kubectl cp pod-name:/path/to/file /local/path
kubectl cp /local/file pod-name:/path/to/destination

# Check resource usage
kubectl top nodes
kubectl top pods
```

### **ConfigMaps and Secrets**
```bash
# Create ConfigMap
kubectl create configmap my-config --from-file=config.properties
kubectl create configmap my-config --from-literal=key1=value1

# Create Secret
kubectl create secret generic my-secret --from-literal=password=secret123
kubectl create secret docker-registry regcred --docker-server=myregistry.azurecr.io --docker-username=user --docker-password=pass

# Get ConfigMaps and Secrets
kubectl get configmaps
kubectl get secrets
kubectl describe configmap my-config
kubectl describe secret my-secret
```

## 🚢 Helm Commands

### **Chart Management**
```bash
# Create new chart
helm create my-app

# Validate chart
helm lint ./helm
helm template my-app ./helm
helm template my-app ./helm --values ./helm/values-dev.yaml

# Package chart
helm package ./helm
helm package ./helm --version 1.0.0
```

### **Installation and Upgrades**
```bash
# Install release
helm install my-app ./helm
helm install my-app ./helm --values ./helm/values-dev.yaml
helm install my-app ./helm --namespace my-namespace --create-namespace

# Upgrade release
helm upgrade my-app ./helm
helm upgrade my-app ./helm --values ./helm/values-prod.yaml
helm upgrade --install my-app ./helm

# Rollback release
helm rollback my-app 1
helm rollback my-app
```

### **Release Management**
```bash
# List releases
helm list
helm list --all-namespaces
helm list --namespace my-namespace

# Get release info
helm status my-app
helm history my-app
helm get values my-app
helm get manifest my-app

# Uninstall release
helm uninstall my-app
helm uninstall my-app --namespace my-namespace
```

### **Repository Management**
```bash
# Add repository
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repositories
helm repo update

# Search charts
helm search repo nginx
helm search hub wordpress

# Remove repository
helm repo remove stable
```

### **Debugging Helm**
```bash
# Dry run installation
helm install my-app ./helm --dry-run --debug

# Debug template rendering
helm template my-app ./helm --debug
helm template my-app ./helm --set image.tag=v2.0.0 --debug

# Test release
helm test my-app
```

## ☁️ Azure CLI Commands

### **Authentication and Subscription**
```bash
# Login
az login
az login --tenant tenant-id

# Set subscription
az account set --subscription subscription-id
az account show
az account list
```

### **AKS (Azure Kubernetes Service)**
```bash
# Get AKS credentials
az aks get-credentials --resource-group my-rg --name my-cluster
az aks get-credentials --resource-group my-rg --name my-cluster --overwrite-existing

# List AKS clusters
az aks list
az aks list --resource-group my-rg

# Show AKS cluster
az aks show --resource-group my-rg --name my-cluster
az aks show --resource-group my-rg --name my-cluster --query "powerState.code"

# Start/Stop AKS cluster
az aks start --resource-group my-rg --name my-cluster
az aks stop --resource-group my-rg --name my-cluster

# Scale AKS cluster
az aks scale --resource-group my-rg --name my-cluster --node-count 3
```

### **ACR (Azure Container Registry)**
```bash
# Login to ACR
az acr login --name myregistry

# List repositories
az acr repository list --name myregistry
az acr repository show-tags --name myregistry --repository my-app

# Delete image/tag
az acr repository delete --name myregistry --image my-app:v1.0.0
az acr repository delete --name myregistry --repository my-app --tag v1.0.0

# Import image
az acr import --name myregistry --source docker.io/nginx:latest --image nginx:latest
```

### **Resource Groups**
```bash
# Create resource group
az group create --name my-rg --location eastus

# List resource groups
az group list
az group list --query "[].{Name:name, Location:location}"

# Delete resource group
az group delete --name my-rg --yes --no-wait
```

### **Key Vault Operations**
```bash
# Create Key Vault
az keyvault create --name my-vault --resource-group my-rg --location eastus

# Set secret
az keyvault secret set --vault-name my-vault --name mysecret --value "secret-value"

# Get secret
az keyvault secret show --vault-name my-vault --name mysecret --query value

# List secrets
az keyvault secret list --vault-name my-vault
```

## 🔧 Git Commands

### **Basic Git Operations**
```bash
# Initialize repository
git init
git clone https://github.com/user/repo.git

# Check status and history
git status
git log --oneline
git log --graph --oneline --all

# Add and commit
git add .
git add file.txt
git commit -m "commit message"
git commit -am "add and commit"
```

### **Branch Management**
```bash
# Create and switch branches
git branch feature-branch
git checkout feature-branch
git checkout -b feature-branch

# List branches
git branch
git branch -a
git branch -r

# Merge and delete branches
git checkout main
git merge feature-branch
git branch -d feature-branch
git push origin --delete feature-branch
```

### **Remote Operations**
```bash
# Remote management
git remote -v
git remote add origin https://github.com/user/repo.git

# Push and pull
git push origin main
git push origin feature-branch
git pull origin main
git fetch origin

# Tags
git tag v1.0.0
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
git push origin --tags
```

### **Deployment Specific Git Commands**
```bash
# Deploy to environments via git
git checkout dev && git push origin dev           # Deploy to DEV
git checkout sqe && git push origin sqe           # Deploy to SQE
git checkout release/v1.0.0 && git push origin release/v1.0.0  # Deploy to PPR
git tag v1.0.0 && git push origin v1.0.0          # Deploy to PROD

# Create release branch
git checkout -b release/v1.0.0
git push origin release/v1.0.0
```

## 🐙 GitHub CLI Commands

### **Repository Operations**
```bash
# Clone repository
gh repo clone user/repo
gh repo create my-new-repo --public
gh repo create my-new-repo --private

# Repository info
gh repo view
gh repo view user/repo
```

### **Workflow Operations**
```bash
# List workflows
gh workflow list

# Run workflow
gh workflow run deploy.yml
gh workflow run deploy.yml -f environment=dev
gh workflow run deploy.yml -f environment=prod -f override_branch_validation=true

# View workflow runs
gh run list
gh run list --workflow=deploy.yml
gh run view run-id
gh run watch
```

### **Variables and Secrets**
```bash
# Repository variables
gh variable set EMERGENCY_BYPASS_SONAR --body "true"
gh variable list
gh variable delete EMERGENCY_BYPASS_SONAR

# Repository secrets
gh secret set MY_SECRET --body "secret-value"
gh secret list
gh secret delete MY_SECRET
```

### **Issues and Pull Requests**
```bash
# Create issue
gh issue create --title "Bug report" --body "Description"

# List issues
gh issue list
gh issue view issue-number

# Create pull request
gh pr create --title "Feature" --body "Description"
gh pr list
gh pr view pr-number
gh pr merge pr-number
```

## 🏗️ Maven Commands

### **Build and Test**
```bash
# Clean and compile
mvn clean
mvn compile
mvn clean compile

# Test
mvn test
mvn test -Dtest=MyTestClass
mvn clean test

# Package
mvn package
mvn clean package
mvn package -DskipTests

# Install to local repository
mvn install
mvn clean install
```

### **Spring Boot Specific**
```bash
# Run Spring Boot application
mvn spring-boot:run
mvn spring-boot:run -Dspring-boot.run.profiles=dev
mvn spring-boot:run -Dspring-boot.run.profiles=local

# Build Docker image (with Spring Boot plugin)
mvn spring-boot:build-image
mvn spring-boot:build-image -Dspring-boot.build-image.imageName=my-app:latest
```

### **Dependency Management**
```bash
# Show dependencies
mvn dependency:tree
mvn dependency:list

# Download sources
mvn dependency:sources
mvn dependency:resolve -Dclassifier=javadoc
```

## 📊 Monitoring Commands

### **Application Health Checks**
```bash
# Spring Boot Actuator endpoints
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/health/readiness
curl http://localhost:8080/actuator/health/liveness
curl http://localhost:8080/actuator/info
curl http://localhost:8080/actuator/metrics

# Kubernetes health checks
kubectl get pods --field-selector=status.phase=Running
kubectl get pods --field-selector=status.phase!=Running
```

### **Log Monitoring**
```bash
# Kubernetes logs
kubectl logs -f deployment/my-app
kubectl logs --tail=100 deployment/my-app
kubectl logs --since=1h deployment/my-app

# Follow logs from multiple pods
kubectl logs -f -l app=my-app
```

### **Resource Monitoring**
```bash
# Kubernetes resource usage
kubectl top nodes
kubectl top pods
kubectl top pods --containers

# Check pod resource limits
kubectl describe pod pod-name | grep -A 5 "Limits\|Requests"
```

## 🔍 Troubleshooting Commands

### **Common Deployment Issues**
```bash
# Check pod status and events
kubectl get pods
kubectl describe pod pod-name
kubectl get events --sort-by='.lastTimestamp'

# Check container logs
kubectl logs pod-name
kubectl logs pod-name -c container-name
kubectl logs --previous pod-name

# Debug failed deployments
kubectl describe deployment deployment-name
kubectl get replicasets
kubectl describe replicaset replicaset-name
```

### **Network Troubleshooting**
```bash
# Test service connectivity
kubectl exec -it pod-name -- nslookup service-name
kubectl exec -it pod-name -- curl service-name:80
kubectl exec -it pod-name -- telnet service-name 80

# Port forwarding for debugging
kubectl port-forward pod/pod-name 8080:8080
kubectl port-forward service/service-name 8080:80
```

### **Image and Registry Issues**
```bash
# Check image pull status
kubectl describe pod pod-name | grep -A 10 "Events"

# Test image pull manually
docker pull myregistry.azurecr.io/my-app:latest

# Check registry authentication
kubectl get secret regcred -o yaml
kubectl describe secret regcred
```

### **Helm Troubleshooting**
```bash
# Debug Helm releases
helm status my-app
helm history my-app
helm get manifest my-app
helm get values my-app

# Validate Helm templates
helm template my-app ./helm --debug
helm lint ./helm
```

### **SonarQube Troubleshooting**
```bash
# Check SonarQube server status
curl -u admin:admin http://sonar-server:9000/api/system/status
curl -H "Authorization: Bearer your-token" http://sonar-server:9000/api/system/status

# Check SonarQube health
curl -u admin:admin http://sonar-server:9000/api/system/health
curl -H "Authorization: Bearer your-token" http://sonar-server:9000/api/system/health

# Get project information
curl -u admin:admin "http://sonar-server:9000/api/projects/search?q=my-project"
curl -H "Authorization: Bearer your-token" "http://sonar-server:9000/api/projects/search?q=my-project"

# Check quality gate status
curl -u admin:admin "http://sonar-server:9000/api/qualitygates/project_status?projectKey=my-project"
curl -H "Authorization: Bearer your-token" "http://sonar-server:9000/api/qualitygates/project_status?projectKey=my-project"

# Get quality gate details
curl -u admin:admin "http://sonar-server:9000/api/qualitygates/show?id=1"
curl -H "Authorization: Bearer your-token" "http://sonar-server:9000/api/qualitygates/show?id=1"

# Check project metrics
curl -u admin:admin "http://sonar-server:9000/api/measures/component?component=my-project&metricKeys=coverage,bugs,vulnerabilities,code_smells"
curl -H "Authorization: Bearer your-token" "http://sonar-server:9000/api/measures/component?component=my-project&metricKeys=coverage,bugs,vulnerabilities,code_smells"

# Get analysis history
curl -u admin:admin "http://sonar-server:9000/api/project_analyses/search?project=my-project"
curl -H "Authorization: Bearer your-token" "http://sonar-server:9000/api/project_analyses/search?project=my-project"

# Check SonarQube version and plugins
curl -u admin:admin http://sonar-server:9000/api/system/info
curl -u admin:admin http://sonar-server:9000/api/plugins/installed

# Test webhook endpoints
curl -X POST -H "Content-Type: application/json" \
  -d '{"serverUrl":"http://sonar-server:9000","taskId":"task-123","status":"SUCCESS"}' \
  http://webhook-endpoint/sonar

# Check compute engine tasks
curl -u admin:admin "http://sonar-server:9000/api/ce/activity?component=my-project"
curl -H "Authorization: Bearer your-token" "http://sonar-server:9000/api/ce/activity?component=my-project"
```

### **Checkmarx Troubleshooting**
```bash
# Check Checkmarx server status
curl -X GET "https://checkmarx-server/cxrestapi/help/about" \
  -H "Accept: application/json"

# Authenticate and get token
curl -X POST "https://checkmarx-server/cxrestapi/auth/identity/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=your-username&password=your-password&grant_type=password&scope=sast_rest_api&client_id=resource_owner_client&client_secret=014DF517-39D1-4453-B7B3-9930C563627C"

# Check projects (with token)
curl -X GET "https://checkmarx-server/cxrestapi/projects" \
  -H "Authorization: Bearer your-access-token" \
  -H "Accept: application/json"

# Get project details
curl -X GET "https://checkmarx-server/cxrestapi/projects/project-id" \
  -H "Authorization: Bearer your-access-token" \
  -H "Accept: application/json"

# Check scan status
curl -X GET "https://checkmarx-server/cxrestapi/sast/scans/scan-id" \
  -H "Authorization: Bearer your-access-token" \
  -H "Accept: application/json"

# Get scan results
curl -X GET "https://checkmarx-server/cxrestapi/sast/scans/scan-id/results" \
  -H "Authorization: Bearer your-access-token" \
  -H "Accept: application/json"

# Check scan statistics
curl -X GET "https://checkmarx-server/cxrestapi/sast/scans/scan-id/resultsStatistics" \
  -H "Authorization: Bearer your-access-token" \
  -H "Accept: application/json"

# Get presets
curl -X GET "https://checkmarx-server/cxrestapi/sast/presets" \
  -H "Authorization: Bearer your-access-token" \
  -H "Accept: application/json"

# Check teams
curl -X GET "https://checkmarx-server/cxrestapi/auth/teams" \
  -H "Authorization: Bearer your-access-token" \
  -H "Accept: application/json"

# Generate report
curl -X POST "https://checkmarx-server/cxrestapi/reports/sastScan" \
  -H "Authorization: Bearer your-access-token" \
  -H "Content-Type: application/json" \
  -d '{"reportType":"PDF","scanId":scan-id}'

# Download report
curl -X GET "https://checkmarx-server/cxrestapi/reports/sastScan/report-id" \
  -H "Authorization: Bearer your-access-token" \
  -o "checkmarx-report.pdf"

# Check server health
curl -X GET "https://checkmarx-server/cxrestapi/system/version" \
  -H "Accept: application/json"
```

### **Application Health and API Troubleshooting**
```bash
# Spring Boot Actuator endpoints
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/health/readiness
curl http://localhost:8080/actuator/health/liveness
curl http://localhost:8080/actuator/info
curl http://localhost:8080/actuator/metrics
curl http://localhost:8080/actuator/env
curl http://localhost:8080/actuator/configprops

# Check specific metrics
curl http://localhost:8080/actuator/metrics/jvm.memory.used
curl http://localhost:8080/actuator/metrics/http.server.requests

# Application endpoints testing
curl -X GET http://localhost:8080/api/health \
  -H "Accept: application/json"

curl -X POST http://localhost:8080/api/test \
  -H "Content-Type: application/json" \
  -d '{"test":"data"}'

# Test with authentication
curl -X GET http://localhost:8080/api/secured \
  -H "Authorization: Bearer your-jwt-token" \
  -H "Accept: application/json"

# Database connectivity test (if exposed)
curl http://localhost:8080/actuator/health/db

# Check application logs endpoint (if available)
curl http://localhost:8080/actuator/loggers
curl http://localhost:8080/actuator/logfile
```

### **GitHub API Troubleshooting**
```bash
# Check GitHub API rate limits
curl -H "Authorization: token your-github-token" \
  https://api.github.com/rate_limit

# Check workflow runs
curl -H "Authorization: token your-github-token" \
  https://api.github.com/repos/owner/repo/actions/runs

# Get specific workflow run
curl -H "Authorization: token your-github-token" \
  https://api.github.com/repos/owner/repo/actions/runs/run-id

# Check workflow run logs
curl -L -H "Authorization: token your-github-token" \
  https://api.github.com/repos/owner/repo/actions/runs/run-id/logs

# Check repository variables
curl -H "Authorization: token your-github-token" \
  https://api.github.com/repos/owner/repo/actions/variables

# Check repository secrets (names only)
curl -H "Authorization: token your-github-token" \
  https://api.github.com/repos/owner/repo/actions/secrets

# Check workflow status
curl -H "Authorization: token your-github-token" \
  https://api.github.com/repos/owner/repo/actions/workflows

# Trigger workflow dispatch
curl -X POST \
  -H "Authorization: token your-github-token" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/owner/repo/actions/workflows/deploy.yml/dispatches \
  -d '{"ref":"main","inputs":{"environment":"dev"}}'
```

### **Azure Services Troubleshooting**
```bash
# Azure Resource Manager API
az rest --method GET --url "https://management.azure.com/subscriptions/subscription-id/resourceGroups/rg-name/providers/Microsoft.ContainerService/managedClusters/cluster-name?api-version=2021-05-01"

# Check AKS cluster health
az aks show --resource-group rg-name --name cluster-name --query "powerState"

# Check ACR health
az acr check-health --name registry-name

# Test ACR connectivity
curl -u username:password https://registry-name.azurecr.io/v2/_catalog

# Check Azure KeyVault (if using)
az keyvault show --name vault-name
curl -H "Authorization: Bearer azure-token" \
  "https://vault-name.vault.azure.net/secrets?api-version=7.3"

# Azure Monitor/Application Insights
curl -X GET \
  "https://api.applicationinsights.io/v1/apps/app-id/query" \
  -H "X-API-Key: api-key" \
  -H "Content-Type: application/json" \
  -d '{"query":"requests | take 10"}'
```

### **Database Connectivity Testing**
```bash
# PostgreSQL connection test
curl -X POST http://localhost:8080/actuator/health/db

# Test database endpoint (if exposed)
curl -X GET http://localhost:8080/api/db/health \
  -H "Accept: application/json"

# Redis connection test
curl http://localhost:8080/actuator/health/redis

# Test Redis directly (if accessible)
redis-cli -h redis-host -p 6379 ping
```

### **Load Balancer and Ingress Testing**
```bash
# Test ingress endpoints
curl -H "Host: my-app.example.com" http://ingress-ip/
curl -k https://my-app.example.com/health

# Test with different headers
curl -H "Host: my-app.example.com" \
     -H "X-Forwarded-Proto: https" \
     http://ingress-ip/api/test

# Check SSL certificate
curl -vI https://my-app.example.com 2>&1 | grep -A 10 "Server certificate"
openssl s_client -connect my-app.example.com:443 -servername my-app.example.com

# Test load balancer health checks
curl http://load-balancer-ip/health
curl -I http://load-balancer-ip/ping
```

### **Performance Testing**
```bash
# Simple load testing with curl
for i in {1..100}; do
  curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8080/api/test
done

# Create curl-format.txt for timing
echo "     time_namelookup:  %{time_namelookup}s
        time_connect:  %{time_connect}s
     time_appconnect:  %{time_appconnect}s
    time_pretransfer:  %{time_pretransfer}s
       time_redirect:  %{time_redirect}s
  time_starttransfer:  %{time_starttransfer}s
                     ----------
          time_total:  %{time_total}s" > curl-format.txt

# Concurrent requests testing
seq 1 10 | xargs -n1 -P10 curl -s http://localhost:8080/api/test

# HTTP/2 testing
curl --http2 -I https://my-app.example.com/
```

### **Docker Registry and Image Troubleshooting**
```bash
# Azure Container Registry (ACR) API testing
# Authenticate and get catalog
curl -u username:password https://registry-name.azurecr.io/v2/_catalog

# Get repository tags
curl -u username:password https://registry-name.azurecr.io/v2/my-app/tags/list

# Get image manifest
curl -u username:password \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  https://registry-name.azurecr.io/v2/my-app/manifests/latest

# Check registry health
curl https://registry-name.azurecr.io/v2/

# Docker Hub API testing
# Get repository information
curl https://hub.docker.com/v2/repositories/library/ubuntu/

# Get image tags
curl https://hub.docker.com/v2/repositories/library/ubuntu/tags/

# Private registry authentication test
curl -u "$DOCKER_USERNAME:$DOCKER_PASSWORD" \
  https://your-private-registry.com/v2/_catalog

# Test image pull without Docker (registry API)
TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/ubuntu:pull" | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" \
  https://registry-1.docker.io/v2/library/ubuntu/manifests/latest

# Check registry storage and cleanup API (if supported)
curl -X GET \
  -u username:password \
  https://registry-name.azurecr.io/v2/_catalog?n=100

# ACR webhook testing
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"id":"test","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","action":"push","target":{"repository":"my-app","tag":"latest"}}' \
  https://webhook-endpoint/acr
```

### **Docker Cleanup Monitoring**
```bash
# Monitor Docker system usage via API (if Docker API exposed)
curl --unix-socket /var/run/docker.sock http://localhost/system/df

# Get Docker system information
curl --unix-socket /var/run/docker.sock http://localhost/info

# List all images via API
curl --unix-socket /var/run/docker.sock http://localhost/images/json

# List all containers via API
curl --unix-socket /var/run/docker.sock http://localhost/containers/json?all=true

# Monitor Docker events via API
curl --unix-socket /var/run/docker.sock http://localhost/events

# Check Docker daemon health
curl --unix-socket /var/run/docker.sock http://localhost/version

# Docker stats via API
curl --unix-socket /var/run/docker.sock http://localhost/containers/json | \
  jq -r '.[].Id' | \
  xargs -I {} curl --unix-socket /var/run/docker.sock http://localhost/containers/{}/stats?stream=false

# Cleanup operation monitoring (if cleanup API exposed)
curl -X POST http://cleanup-service/api/cleanup \
  -H "Content-Type: application/json" \
  -d '{"level":"light","preserve_cache":true}'

# Check cleanup job status
curl http://cleanup-service/api/cleanup/status

# Get cleanup history
curl http://cleanup-service/api/cleanup/history

# Disk usage monitoring via API
curl http://monitoring-service/api/disk-usage

# Real-time cleanup monitoring
curl -N http://cleanup-service/api/cleanup/stream
```

### **Registry Cleanup and Maintenance**
```bash
# ACR repository cleanup (Azure CLI REST calls)
# List repositories for cleanup
curl -H "Authorization: Bearer $AZURE_TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ContainerRegistry/registries/$REGISTRY_NAME/repositories?api-version=2019-05-01"

# Delete old image tags
curl -X DELETE \
  -H "Authorization: Bearer $AZURE_TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ContainerRegistry/registries/$REGISTRY_NAME/repositories/my-app/tags/old-tag?api-version=2019-05-01"

# Purge deleted images (permanently delete)
curl -X POST \
  -H "Authorization: Bearer $AZURE_TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ContainerRegistry/registries/$REGISTRY_NAME/purgeManifests?api-version=2019-05-01" \
  -d '{"tagFilters":[".*"],"until":"2024-01-01T00:00:00Z"}'

# Registry storage usage
curl -H "Authorization: Bearer $AZURE_TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ContainerRegistry/registries/$REGISTRY_NAME/usage?api-version=2019-05-01"

# Private registry garbage collection (if supported)
curl -X POST \
  -u username:password \
  https://your-private-registry.com/api/v1/gc

# Registry catalog with size information
curl -u username:password \
  https://registry-name.azurecr.io/v2/_catalog | \
  jq -r '.repositories[]' | \
  while read repo; do
    echo "Repository: $repo"
    curl -u username:password \
      https://registry-name.azurecr.io/v2/$repo/tags/list
  done
```

### **Workflow-Specific Troubleshooting**
```bash
# Check GitHub workflow status via API
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/owner/repo/actions/runs | jq '.workflow_runs[0]'

# Check SonarQube quality gate from pipeline
curl -u "$SONAR_TOKEN:" \
  "$SONAR_HOST_URL/api/qualitygates/project_status?projectKey=$PROJECT_KEY" | jq '.'

# Check Checkmarx scan status from pipeline
curl -X GET "$CHECKMARX_SERVER/cxrestapi/sast/scans/$SCAN_ID" \
  -H "Authorization: Bearer $CX_TOKEN" | jq '.status'

# Verify Azure AKS cluster connectivity from pipeline
az aks get-credentials --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --overwrite-existing
kubectl cluster-info

# Test ACR authentication from pipeline
echo $ACR_PASSWORD | docker login $ACR_LOGIN_SERVER --username $ACR_USERNAME --password-stdin

# Check repository variables via API
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/owner/repo/actions/variables | jq '.variables'

# Validate emergency bypass status
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/owner/repo/actions/variables/EMERGENCY_BYPASS_SONAR

# Test Helm deployment dry run from pipeline
helm template my-app ./helm --values ./helm/values-$ENVIRONMENT.yaml --debug

# Check pod status after deployment
kubectl get pods -l app=my-app -o wide
kubectl describe pod $(kubectl get pods -l app=my-app -o jsonpath='{.items[0].metadata.name}')

# Verify service endpoints after deployment
kubectl get service my-app
kubectl describe service my-app
curl http://$(kubectl get service my-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/health

# Check ingress after deployment
kubectl get ingress my-app
curl -H "Host: my-app.domain.com" http://$(kubectl get ingress my-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/health
```

### **Emergency Debugging Commands**
```bash
# Quick health check of all pipeline components
echo "=== PIPELINE HEALTH CHECK ==="

# 1. Check SonarQube
echo "1. SonarQube Status:"
curl -s -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/system/status" | jq '.status' || echo "❌ SonarQube unreachable"

# 2. Check Checkmarx
echo "2. Checkmarx Status:"
curl -s -X GET "$CHECKMARX_SERVER/cxrestapi/help/about" | jq '.version' || echo "❌ Checkmarx unreachable"

# 3. Check AKS cluster
echo "3. AKS Cluster Status:"
az aks show --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "powerState.code" -o tsv || echo "❌ AKS unreachable"

# 4. Check ACR
echo "4. ACR Status:"
az acr check-health --name $ACR_NAME --query "status" -o tsv || echo "❌ ACR unreachable"

# 5. Check GitHub API
echo "5. GitHub API Status:"
curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit | jq '.rate.remaining' || echo "❌ GitHub API unreachable"

# Emergency deployment status check
echo "=== EMERGENCY DEPLOYMENT STATUS ==="
kubectl get pods -l app=my-app --field-selector=status.phase=Running
kubectl get pods -l app=my-app --field-selector=status.phase!=Running
kubectl get events --sort-by='.lastTimestamp' | grep my-app | tail -10

# Quick rollback command
echo "=== QUICK ROLLBACK ==="
helm rollback my-app
kubectl rollout status deployment/my-app --timeout=300s
```

### **Pipeline Debugging Workflows**
```bash
# Debug failed SonarQube scan
echo "=== SONARQUBE DEBUG ==="
echo "Project Key: $PROJECT_KEY"
echo "SonarQube URL: $SONAR_HOST_URL"

# Check if project exists
curl -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/projects/search?q=$PROJECT_KEY" | jq '.components'

# Check latest analysis
curl -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/project_analyses/search?project=$PROJECT_KEY" | jq '.analyses[0]'

# Check compute engine tasks
curl -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/ce/activity?component=$PROJECT_KEY" | jq '.tasks[0]'

# Debug failed Checkmarx scan
echo "=== CHECKMARX DEBUG ==="
echo "Checkmarx Server: $CHECKMARX_SERVER"
echo "Project ID: $CX_PROJECT_ID"

# Get authentication token
CX_TOKEN=$(curl -s -X POST "$CHECKMARX_SERVER/cxrestapi/auth/identity/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$CX_USERNAME&password=$CX_PASSWORD&grant_type=password&scope=sast_rest_api&client_id=resource_owner_client&client_secret=014DF517-39D1-4453-B7B3-9930C563627C" \
  | jq -r '.access_token')

# Check project status
curl -s -X GET "$CHECKMARX_SERVER/cxrestapi/projects/$CX_PROJECT_ID" \
  -H "Authorization: Bearer $CX_TOKEN" | jq '.'

# Check latest scan
curl -s -X GET "$CHECKMARX_SERVER/cxrestapi/sast/scans?projectId=$CX_PROJECT_ID&last=1" \
  -H "Authorization: Bearer $CX_TOKEN" | jq '.[0]'

# Debug failed AKS deployment
echo "=== AKS DEPLOYMENT DEBUG ==="
echo "Cluster: $AKS_CLUSTER_NAME"
echo "Resource Group: $AKS_RESOURCE_GROUP"
echo "Namespace: $KUBE_NAMESPACE"

# Check cluster connectivity
kubectl cluster-info || echo "❌ Cannot connect to AKS cluster"

# Check namespace
kubectl get namespace $KUBE_NAMESPACE || echo "❌ Namespace does not exist"

# Check recent events
kubectl get events --namespace=$KUBE_NAMESPACE --sort-by='.lastTimestamp' | tail -20

# Check deployment status
kubectl get deployment my-app --namespace=$KUBE_NAMESPACE
kubectl describe deployment my-app --namespace=$KUBE_NAMESPACE

# Check pods
kubectl get pods -l app=my-app --namespace=$KUBE_NAMESPACE
kubectl describe pod $(kubectl get pods -l app=my-app --namespace=$KUBE_NAMESPACE -o jsonpath='{.items[0].metadata.name}') --namespace=$KUBE_NAMESPACE

# Check services
kubectl get service my-app --namespace=$KUBE_NAMESPACE
kubectl describe service my-app --namespace=$KUBE_NAMESPACE
```

## 🚀 Deployment Workflow Commands

### **Environment-Specific Deployments**
```bash
# DEV Environment
git checkout dev
git push origin dev
# OR
gh workflow run deploy.yml -f environment=dev

# SQE Environment  
git checkout sqe
git push origin sqe
# OR
gh workflow run deploy.yml -f environment=sqe

# PPR Environment
git checkout release/v1.0.0
git push origin release/v1.0.0
# OR
gh workflow run deploy.yml -f environment=ppr

# PROD Environment
git tag v1.0.0
git push origin v1.0.0
# OR
gh workflow run deploy.yml -f environment=prod
```

### **Manual Deployment with Override**
```bash
# Deploy to any environment from any branch
gh workflow run deploy.yml \
  -f environment=prod \
  -f override_branch_validation=true \
  -f deploy_notes="Emergency hotfix deployment"

# Deploy with custom image tag
gh workflow run deploy.yml \
  -f environment=dev \
  -f custom_image_tag=feature-branch-123 \
  -f deploy_notes="Testing feature branch"
```

### **Emergency Deployment**
```bash
# 1. Set emergency bypass (if needed)
gh variable set EMERGENCY_BYPASS_SONAR --body "true"
gh variable set EMERGENCY_BYPASS_CHECKMARX --body "true"

# 2. Deploy with override
gh workflow run deploy.yml \
  -f environment=prod \
  -f override_branch_validation=true \
  -f deploy_notes="EMERGENCY: Critical security patch"

# 3. Clean up immediately after deployment
gh variable delete EMERGENCY_BYPASS_SONAR
gh variable delete EMERGENCY_BYPASS_CHECKMARX
```

## 📋 Environment-Specific Configurations

### **Local Development**
```bash
# Run with local profile
mvn spring-boot:run -Dspring-boot.run.profiles=local
export SPRING_PROFILES_ACTIVE=local
java -jar app.jar

# Local database (H2)
# Access H2 console: http://localhost:8080/h2-console
# JDBC URL: jdbc:h2:mem:testdb
```

### **Development Environment**
```bash
# Set context to dev cluster
az aks get-credentials --resource-group rg-aks-dev --name aks-dev-cluster

# Check dev deployment
kubectl get all -n dev
helm list -n dev
```

### **Production Environment**
```bash
# Set context to prod cluster
az aks get-credentials --resource-group rg-aks-prod --name aks-prod-cluster

# Check prod deployment
kubectl get all -n prod
helm list -n prod

# Monitor production
kubectl top pods -n prod
kubectl logs -f deployment/my-app -n prod
```

## 🔧 Quick Fixes and Common Solutions

### **Pod Not Starting**
```bash
# Check pod events
kubectl describe pod pod-name

# Check image pull issues
kubectl get events --field-selector involvedObject.name=pod-name

# Force pod restart
kubectl delete pod pod-name
kubectl rollout restart deployment deployment-name
```

### **Service Not Accessible**
```bash
# Check service endpoints
kubectl get endpoints service-name
kubectl describe service service-name

# Test service connectivity
kubectl exec -it test-pod -- curl service-name:port
```

### **Deployment Stuck**
```bash
# Check deployment status
kubectl get deployment deployment-name
kubectl describe deployment deployment-name

# Force deployment update
kubectl patch deployment deployment-name -p '{"spec":{"template":{"metadata":{"annotations":{"kubectl.kubernetes.io/restartedAt":"'$(date +%Y-%m-%dT%H:%M:%S%z)'"}}}}}'
```

### **High Resource Usage**
```bash
# Check resource usage
kubectl top pods
kubectl top nodes

# Scale down if needed
kubectl scale deployment deployment-name --replicas=1

# Check resource limits
kubectl describe pod pod-name | grep -A 5 "Limits\|Requests"
```

## 📚 Reference Links

### **Official Documentation**
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Docker Documentation](https://docs.docker.com/)
- [Spring Boot Documentation](https://spring.io/projects/spring-boot)

### **Quick References**
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm Cheat Sheet](https://helm.sh/docs/helm/)
- [Docker Cheat Sheet](https://docs.docker.com/get-started/docker_cheatsheet.pdf)
- [Git Cheat Sheet](https://education.github.com/git-cheat-sheet-education.pdf)

## 🎯 Tips and Best Practices

### **Command Aliases**
```bash
# Add to ~/.bashrc or ~/.zshrc
alias k='kubectl'
alias h='helm'
alias d='docker'
alias g='git'
alias gh='gh'

# Kubernetes shortcuts
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
```

### **Useful Environment Variables**
```bash
# Set default namespace
export KUBE_NAMESPACE=my-namespace

# Set default Azure subscription
export AZURE_SUBSCRIPTION_ID=your-subscription-id

# Set Spring profiles
export SPRING_PROFILES_ACTIVE=dev
```

### **Quick Commands for Daily Use**
```bash
# Most used kubectl commands
kubectl get all
kubectl describe pod $(kubectl get pods -o name | head -1)
kubectl logs -f deployment/my-app
kubectl port-forward service/my-app 8080:80

# Most used helm commands
helm list
helm status my-app
helm template my-app ./helm --values ./helm/values-dev.yaml

# Most used git commands
git status
git log --oneline -10
git push origin $(git branch --show-current)
```

This command reference guide provides quick access to all commonly used commands without the need to search through extensive documentation. Keep this handy for daily development and deployment tasks!