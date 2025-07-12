# =================================
# Multi-stage Dockerfile for Spring Boot Application
# =================================

# Stage 1: Build stage
FROM maven:3.9.5-eclipse-temurin-17 AS build

# Set working directory
WORKDIR /app

# Copy pom.xml first to leverage Docker cache
COPY pom.xml .

# Download dependencies (this layer will be cached if pom.xml doesn't change)
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests -B

# Stage 2: Runtime stage
FROM eclipse-temurin:17-jre-jammy

# Set metadata
LABEL maintainer="devops@example.com"
LABEL version="1.0.0"
LABEL description="Java Spring Boot Application"

# Create application user and group
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Install required packages and clean up
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        dumb-init \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up application directory
WORKDIR /app

# Create necessary directories
RUN mkdir -p /app/logs /app/data /var/log/java-app && \
    chown -R appuser:appuser /app /var/log/java-app

# Copy the built JAR from build stage
COPY --from=build /app/target/*.jar app.jar

# Copy additional configuration files if needed
COPY --from=build /app/src/main/resources/application*.properties ./config/

# Change ownership of the application files
RUN chown -R appuser:appuser /app

# Create health check script
RUN echo '#!/bin/bash\ncurl -f http://localhost:8080/api/v1/actuator/health || exit 1' > /app/healthcheck.sh && \
    chmod +x /app/healthcheck.sh && \
    chown appuser:appuser /app/healthcheck.sh

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Environment variables
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -XX:+UseStringDeduplication"
ENV SPRING_PROFILES_ACTIVE=prod
ENV SPRING_CONFIG_LOCATION=classpath:/application.properties,classpath:/application-${SPRING_PROFILES_ACTIVE}.properties

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /app/healthcheck.sh

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Run the application
CMD ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]