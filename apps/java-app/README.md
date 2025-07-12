# Java Spring Boot Application with Multi-Environment Support

This is a production-ready Spring Boot application that demonstrates multi-environment configuration using Spring profiles, ConfigMap, and Secret integration for Kubernetes deployment.

## 🚀 Features

- **Multi-Environment Profiles**: dev, staging, prod
- **ConfigMap Integration**: Non-sensitive configuration from Kubernetes ConfigMap
- **Secret Integration**: Sensitive configuration from Kubernetes Secret
- **Database Integration**: H2 database with JPA/Hibernate
- **User Management**: CRUD operations with environment-aware data
- **Health Checks**: Spring Boot Actuator endpoints
- **Metrics**: Prometheus integration
- **Security**: Environment-specific security configuration
- **Docker Support**: Multi-stage Dockerfile with security best practices

## 📁 Project Structure

```
apps/java-app/
├── src/
│   └── main/
│       ├── java/com/example/javaapp/
│       │   ├── JavaAppApplication.java          # Main application class
│       │   ├── config/
│       │   │   └── AppProperties.java           # Configuration properties
│       │   ├── controller/
│       │   │   └── AppController.java           # REST endpoints
│       │   ├── entity/
│       │   │   └── User.java                    # JPA entity
│       │   ├── repository/
│       │   │   └── UserRepository.java          # Data repository
│       │   └── service/
│       │       └── UserService.java             # Business logic
│       └── resources/
│           ├── application.properties           # Base configuration
│           ├── application-dev.properties       # Development profile
│           ├── application-staging.properties   # Staging profile
│           ├── application-prod.properties      # Production profile
│           ├── schema.sql                       # Database schema
│           └── data.sql                         # Sample data
├── Dockerfile                                   # Multi-stage Docker build
├── pom.xml                                      # Maven dependencies
└── README.md                                    # This file
```

## 🔧 Configuration Overview

### Spring Profiles

The application supports three environment profiles:

| Profile | Environment | Database | Debug | SSL | Actuator Endpoints |
|---------|-------------|----------|-------|-----|-------------------|
| `dev` | Development | H2 In-Memory | Enabled | Disabled | All endpoints |
| `staging` | Staging | H2 File-based | Disabled | Disabled | Limited endpoints |
| `prod` | Production | External DB | Disabled | Optional | Minimal endpoints |

### Configuration Sources

1. **Application Properties**: Base configuration in `application.properties`
2. **Profile-Specific Properties**: Environment overrides in `application-{profile}.properties`
3. **Environment Variables**: Override any property using environment variables
4. **ConfigMap**: Non-sensitive Kubernetes configuration
5. **Secret**: Sensitive Kubernetes configuration (passwords, tokens)

## 🌍 Environment-Specific Configuration

### Development Profile (`dev`)

```properties
# Enable all debugging features
logging.level.root=DEBUG
spring.jpa.show-sql=true
spring.h2.console.enabled=true

# Features
app.features.cache-enabled=false
app.features.debug-mode=true
app.features.audit-enabled=true

# Security (relaxed for development)
app.security.allowed-origins=*
```

**Usage:**
```bash
# Run with dev profile
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# Or with environment variable
SPRING_PROFILES_ACTIVE=dev java -jar target/java-app-1.0.0.jar
```

### Staging Profile (`staging`)

```properties
# Balanced logging
logging.level.root=INFO
spring.jpa.show-sql=false
spring.h2.console.enabled=false

# Features
app.features.cache-enabled=true
app.features.debug-mode=false
app.features.audit-enabled=true

# Security (more restrictive)
app.security.allowed-origins=https://staging.example.com
```

**Usage:**
```bash
# Run with staging profile
mvn spring-boot:run -Dspring-boot.run.profiles=staging
```

### Production Profile (`prod`)

```properties
# Minimal logging
logging.level.root=WARN
spring.jpa.hibernate.ddl-auto=validate
spring.h2.console.enabled=false

# Features
app.features.cache-enabled=true
app.features.debug-mode=false
app.features.audit-enabled=true

# Security (most restrictive)
app.security.allowed-origins=https://api.example.com
management.endpoints.web.exposure.include=health,info,metrics,prometheus
```

**Usage:**
```bash
# Run with production profile
mvn spring-boot:run -Dspring-boot.run.profiles=prod
```

## 🔐 ConfigMap and Secret Configuration

### ConfigMap (Non-Sensitive Configuration)

The application reads non-sensitive configuration from Kubernetes ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: java-app-config
data:
  # Environment
  ENVIRONMENT: "dev"
  SPRING_PROFILES_ACTIVE: "dev"
  
  # Database (non-sensitive)
  DB_HOST: "localhost"
  DB_PORT: "5432"
  DB_NAME: "javaapp_dev"
  DB_MAX_POOL_SIZE: "10"
  DB_SHOW_SQL: "true"
  
  # Features
  CACHE_ENABLED: "false"
  METRICS_ENABLED: "true"
  AUDIT_ENABLED: "true"
  DEBUG_MODE: "true"
  
  # Monitoring
  MONITORING_ENABLED: "true"
  HEALTH_CHECK_INTERVAL: "30"
```

### Secret (Sensitive Configuration)

Sensitive configuration is stored in Kubernetes Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: java-app-secret
type: Opaque
data:
  # Database credentials (base64 encoded)
  DB_USERNAME: dXNlcg==  # "user"
  DB_PASSWORD: cGFzc3dvcmQ=  # "password"
  
  # Security tokens (base64 encoded)
  JWT_SECRET: bXktand0LXNlY3JldC1rZXk=  # "my-jwt-secret-key"
```

## 🚀 Building and Running

### Local Development

1. **Build the application:**
   ```bash
   mvn clean package
   ```

2. **Run with specific profile:**
   ```bash
   # Development
   java -jar target/java-app-1.0.0.jar --spring.profiles.active=dev
   
   # Staging
   java -jar target/java-app-1.0.0.jar --spring.profiles.active=staging
   
   # Production
   java -jar target/java-app-1.0.0.jar --spring.profiles.active=prod
   ```

3. **Run with Maven:**
   ```bash
   mvn spring-boot:run -Dspring-boot.run.profiles=dev
   ```

### Docker Build

1. **Build Docker image:**
   ```bash
   docker build -t java-app:latest .
   ```

2. **Run with Docker:**
   ```bash
   # Development
   docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=dev java-app:latest
   
   # Production
   docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=prod java-app:latest
   ```

### Kubernetes Deployment

When deployed to Kubernetes, the application automatically loads configuration from ConfigMap and Secret:

```bash
# Deploy using Helm (from repository root)
helm install java-app helm/shared-app \
  --set global.applicationName=java-app \
  --set global.applicationType=java-springboot \
  --set global.environment=dev \
  --set image.repository=myregistry.azurecr.io/java-app \
  --set image.tag=latest
```

## 📊 API Endpoints

### Application Information

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/` | GET | Home page with basic info |
| `/api/v1/info` | GET | Detailed application information |
| `/api/v1/config` | GET | Current configuration (non-sensitive) |
| `/api/v1/environment` | GET | Environment and runtime information |
| `/api/v1/health` | GET | Custom health check |

### User Management

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/users` | GET | List all users with statistics |
| `/api/v1/users/active` | GET | List active users only |
| `/api/v1/users/environment/{env}` | GET | Users by environment |
| `/api/v1/users/{id}` | GET | Get user by ID |
| `/api/v1/users` | POST | Create new user |
| `/api/v1/users/{id}` | PUT | Update user |
| `/api/v1/users/{id}/activate` | PUT | Activate user |
| `/api/v1/users/{id}/deactivate` | PUT | Deactivate user |
| `/api/v1/users/statistics` | GET | User statistics |

### Spring Boot Actuator

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/actuator/health` | GET | Application health status |
| `/actuator/info` | GET | Application information |
| `/actuator/metrics` | GET | Application metrics |
| `/actuator/prometheus` | GET | Prometheus metrics |
| `/actuator/env` | GET | Environment properties (dev only) |

## 🧪 Testing the Application

### 1. Check Application Health
```bash
curl http://localhost:8080/actuator/health
```

### 2. Get Application Information
```bash
curl http://localhost:8080/api/v1/info
```

### 3. View Configuration
```bash
curl http://localhost:8080/api/v1/config
```

### 4. Create a User
```bash
curl -X POST http://localhost:8080/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "email": "test@example.com"}'
```

### 5. List Users
```bash
curl http://localhost:8080/api/v1/users
```

### 6. Get User Statistics
```bash
curl http://localhost:8080/api/v1/users/statistics
```

## 🔍 Monitoring and Observability

### Health Checks

The application provides comprehensive health checks:

- **Liveness Probe**: `/actuator/health/liveness`
- **Readiness Probe**: `/actuator/health/readiness`
- **Custom Health**: `/api/v1/health`

### Metrics

Prometheus metrics are available at `/actuator/prometheus`:

```bash
# View metrics
curl http://localhost:8080/actuator/prometheus
```

### Logging

Environment-specific logging configuration:

- **Development**: DEBUG level with SQL logging
- **Staging**: INFO level with structured logging
- **Production**: WARN level with file logging

## 🔧 Configuration Examples

### Override Database Configuration

```bash
# Using environment variables
export DB_HOST=mydb.example.com
export DB_PORT=5432
export DB_USERNAME=myuser
export DB_PASSWORD=mypassword
java -jar target/java-app-1.0.0.jar --spring.profiles.active=prod
```

### Override Feature Flags

```bash
# Enable cache in development
export CACHE_ENABLED=true
export DEBUG_MODE=false
java -jar target/java-app-1.0.0.jar --spring.profiles.active=dev
```

### Custom JVM Options

```bash
# Production JVM tuning
export JAVA_OPTS="-Xms512m -Xmx2g -XX:+UseG1GC"
java $JAVA_OPTS -jar target/java-app-1.0.0.jar --spring.profiles.active=prod
```

## 🐛 Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Change server port
   java -jar target/java-app-1.0.0.jar --server.port=8090
   ```

2. **Database Connection Issues**
   ```bash
   # Check H2 console (dev profile only)
   open http://localhost:8080/h2-console
   ```

3. **Profile Not Loading**
   ```bash
   # Verify active profile
   curl http://localhost:8080/actuator/env | grep "spring.profiles.active"
   ```

4. **Configuration Not Applied**
   ```bash
   # Check configuration properties
   curl http://localhost:8080/actuator/configprops
   ```

### Debug Mode

Enable debug mode for troubleshooting:

```bash
java -jar target/java-app-1.0.0.jar \
  --spring.profiles.active=dev \
  --debug \
  --logging.level.com.example.javaapp=DEBUG
```

## 📈 Performance Tuning

### Production Settings

```properties
# JVM Options for production
-Xms1g -Xmx2g
-XX:+UseG1GC
-XX:+UseStringDeduplication
-XX:MaxGCPauseMillis=200

# Connection pool tuning
spring.datasource.hikari.maximum-pool-size=50
spring.datasource.hikari.minimum-idle=10

# Caching
spring.cache.type=caffeine
spring.cache.caffeine.spec=maximumSize=1000,expireAfterWrite=10m
```

## 🔐 Security Considerations

### Production Security

1. **Disable Debug Endpoints**: Limited actuator endpoints in production
2. **Secure Headers**: HTTPS-only cookies, HSTS headers
3. **CORS Configuration**: Restrict allowed origins
4. **JWT Security**: Strong secret keys, proper expiration
5. **Database Security**: Encrypted connections, strong passwords

### Environment Variables

Never include sensitive information in application properties. Use environment variables or Kubernetes secrets:

```bash
# Bad - hardcoded password
spring.datasource.password=mysecretpassword

# Good - environment variable
spring.datasource.password=${DB_PASSWORD}
```

## 🚀 Deployment

This application is designed to work with the shared GitHub Actions workflow system. See the repository README for complete deployment instructions.

### Quick Deploy

```bash
# Build and push to registry
docker build -t myregistry.azurecr.io/java-app:latest .
docker push myregistry.azurecr.io/java-app:latest

# Deploy with Helm
helm install java-app helm/shared-app \
  --set global.applicationName=java-app \
  --set global.applicationType=java-springboot \
  --set global.environment=prod \
  --set image.repository=myregistry.azurecr.io/java-app \
  --set image.tag=latest
```

---

**Happy Coding!** 🎉 This application demonstrates production-ready Spring Boot practices with multi-environment support.