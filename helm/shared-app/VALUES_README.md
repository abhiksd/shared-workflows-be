# 🎯 Environment-Specific Values Files Guide

This document explains the different values files available for deploying applications across different environments with production-grade configurations.

## 📁 Available Values Files

| File | Environment | Purpose | Use Case |
|------|-------------|---------|----------|
| `values.yaml` | Default | Base configuration | Local development, testing |
| `values-dev.yml` | Development | Development settings | Feature development, debugging |
| `values-staging.yml` | Staging | Pre-production testing | Integration testing, QA |
| `values-prod.yml` | Production | Production-grade | Live production workloads |

## 🚀 Quick Start

### Deploy to Development
```bash
helm install myapp . -f values-dev.yml \
  --set global.applicationName=myapp \
  --set image.tag=dev-abc1234
```

### Deploy to Staging
```bash
helm install myapp . -f values-staging.yml \
  --set global.applicationName=myapp \
  --set image.tag=staging-def5678
```

### Deploy to Production
```bash
helm install myapp . -f values-prod.yml \
  --set global.applicationName=myapp \
  --set image.tag=v1.2.3
```

## 🛠️ Environment Configurations

### 🔧 Development Environment (`values-dev.yml`)

**Purpose**: Optimized for development and debugging

#### Key Features:
- **Single replica** for simplicity
- **Minimal resources** (500m CPU, 1Gi memory)
- **Debug mode enabled** with verbose logging
- **All actuator endpoints** exposed for debugging
- **H2 console enabled** for database inspection
- **No security restrictions** for development ease
- **Hot reload support** for faster development cycles

#### Security Profile:
- CORS allowed from all origins (`*`)
- Read-only filesystem disabled for development flexibility
- All debug endpoints exposed
- Network policies disabled

#### Resource Profile:
```yaml
resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 256Mi
```

#### Use Cases:
- Local development
- Feature development
- Debugging issues
- Testing new configurations

---

### 🧪 Staging Environment (`values-staging.yml`)

**Purpose**: Production-like environment for testing and validation

#### Key Features:
- **2 replicas** for moderate availability
- **Moderate resources** (1000m CPU, 2Gi memory)
- **HPA enabled** (2-5 replicas based on load)
- **Network policies** for security testing
- **Service mesh support** for advanced testing
- **Quality gates** enabled for performance testing
- **Monitoring and alerting** configured

#### Security Profile:
- CORS restricted to staging domains
- Read-only filesystem enabled
- Limited actuator endpoints
- Security policies enforced
- Network isolation configured

#### Resource Profile:
```yaml
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 250m
    memory: 512Mi

autoscaling:
  minReplicas: 2
  maxReplicas: 5
```

#### Use Cases:
- Integration testing
- Performance testing
- Security validation
- Load testing
- User acceptance testing

---

### 🏭 Production Environment (`values-prod.yml`)

**Purpose**: Maximum performance, security, and reliability

#### Key Features:
- **3 replicas minimum** for high availability
- **Production-grade resources** (2000m CPU, 4Gi memory)
- **Advanced HPA** (3-10 replicas with custom behaviors)
- **Strict security policies** and network isolation
- **Comprehensive monitoring** with PrometheusRules
- **Disaster recovery** configuration
- **Backup and persistence** enabled
- **Service mesh** with Istio for advanced traffic management

#### Security Profile:
- CORS restricted to production domains only
- Maximum security context restrictions
- Minimal actuator endpoints exposed
- Network policies with strict ingress/egress rules
- Pod security policies enforced
- Secrets properly encrypted

#### Resource Profile:
```yaml
resources:
  limits:
    cpu: 2000m
    memory: 4Gi
    ephemeral-storage: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
    ephemeral-storage: 500Mi

autoscaling:
  minReplicas: 3
  maxReplicas: 10
```

#### Use Cases:
- Production workloads
- Customer-facing applications
- Mission-critical services
- High-traffic applications

## 📊 Configuration Comparison

### Resource Allocation

| Environment | Replicas | CPU Limit | Memory Limit | HPA | PDB |
|-------------|----------|-----------|--------------|-----|-----|
| Development | 1 | 500m | 1Gi | ❌ | ❌ |
| Staging | 2 | 1000m | 2Gi | ✅ (2-5) | ✅ |
| Production | 3 | 2000m | 4Gi | ✅ (3-10) | ✅ |

### Security Features

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| CORS Origins | `*` | staging domains | production domains |
| Debug Endpoints | All enabled | Limited | Minimal |
| Network Policy | Disabled | Enabled | Strict |
| Read-only FS | Disabled | Enabled | Enabled |
| Pod Security | Basic | Enhanced | Maximum |

### Monitoring & Observability

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| Metrics | Basic | Enhanced | Comprehensive |
| Alerting | Disabled | Basic | Advanced |
| Logging Level | DEBUG | INFO | WARN |
| Service Monitor | Basic | Enabled | Enhanced |
| Prometheus Rules | ❌ | ✅ | ✅ |

## 🔧 Customization Examples

### Override Image Tag
```bash
# Development with custom image
helm install myapp . -f values-dev.yml \
  --set image.tag=feature-branch-abc123

# Production with specific version
helm install myapp . -f values-prod.yml \
  --set image.tag=v2.1.0
```

### Custom Resource Limits
```bash
# Increase memory for staging
helm install myapp . -f values-staging.yml \
  --set resources.limits.memory=3Gi \
  --set resources.requests.memory=1Gi
```

### Environment-Specific Secrets
```bash
# Production with custom database
helm install myapp . -f values-prod.yml \
  --set database.host=prod-cluster.example.com \
  --set database.name=production_db
```

### Custom Domains
```bash
# Staging with custom domain
helm install myapp . -f values-staging.yml \
  --set ingress.hosts[0].host=myapp-staging.company.com

# Production with multiple domains
helm install myapp . -f values-prod.yml \
  --set ingress.hosts[0].host=api.company.com \
  --set ingress.hosts[1].host=app.company.com
```

## 🛡️ Security Configurations

### Development Security
- **Relaxed for development ease**
- No network restrictions
- All debug endpoints enabled
- Simplified authentication

### Staging Security
- **Production-like security testing**
- Network policies enabled
- Limited endpoint exposure
- Security context enforced

### Production Security
- **Maximum security hardening**
- Strict network isolation
- Minimal attack surface
- Advanced security policies
- Pod security standards enforced

## 📈 Performance Tuning

### JVM Settings by Environment

| Environment | Initial Heap | Max Heap | GC Strategy |
|-------------|--------------|----------|-------------|
| Development | 128m | 512m | G1GC |
| Staging | 512m | 1536m | G1GC with tuning |
| Production | 1g | 3g | G1GC optimized |

### Database Connection Pools

| Environment | Pool Size | Timeout | Max Lifetime |
|-------------|-----------|---------|--------------|
| Development | 5 | 30s | 30m |
| Staging | 15 | 30s | 30m |
| Production | 50 | 20s | 30m |

## 🚨 Alerting Rules

### Development
- No alerting (development focus)
- Debug logging enabled

### Staging
- Basic resource alerts
- Performance threshold warnings
- Error rate monitoring

### Production
- **Critical alerts**: CPU > 90%, Memory > 90%, Error rate > 1%
- **Warning alerts**: CPU > 75%, Memory > 80%
- **Custom alerts**: Database connections, response time
- **Notifications**: Slack, Email, PagerDuty

## 📋 Best Practices

### Development
1. Use latest or feature branch tags
2. Enable all debugging features
3. Use minimal resources to save costs
4. Focus on developer experience

### Staging
1. Mirror production configuration as closely as possible
2. Use semantic versioning for releases
3. Enable comprehensive testing
4. Validate security policies

### Production
1. **Never** use `latest` tags
2. Use specific semantic versions
3. Enable all monitoring and alerting
4. Implement proper backup strategies
5. Use blue/green or canary deployments
6. Regular security updates

## 🔄 Deployment Workflows

### GitHub Actions Integration

```yaml
# Example workflow using environment-specific values
deploy-dev:
  uses: ./.github/workflows/shared-deploy.yml
  with:
    environment: dev
    values_file: values-dev.yml
    
deploy-staging:
  uses: ./.github/workflows/shared-deploy.yml
  with:
    environment: staging
    values_file: values-staging.yml
    
deploy-production:
  uses: ./.github/workflows/shared-deploy.yml
  with:
    environment: production
    values_file: values-prod.yml
```

### Manual Deployment Commands

```bash
# Development deployment
helm upgrade --install myapp-dev . \
  -f values-dev.yml \
  --namespace dev \
  --create-namespace \
  --wait

# Staging deployment
helm upgrade --install myapp-staging . \
  -f values-staging.yml \
  --namespace staging \
  --create-namespace \
  --wait \
  --timeout 600s

# Production deployment
helm upgrade --install myapp-prod . \
  -f values-prod.yml \
  --namespace production \
  --create-namespace \
  --wait \
  --timeout 900s \
  --atomic
```

## 🔍 Troubleshooting

### Common Issues

1. **Resource constraints in development**
   ```bash
   # Reduce resources if needed
   helm upgrade myapp . -f values-dev.yml \
     --set resources.limits.memory=512Mi
   ```

2. **Ingress issues in staging**
   ```bash
   # Check ingress configuration
   kubectl get ingress -n staging
   kubectl describe ingress myapp-staging -n staging
   ```

3. **Pod security issues in production**
   ```bash
   # Check security context
   kubectl get pods -n production -o yaml | grep -A 10 securityContext
   ```

### Debug Commands

```bash
# Check current values
helm get values myapp -n production

# Compare configurations
diff <(helm template myapp . -f values-staging.yml) \
     <(helm template myapp . -f values-prod.yml)

# Validate templates
helm template myapp . -f values-prod.yml --debug
```

## 📚 Additional Resources

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Helm Values Files](https://helm.sh/docs/chart_template_guide/values_files/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Monitoring with Prometheus](https://prometheus.io/docs/introduction/overview/)

---

**Remember**: Always test configuration changes in development and staging before applying to production! 🚀