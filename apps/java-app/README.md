# Java Spring Boot Application

This is a Spring Boot application designed for deployment to Azure Kubernetes Service (AKS) with integrated health checks, metrics, and observability features.

## Features

- **Spring Boot 3.2.0** with Java 17
- **Health checks** via Spring Boot Actuator
- **Prometheus metrics** for monitoring
- **Multi-stage Docker build** with Maven
- **Security best practices** (non-root user, minimal attack surface)
- **Container-optimized JVM settings**

## Local Development

### Prerequisites

- Java 17+
- Maven 3.6+
- Docker (optional, for containerized testing)

### Running the application

```bash
# Build the application
mvn clean package

# Run the application
java -jar target/app.jar

# Or use Maven to run directly
mvn spring-boot:run
```

The application will start on port 8080.

### Testing

```bash
# Run tests
mvn test

# Run tests with coverage
mvn test jacoco:report
```

## Docker Build

### Build the Docker image

```bash
# Build using multi-stage Dockerfile (includes Maven build)
docker build -t java-app:latest .

# Run the container
docker run -p 8080:8080 java-app:latest
```

### Multi-stage Build Process

The Dockerfile uses a multi-stage build:

1. **Build Stage**: Uses `maven:3.9.5-amazoncorretto-17` to compile and package the application
2. **Runtime Stage**: Uses `amazoncorretto:17-alpine` for a minimal runtime environment

### Build Arguments

You can customize the build with build arguments:

```bash
# Build with custom Maven profiles
docker build --build-arg MAVEN_PROFILE=production -t java-app:prod .
```

## Endpoints

Once running, the application exposes the following endpoints:

### Application Endpoints
- `GET /` - Home endpoint with application info
- `GET /health` - Custom health endpoint
- `GET /info` - Application information

### Actuator Endpoints
- `GET /actuator/health` - Spring Boot health endpoint
- `GET /actuator/info` - Application info
- `GET /actuator/metrics` - Application metrics
- `GET /actuator/prometheus` - Prometheus metrics

## Configuration

### Environment Variables

The application can be configured using the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_PORT` | `8080` | Port the application runs on |
| `SPRING_PROFILES_ACTIVE` | `development` | Active Spring profile |
| `JAVA_OPTS` | Container optimized | JVM options |

### Profiles

- **development** (default): Development settings with debug logging
- **production**: Production optimized settings
- **test**: Test-specific configuration

## Kubernetes Deployment

This application is designed to work with the existing GitHub Actions workflows in this repository. The workflows will:

1. Build the application using Maven
2. Create a Docker image
3. Push to Azure Container Registry
4. Deploy to AKS using Helm

### Health Checks

The application includes built-in health checks that Kubernetes can use:

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Monitoring

### Prometheus Metrics

The application exposes Prometheus metrics at `/actuator/prometheus`. These include:

- JVM metrics (memory, GC, threads)
- HTTP request metrics
- Application-specific metrics

### Logging

Structured logging is configured with:
- Console output in development
- JSON format in production
- Configurable log levels per package

## Security

### Container Security

- Runs as non-root user (uid: 1001)
- Uses minimal Alpine-based image
- No unnecessary packages or tools
- Read-only filesystem where possible

### Application Security

- Spring Security configured for production
- Actuator endpoints secured
- No sensitive information in logs

## Development Workflow

1. Make changes to the source code
2. Run tests locally: `mvn test`
3. Build locally: `mvn clean package`
4. Test with Docker: `docker build -t java-app:test .`
5. Push to GitHub to trigger CI/CD pipeline

## Troubleshooting

### Common Issues

1. **Build fails**: Check Java version (requires 17+)
2. **Tests fail**: Ensure test database is configured properly
3. **Container won't start**: Check logs with `docker logs <container-id>`
4. **Health check fails**: Verify application started correctly

### Debug Commands

```bash
# Check application logs
docker logs <container-id>

# Connect to running container
docker exec -it <container-id> sh

# Check application health
curl http://localhost:8080/actuator/health
```