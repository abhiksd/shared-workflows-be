# Spring Boot Profile-Based Configuration Guide

This document describes the Spring Boot profile-based configuration system implemented to replace Azure Key Vault dependency while maintaining all functionality and enhancing deployment flexibility.

## 🎯 Overview

The application now uses **Spring Boot profiles** for environment-specific configuration management, eliminating the need for external key vault services while providing:

- ✅ **Environment-specific configuration** through Spring profiles
- ✅ **Kubernetes-native secret management** 
- ✅ **Enhanced security** with proper secret isolation
- ✅ **Simplified deployment** without external dependencies
- ✅ **Better local development** experience
- ✅ **Configuration validation** and error handling

## 🏗️ Architecture

### Configuration Sources Hierarchy
1. **Spring Boot Profiles** - Environment-specific behavior and settings
2. **Kubernetes Secrets** - Sensitive data (passwords, API keys, tokens)
3. **Kubernetes ConfigMaps** - Non-sensitive configuration (URLs, timeouts, flags)
4. **Environment Variables** - Runtime configuration injection
5. **Application Properties** - Default values and fallbacks

### Profile Structure
```
src/main/resources/
├── application.yml              # Base configuration
├── application-local.yml        # Local development
├── application-dev.yml          # Development environment
├── application-sqe.yml          # System Quality Engineering
├── application-ppr.yml          # Pre-Production environment
└── application-production.yml   # Production environment
```

## 🔧 Configuration Profiles

### Local Profile (`local`)
**Purpose**: Local development with minimal external dependencies

**Features**:
- H2 in-memory database (no PostgreSQL required)
- Simple in-memory caching (no Redis required)
- Debug logging enabled
- Full actuator endpoint exposure
- Permissive CORS settings
- Embedded secrets for development

**Usage**:
```bash
# Run with local profile
mvn spring-boot:run -Dspring-boot.run.profiles=local

# Or set environment variable
export SPRING_PROFILES_ACTIVE=local
java -jar target/java-backend1-*.jar
```

### Development Profile (`dev`)
**Purpose**: Development environment with external services

**Features**:
- PostgreSQL database connection
- Redis caching
- Debug logging
- Enhanced actuator endpoints
- Development-friendly error handling
- OAuth2 integration

**Configuration Sources**:
- Kubernetes Secret: `DB_PASSWORD`, `REDIS_PASSWORD`, `JWT_SECRET`
- ConfigMap: Database URLs, Redis configuration, feature flags
- Environment Variables: Service endpoints, resource limits

### SQE Profile (`sqe`)
**Purpose**: System Quality Engineering - production-like testing environment

**Features**:
- Production database setup with connection pooling
- Redis clustering support
- Moderate logging levels
- Security headers enabled
- Performance monitoring
- SSL/TLS configuration

### PPR Profile (`ppr`)
**Purpose**: Pre-Production - final validation before production

**Features**:
- Production-identical configuration
- Enhanced monitoring and validation
- Performance testing capabilities
- Security validation
- Final integration testing
- Production readiness verification

### Production Profile (`production`)
**Purpose**: Optimized for performance and security

**Features**:
- Minimal logging (WARN level)
- Maximum security configuration
- Connection pooling optimization
- Comprehensive monitoring
- SSL/TLS enforcement
- Resource optimization

## 🔐 Secret Management

### Kubernetes Secrets Configuration

The application uses Kubernetes secrets for sensitive data:

```yaml
# helm/values.yaml
kubernetesSecrets:
  enabled: true
  secretName: "app-secrets"
  secrets:
    - name: "DB_PASSWORD"
      key: "db-password"
    - name: "JWT_SECRET" 
      key: "jwt-secret"
    - name: "REDIS_PASSWORD"
      key: "redis-password"
    - name: "API_KEY"
      key: "api-key"
```

### Secret Injection Methods

#### 1. Environment Variables (Recommended)
```yaml
# Automatically injected from Kubernetes Secret
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: db-password
```

#### 2. Volume Mounts
```yaml
# Mounted as files in /etc/secrets/
volumeMounts:
  - name: secrets-volume
    mountPath: /etc/secrets
    readOnly: true
```

#### 3. Spring Boot ConfigTree
```yaml
# application.yml
spring:
  config:
    import: "optional:configtree:/etc/secrets/"
```

## 📊 Configuration Management

### ConfigMap Structure

Non-sensitive configuration is managed through Kubernetes ConfigMaps:

```yaml
# Auto-generated in helm/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: java-backend1-dev-config
data:
  # Spring Boot Configuration
  spring.profiles.active: "dev"
  spring.config.location: "classpath:application.yml,classpath:application-dev.yml"
  
  # Environment-specific settings
  server.port: "8080"
  logging.level.root: "DEBUG"
  
  # Database configuration (non-sensitive)
  spring.datasource.url: "jdbc:postgresql://dev-db:5432/javaapp_dev"
  spring.datasource.driver-class-name: "org.postgresql.Driver"
  
  # Redis configuration (non-sensitive)
  spring.redis.host: "dev-redis"
  spring.redis.port: "6379"
  
  # Feature flags
  app.features.enable-caching: "true"
  app.features.enable-metrics: "true"
```

### Dynamic Configuration Updates

Configuration can be updated without rebuilding the application:

```bash
# Update ConfigMap
kubectl patch configmap java-backend1-dev-config -n dev --patch '{"data":{"logging.level.root":"INFO"}}'

# Update Secret (base64 encoded)
kubectl patch secret app-secrets -n dev --patch '{"data":{"jwt-secret":"bmV3LWp3dC1zZWNyZXQ="}}'

# Restart deployment to pick up changes
kubectl rollout restart deployment/java-backend1-dev -n dev
```

## 🚀 Deployment Integration

### Shared Workflow Integration

The shared workflow (`no-keyvault-shared-github-actions`) automatically:

1. **Generates runtime values** with deployment metadata
2. **Configures Spring Boot profiles** based on target environment
3. **Creates Kubernetes secrets** from encrypted GitHub secrets
4. **Manages ConfigMaps** with environment-specific configuration
5. **Validates configuration** before deployment

### Helm Chart Configuration

The Helm chart automatically configures Spring Boot profiling:

```yaml
# Runtime values generated by workflow
springBootProfile:
  activeProfile: "{{ .Values.global.environment }}"
  configLocation: "classpath:application-{{ .Values.global.environment }}.yml"
  secretManagement:
    enabled: true
    type: "kubernetes-secrets"
    namespace: "{{ .Release.Namespace }}"
```

## 🧪 Testing and Validation

### Configuration Validation

The application includes comprehensive configuration validation:

```yaml
# application-production.yml
config:
  profile:
    validation:
      strict-mode: true
      required-properties: "DB_PASSWORD,JWT_SECRET,REDIS_PASSWORD"
```

### Health Checks

Enhanced health checks validate configuration:

```bash
# Check active profiles
curl http://localhost:8080/actuator/env | jq '.activeProfiles'

# Validate configuration properties
curl http://localhost:8080/actuator/configprops

# Check configuration sources
curl http://localhost:8080/actuator/env | jq '.propertySources'
```

### Testing Different Profiles

```bash
# Test local profile
mvn spring-boot:run -Dspring-boot.run.profiles=local

# Test dev profile with external database
mvn spring-boot:run -Dspring-boot.run.profiles=dev \
  -DDB_HOST=localhost \
  -DDB_PASSWORD=dev_password

# Integration tests with specific profile
mvn test -Dspring.profiles.active=dev
```

## 🔍 Troubleshooting

### Common Configuration Issues

1. **Profile Not Loading**
   ```bash
   # Check active profiles
   curl http://localhost:8080/actuator/env | jq '.activeProfiles'
   
   # Verify environment variable
   echo $SPRING_PROFILES_ACTIVE
   ```

2. **Missing Secrets**
   ```bash
   # Check secret exists
   kubectl get secret app-secrets -n dev
   
   # Verify secret keys (without exposing values)
   kubectl get secret app-secrets -n dev -o jsonpath='{.data}' | jq 'keys'
   ```

3. **ConfigMap Issues**
   ```bash
   # Check ConfigMap content
   kubectl get configmap java-backend1-dev-config -n dev -o yaml
   
   # Verify mount in pod
   kubectl exec -it deployment/java-backend1-dev -n dev -- ls -la /etc/config
   ```

4. **Property Binding Issues**
   ```bash
   # Check bound properties
   curl http://localhost:8080/actuator/configprops | jq '.contexts.application.beans'
   
   # View all environment variables
   curl http://localhost:8080/actuator/env
   ```

### Debug Commands

```bash
# Application logs with configuration details
kubectl logs -f deployment/java-backend1-dev -n dev | grep -E "(profiles|config|properties)"

# Check configuration binding errors
kubectl logs deployment/java-backend1-dev -n dev | grep -E "(ERROR|WARN).*config"

# Validate Helm values
helm template java-backend1 ./helm -f helm/values-dev.yaml --debug

# Test configuration locally
java -jar target/java-backend1-*.jar --spring.profiles.active=dev --debug
```

## 📈 Performance and Security Benefits

### Performance Improvements
- ❌ **Eliminated Key Vault API calls** - No external service dependencies
- ✅ **Faster startup times** - Configuration loaded from local sources
- ✅ **Reduced network latency** - No external configuration fetching
- ✅ **Better caching** - Static configuration loaded once at startup

### Security Enhancements
- ✅ **Kubernetes-native security** - Leverages RBAC and pod security contexts
- ✅ **Secret isolation** - Secrets only accessible within namespace
- ✅ **Encryption at rest** - Kubernetes etcd encryption
- ✅ **Audit logging** - Kubernetes audit logs for configuration access
- ✅ **No external attack surface** - No Key Vault endpoints to secure

### Operational Benefits
- ✅ **Simplified deployment** - No Key Vault permissions to manage
- ✅ **Better local development** - Full functionality without cloud dependencies
- ✅ **Easier debugging** - Configuration visible through actuator endpoints
- ✅ **Version control** - Configuration changes tracked in Git
- ✅ **Environment parity** - Consistent configuration across all environments

## 🔄 Migration from Key Vault

### What Changed
- ❌ **Removed**: Azure Key Vault dependency
- ❌ **Removed**: `spring-cloud-azure-starter-keyvault-secrets` dependency
- ❌ **Removed**: SecretProviderClass Kubernetes resources
- ✅ **Added**: Kubernetes native Secret resources
- ✅ **Added**: Enhanced Spring Boot profile configuration
- ✅ **Added**: Local development profile
- ✅ **Enhanced**: ConfigMap-based non-sensitive configuration

### Configuration Mapping

| Key Vault Secret | Kubernetes Secret Key | Environment Variable |
|-------------------|----------------------|---------------------|
| `db-password` | `db-password` | `DB_PASSWORD` |
| `jwt-secret` | `jwt-secret` | `JWT_SECRET` |
| `redis-password` | `redis-password` | `REDIS_PASSWORD` |
| `api-key` | `api-key` | `API_KEY` |

## 📚 Best Practices

### Profile Design
1. **Keep profiles focused** - Each profile should target a specific environment
2. **Use inheritance** - Common settings in base `application.yml`
3. **Validate required properties** - Fail fast on missing configuration
4. **Document profile differences** - Clear documentation for each environment

### Secret Management
1. **Separate sensitive from non-sensitive** - Use secrets only for truly sensitive data
2. **Use appropriate keys** - Consistent naming across environments
3. **Rotate secrets regularly** - Leverage Kubernetes secret rotation
4. **Audit access** - Monitor secret access through Kubernetes logs

### Configuration Management
1. **Version control all changes** - Track configuration changes in Git
2. **Test configuration changes** - Validate in dev before production
3. **Use feature flags** - Enable/disable features through configuration
4. **Monitor configuration drift** - Alert on unexpected configuration changes

---

**Migration Status**: ✅ Complete - Azure Key Vault dependency successfully removed  
**Configuration Type**: Spring Boot Profile-based  
**Secret Management**: Kubernetes-native  
**Deployment**: Automated through GitHub Actions + Helm