# Java Backend1

A Spring Boot microservice for Java Backend1 functionality.

## 🚀 Quick Start

### Local Development
```bash
# Build and run
mvn clean spring-boot:run

# Run with specific profile
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# Or with Docker
docker build -t java-backend1 .
docker run -p 8080:8080 java-backend1
```

### API Endpoints
- **Base URL**: `http://localhost:8080/api`
- **Health Check**: `/actuator/health`
- **Metrics**: `/actuator/prometheus`
- **Info**: `/actuator/info`

## 🏗️ Architecture

- **Framework**: Spring Boot 3.x
- **Java Version**: 21
- **Build Tool**: Maven
- **Database**: PostgreSQL (configurable)
- **Caching**: Redis
- **Monitoring**: Prometheus + Grafana
- **Deployment**: Kubernetes with Helm

## 🔧 Configuration

### Spring Boot Profiles
- **local**: Local development with H2 database
- **dev**: Development environment with PostgreSQL
- **staging**: Staging environment with full monitoring
- **production**: Production environment with all features

### Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | Database host | localhost |
| `DB_PORT` | Database port | 5432 |
| `DB_NAME` | Database name | java_backend1_dev |
| `DB_USERNAME` | Database username | app_user |
| `DB_PASSWORD` | Database password | (required) |
| `REDIS_HOST` | Redis host | localhost |
| `REDIS_PORT` | Redis port | 6379 |

## 🚀 Deployment

This service uses shared GitHub Actions workflows from the `shared-github-actions` branch.

### Manual Deployment
```bash
# Deploy to development
gh workflow run deploy.yml -f environment=dev

# Deploy to staging  
gh workflow run deploy.yml -f environment=staging

# Deploy to production
gh workflow run deploy.yml -f environment=production
```

### Automatic Deployment
- **Dev**: Triggered on push to this branch
- **Staging**: Triggered on push to `release/*` branches
- **Production**: Triggered on push to `main` branch

## 📊 Monitoring & Observability

### Health Checks
- **Liveness**: `/actuator/health/liveness`
- **Readiness**: `/actuator/health/readiness`
- **Custom Health**: Application-specific indicators

### Metrics
- **Prometheus**: `/actuator/prometheus`
- **JVM Metrics**: Memory, GC, threads
- **HTTP Metrics**: Request duration, response codes
- **Custom Metrics**: Business-specific metrics

### Logging
- **Format**: JSON structured logging
- **Levels**: Configurable per environment
- **Correlation**: Request tracing with correlation IDs

## 🛠️ Development

### Prerequisites
- Java 21+
- Maven 3.6+
- Docker & Docker Compose
- PostgreSQL (for local dev)

### Setup
```bash
# Clone and switch to app branch
git clone <repository-url>
git checkout my-java-app

# Install dependencies
mvn clean install

# Run tests
mvn test

# Run with development profile
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

### Testing
```bash
# Unit tests
mvn test

# Integration tests
mvn verify

# Test with specific profile
mvn test -Dspring.profiles.active=dev
```

### Docker Development
```bash
# Build image
docker build -t java-backend1:latest .

# Run with docker-compose (if available)
docker-compose up -d

# Run standalone
docker run -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=dev \
  -e DB_HOST=host.docker.internal \
  java-backend1:latest
```

## 🔗 Branch Structure

This repository uses a branch-based approach:

- **`shared-github-actions`**: Shared CI/CD workflows and composite actions
- **`my-java-app`**: This Spring Boot application (current branch)
- **`main`**: Production releases

### Workflow Integration

The deployment workflow references shared workflows:

```yaml
uses: ./.github/workflows/shared-deploy.yml@shared-github-actions
```

## 📚 Documentation

- [Deployment Guide](./DEPLOYMENT.md) - Comprehensive deployment instructions
- [Shared Workflows](../../tree/shared-github-actions) - CI/CD workflows documentation
- [API Documentation](./docs/api.md) - API endpoints and examples

## 🐛 Troubleshooting

### Common Issues

1. **Application won't start**
   - Check database connectivity
   - Verify environment variables
   - Check application logs

2. **Workflow failures**
   - Verify shared workflows are up to date
   - Check repository secrets configuration
   - Review workflow logs

3. **Docker build fails**
   - Check Dockerfile syntax
   - Verify JAR file exists in target/
   - Ensure Maven build completes successfully

### Debug Commands
```bash
# Check application logs
kubectl logs -f deployment/java-backend1

# Check health status
curl http://localhost:8080/actuator/health

# View configuration
curl http://localhost:8080/actuator/configprops
```

## 🤝 Contributing

1. Create a feature branch from `my-java-app`
2. Make your changes
3. Test locally and with CI/CD
4. Create a pull request to `my-java-app`

## 📄 License

This project is licensed under the MIT License.

---

**Service**: Java Backend1  
**Branch**: my-java-app  
**Type**: Spring Boot Microservice  
**Shared Workflows**: shared-github-actions branch  
**Deployment**: GitHub Actions + Kubernetes + Helm
