# Multi-stage Docker build for Spring Boot application
# Stage 1: Build the application using Maven
FROM maven:3.9.5-amazoncorretto-17 AS build

# Set the working directory
WORKDIR /app

# Copy the pom.xml file first to leverage Docker layer caching
COPY pom.xml .

# Download dependencies (this layer will be cached if pom.xml doesn't change)
RUN mvn dependency:go-offline -B

# Copy the source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests -B

# Verify that the JAR file was created
RUN ls -la target/ && test -f target/app.jar

# Stage 2: Create the runtime image
FROM amazoncorretto:17-alpine

# Set metadata
LABEL maintainer="example@company.com"
LABEL version="1.0.0"
LABEL description="Java Spring Boot Application for AKS deployment"

# Create a non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Set the working directory
WORKDIR /app

# Copy the JAR file from the build stage
COPY --from=build /app/target/app.jar app.jar

# Change ownership of the app directory to appuser
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose the port the app runs on
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Set JVM options for containerized environment
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=70.0 -Djava.security.egd=file:/dev/./urandom"

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]