# ☕ Spring Boot Configuration Guide

Complete guide for configuring Spring Boot application with Azure Key Vault integration, environment profiles, and Blue-Green deployment support.

## 📋 **Table of Contents**

- [Application Properties Structure](#application-properties-structure)
- [Environment Profiles](#environment-profiles)
- [Azure Key Vault Integration](#azure-key-vault-integration)
- [Database Configuration](#database-configuration)
- [Security Configuration](#security-configuration)
- [Monitoring & Health Checks](#monitoring--health-checks)
- [Logging Configuration](#logging-configuration)
- [Caching Configuration](#caching-configuration)
- [API Documentation](#api-documentation)
- [Performance Optimization](#performance-optimization)
- [Blue-Green Deployment Support](#blue-green-deployment-support)

## 🏗️ **Application Properties Structure**

### **Main Application Properties (`application.yml`)**
```yaml
# src/main/resources/application.yml
spring:
  application:
    name: java-backend1
  profiles:
    active: local  # Default profile for local development
  
  # Default datasource configuration (overridden by profiles)
  datasource:
    url: jdbc:h2:mem:testdb
    driver-class-name: org.h2.Driver
    username: sa
    password: password
  
  # JPA configuration
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.H2Dialect
        format_sql: true
    show-sql: false
  
  # Azure Key Vault configuration (profile-specific)
  cloud:
    azure:
      keyvault:
        secret:
          enabled: false  # Enabled in cloud profiles

# Server configuration
server:
  port: 8080
  servlet:
    context-path: /backend1
  compression:
    enabled: true
    mime-types: text/html,text/xml,text/plain,text/css,text/javascript,application/javascript,application/json
    min-response-size: 1024

# Management endpoints for health checks
management:
  endpoint:
    health:
      enabled: true
      show-details: always
      probes:
        enabled: true
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
      base-path: /actuator
  health:
    readinessstate:
      enabled: true
    livenessstate:
      enabled: true

# Application info
info:
  app:
    name: ${spring.application.name}
    description: Java Backend1 microservice
    version: @project.version@

# Logging configuration
logging:
  level:
    com.yourcompany.javabackend1: INFO
    org.springframework.security: WARN
    org.hibernate.SQL: WARN
  pattern:
    console: "%clr(%d{yyyy-MM-dd HH:mm:ss.SSS}){faint} %clr(${LOG_LEVEL_PATTERN:-%5p}) %clr(${PID:- }){magenta} %clr(---){faint} %clr([%15.15t]){faint} %clr(%-40.40logger{39}){cyan} %clr(:){faint} %m%n${LOG_EXCEPTION_CONVERSION_WORD:-%wEx}"
```

## 🌍 **Environment Profiles**

### **Local Development Profile (`application-local.yml`)**
```yaml
# src/main/resources/application-local.yml
spring:
  datasource:
    url: jdbc:h2:mem:localdb
    driver-class-name: org.h2.Driver
    username: sa
    password: password
  
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true
  
  h2:
    console:
      enabled: true
      path: /h2-console

# Local development settings
app:
  cors:
    allowed-origins: "http://localhost:3000,http://localhost:4200"
  jwt:
    secret: "local-jwt-secret-key-for-development-only"
    expiration: 86400000  # 24 hours
  
logging:
  level:
    com.yourcompany.javabackend1: DEBUG
    org.hibernate.SQL: DEBUG
    org.hibernate.type.descriptor.sql.BasicBinder: TRACE
```

### **Development Profile (`application-dev.yml`)**
```yaml
# src/main/resources/application-dev.yml
spring:
  cloud:
    azure:
      keyvault:
        secret:
          enabled: true
          endpoint: ${AZURE_KEYVAULT_ENDPOINT}
  
  datasource:
    url: ${database-connection-string}
    username: ${database-username}
    password: ${database-password}
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 10
      minimum-idle: 2
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
  
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
    show-sql: false

# Redis configuration
spring:
  redis:
    url: ${redis-connection-string}
    timeout: 2000ms
    lettuce:
      pool:
        max-active: 8
        max-idle: 8
        min-idle: 0

# Application specific configuration
app:
  cors:
    allowed-origins: "https://dev.mydomain.com"
  jwt:
    secret: ${jwt-secret-key}
    expiration: 86400000  # 24 hours
  external-api:
    key: ${external-api-key}
    timeout: 5000
  
# Feature flags
features:
  new-user-registration: true
  email-notifications: true
  advanced-analytics: false

logging:
  level:
    com.yourcompany.javabackend1: DEBUG
    root: INFO
```

### **SQE Profile (`application-sqe.yml`)**
```yaml
# src/main/resources/application-sqe.yml
spring:
  cloud:
    azure:
      keyvault:
        secret:
          enabled: true
          endpoint: ${AZURE_KEYVAULT_ENDPOINT}
  
  datasource:
    url: ${database-connection-string}
    username: ${database-username}
    password: ${database-password}
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 15
      minimum-idle: 3
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
  
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
    show-sql: false

# Redis configuration
spring:
  redis:
    url: ${redis-connection-string}
    timeout: 2000ms
    lettuce:
      pool:
        max-active: 10
        max-idle: 8
        min-idle: 2

# Application specific configuration
app:
  cors:
    allowed-origins: "https://sqe.mydomain.com"
  jwt:
    secret: ${jwt-secret-key}
    expiration: 43200000  # 12 hours
  external-api:
    key: ${external-api-key}
    timeout: 5000
  
# Feature flags (testing new features)
features:
  new-user-registration: true
  email-notifications: true
  advanced-analytics: true

logging:
  level:
    com.yourcompany.javabackend1: INFO
    root: WARN
```

### **Pre-Production Profile (`application-ppr.yml`)**
```yaml
# src/main/resources/application-ppr.yml
spring:
  cloud:
    azure:
      keyvault:
        secret:
          enabled: true
          endpoint: ${AZURE_KEYVAULT_ENDPOINT}
  
  datasource:
    url: ${database-connection-string}
    username: ${database-username}
    password: ${database-password}
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
      leak-detection-threshold: 60000
  
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        jdbc:
          batch_size: 20
        order_inserts: true
        order_updates: true
    show-sql: false

# Redis configuration
spring:
  redis:
    url: ${redis-connection-string}
    timeout: 2000ms
    lettuce:
      pool:
        max-active: 15
        max-idle: 10
        min-idle: 3

# Application specific configuration
app:
  cors:
    allowed-origins: "https://preprod.mydomain.com"
  jwt:
    secret: ${jwt-secret-key}
    expiration: 28800000  # 8 hours
  external-api:
    key: ${external-api-key}
    timeout: 3000
  
# Feature flags (production-like)
features:
  new-user-registration: true
  email-notifications: true
  advanced-analytics: true

# Blue-Green deployment configuration
deployment:
  slot: ${DEPLOYMENT_SLOT:blue}
  environment: ppr

logging:
  level:
    com.yourcompany.javabackend1: INFO
    root: WARN
```

### **Production Profile (`application-prod.yml`)**
```yaml
# src/main/resources/application-prod.yml
spring:
  cloud:
    azure:
      keyvault:
        secret:
          enabled: true
          endpoint: ${AZURE_KEYVAULT_ENDPOINT}
  
  datasource:
    url: ${database-connection-string}
    username: ${database-username}
    password: ${database-password}
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 30
      minimum-idle: 10
      connection-timeout: 20000
      idle-timeout: 600000
      max-lifetime: 1800000
      leak-detection-threshold: 60000
      validation-timeout: 5000
  
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        jdbc:
          batch_size: 25
        order_inserts: true
        order_updates: true
        generate_statistics: false
    show-sql: false

# Redis configuration
spring:
  redis:
    url: ${redis-connection-string}
    timeout: 1000ms
    lettuce:
      pool:
        max-active: 20
        max-idle: 15
        min-idle: 5

# Application specific configuration
app:
  cors:
    allowed-origins: "https://api.mydomain.com"
  jwt:
    secret: ${jwt-secret-key}
    expiration: 3600000  # 1 hour
  external-api:
    key: ${external-api-key}
    timeout: 2000
  
# Feature flags (stable features only)
features:
  new-user-registration: true
  email-notifications: true
  advanced-analytics: true

# Blue-Green deployment configuration
deployment:
  slot: ${DEPLOYMENT_SLOT:blue}
  environment: prod

# Production security settings
security:
  require-ssl: true
  hsts:
    enabled: true
    max-age: 31536000
    include-subdomains: true

logging:
  level:
    com.yourcompany.javabackend1: WARN
    root: ERROR
```

## 🔐 **Azure Key Vault Integration**

### **Key Vault Configuration Class**
```java
// src/main/java/com/yourcompany/javabackend1/config/KeyVaultConfig.java
package com.yourcompany.javabackend1.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration
@Profile({"dev", "sqe", "ppr", "prod"})
@ConfigurationProperties(prefix = "spring.cloud.azure.keyvault.secret")
public class KeyVaultConfig {
    
    private boolean enabled;
    private String endpoint;
    
    // Getters and setters
    public boolean isEnabled() {
        return enabled;
    }
    
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }
    
    public String getEndpoint() {
        return endpoint;
    }
    
    public void setEndpoint(String endpoint) {
        this.endpoint = endpoint;
    }
}
```

### **Secret Value Injection Examples**
```java
// src/main/java/com/yourcompany/javabackend1/config/AppConfig.java
package com.yourcompany.javabackend1.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AppConfig {
    
    @Value("${jwt-secret-key:default-local-secret}")
    private String jwtSecret;
    
    @Value("${external-api-key:default-api-key}")
    private String externalApiKey;
    
    @Value("${database-username:sa}")
    private String dbUsername;
    
    // Configuration methods
    public String getJwtSecret() {
        return jwtSecret;
    }
    
    public String getExternalApiKey() {
        return externalApiKey;
    }
    
    public String getDbUsername() {
        return dbUsername;
    }
}
```

## 🗄️ **Database Configuration**

### **Database Configuration Class**
```java
// src/main/java/com/yourcompany/javabackend1/config/DatabaseConfig.java
package com.yourcompany.javabackend1.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

import javax.sql.DataSource;

@Configuration
@Profile({"dev", "sqe", "ppr", "prod"})
public class DatabaseConfig {
    
    @Value("${spring.datasource.url}")
    private String jdbcUrl;
    
    @Value("${spring.datasource.username}")
    private String username;
    
    @Value("${spring.datasource.password}")
    private String password;
    
    @Value("${spring.datasource.hikari.maximum-pool-size:10}")
    private int maxPoolSize;
    
    @Value("${spring.datasource.hikari.minimum-idle:2}")
    private int minIdle;
    
    @Bean
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(jdbcUrl);
        config.setUsername(username);
        config.setPassword(password);
        config.setMaximumPoolSize(maxPoolSize);
        config.setMinimumIdle(minIdle);
        config.setConnectionTimeout(30000);
        config.setIdleTimeout(600000);
        config.setMaxLifetime(1800000);
        config.setLeakDetectionThreshold(60000);
        
        // Connection pool monitoring
        config.setMetricRegistry(null); // Add your metric registry if needed
        
        return new HikariDataSource(config);
    }
}
```

### **Database Migration with Flyway**
```yaml
# Add to application.yml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true
    validate-on-migrate: true
```

**Migration Example:**
```sql
-- src/main/resources/db/migration/V1__Create_user_table.sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
```

## 🔒 **Security Configuration**

### **JWT Security Configuration**
```java
// src/main/java/com/yourcompany/javabackend1/config/SecurityConfig.java
package com.yourcompany.javabackend1.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;

@Configuration
@EnableWebSecurity
public class SecurityConfig {
    
    @Value("${app.cors.allowed-origins}")
    private String allowedOrigins;
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors().and()
            .csrf().disable()
            .sessionManagement().sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            .and()
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/actuator/health/**").permitAll()
                .requestMatchers("/actuator/info").permitAll()
                .requestMatchers("/actuator/prometheus").permitAll()
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/h2-console/**").permitAll() // Only for dev
                .anyRequest().authenticated()
            );
        
        // Add JWT filter here
        
        return http.build();
    }
    
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
    
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(Arrays.asList(allowedOrigins.split(",")));
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(Arrays.asList("*"));
        configuration.setAllowCredentials(true);
        
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
```

### **JWT Utility Class**
```java
// src/main/java/com/yourcompany/javabackend1/security/JwtUtils.java
package com.yourcompany.javabackend1.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Date;

@Component
public class JwtUtils {
    
    @Value("${app.jwt.secret}")
    private String jwtSecret;
    
    @Value("${app.jwt.expiration}")
    private long jwtExpiration;
    
    private Key getSigningKey() {
        return Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
    }
    
    public String generateToken(String username) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + jwtExpiration);
        
        return Jwts.builder()
                .setSubject(username)
                .setIssuedAt(now)
                .setExpirationTime(expiryDate)
                .signWith(getSigningKey(), SignatureAlgorithm.HS512)
                .compact();
    }
    
    public boolean validateToken(String token) {
        try {
            Jwts.parserBuilder().setSigningKey(getSigningKey()).build().parseClaimsJws(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }
    
    public String getUsernameFromToken(String token) {
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody();
        
        return claims.getSubject();
    }
}
```

## 📊 **Monitoring & Health Checks**

### **Custom Health Indicators**
```java
// src/main/java/com/yourcompany/javabackend1/health/DatabaseHealthIndicator.java
package com.yourcompany.javabackend1.health;

import org.springframework.boot.actuator.health.Health;
import org.springframework.boot.actuator.health.HealthIndicator;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

@Component
public class DatabaseHealthIndicator implements HealthIndicator {
    
    private final DataSource dataSource;
    
    public DatabaseHealthIndicator(DataSource dataSource) {
        this.dataSource = dataSource;
    }
    
    @Override
    public Health health() {
        try (Connection connection = dataSource.getConnection()) {
            if (connection.isValid(2)) {
                return Health.up()
                        .withDetail("database", "Available")
                        .withDetail("validationQuery", "SELECT 1")
                        .build();
            } else {
                return Health.down()
                        .withDetail("database", "Connection invalid")
                        .build();
            }
        } catch (SQLException e) {
            return Health.down()
                    .withDetail("database", "Connection failed")
                    .withDetail("error", e.getMessage())
                    .build();
        }
    }
}
```

### **External Service Health Check**
```java
// src/main/java/com/yourcompany/javabackend1/health/ExternalApiHealthIndicator.java
package com.yourcompany.javabackend1.health;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.actuator.health.Health;
import org.springframework.boot.actuator.health.HealthIndicator;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@Component
public class ExternalApiHealthIndicator implements HealthIndicator {
    
    @Value("${app.external-api.key}")
    private String apiKey;
    
    private final RestTemplate restTemplate;
    
    public ExternalApiHealthIndicator(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }
    
    @Override
    public Health health() {
        try {
            // Perform health check call to external API
            String response = restTemplate.getForObject(
                "https://external-api.com/health?key=" + apiKey, 
                String.class
            );
            
            return Health.up()
                    .withDetail("externalApi", "Available")
                    .withDetail("response", response)
                    .build();
        } catch (Exception e) {
            return Health.down()
                    .withDetail("externalApi", "Unavailable")
                    .withDetail("error", e.getMessage())
                    .build();
        }
    }
}
```

## 📝 **Logging Configuration**

### **Logback Configuration (`logback-spring.xml`)**
```xml
<!-- src/main/resources/logback-spring.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <springProfile name="local,dev">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%clr(%d{yyyy-MM-dd HH:mm:ss.SSS}){faint} %clr(${LOG_LEVEL_PATTERN:-%5p}) %clr(${PID:- }){magenta} %clr(---){faint} %clr([%15.15t]){faint} %clr(%-40.40logger{39}){cyan} %clr(:){faint} %m%n${LOG_EXCEPTION_CONVERSION_WORD:-%wEx}</pattern>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>

    <springProfile name="sqe,ppr,prod">
        <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
            <file>/var/log/java-backend1/application.log</file>
            <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
                <fileNamePattern>/var/log/java-backend1/application.%d{yyyy-MM-dd}.%i.log</fileNamePattern>
                <maxFileSize>100MB</maxFileSize>
                <maxHistory>30</maxHistory>
                <totalSizeCap>3GB</totalSizeCap>
            </rollingPolicy>
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <includeContext>true</includeContext>
                <includeMdc>true</includeMdc>
                <customFields>{"service":"java-backend1","environment":"${spring.profiles.active}"}</customFields>
            </encoder>
        </appender>
        
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
        </appender>
        
        <root level="INFO">
            <appender-ref ref="FILE"/>
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>

    <!-- Logger for database queries -->
    <logger name="org.hibernate.SQL" level="WARN"/>
    <logger name="org.hibernate.type.descriptor.sql.BasicBinder" level="WARN"/>
    
    <!-- Logger for security -->
    <logger name="org.springframework.security" level="WARN"/>
    
    <!-- Application loggers -->
    <logger name="com.yourcompany.javabackend1" level="INFO"/>
</configuration>
```

### **Structured Logging with MDC**
```java
// src/main/java/com/yourcompany/javabackend1/logging/LoggingFilter.java
package com.yourcompany.javabackend1.logging;

import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;

@Component
public class LoggingFilter extends OncePerRequestFilter {
    
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                   HttpServletResponse response, 
                                   FilterChain filterChain) throws ServletException, IOException {
        
        try {
            // Add request correlation ID
            String correlationId = UUID.randomUUID().toString();
            MDC.put("correlationId", correlationId);
            MDC.put("requestUri", request.getRequestURI());
            MDC.put("httpMethod", request.getMethod());
            MDC.put("clientIp", getClientIpAddress(request));
            
            // Add deployment slot info for Blue-Green
            MDC.put("deploymentSlot", System.getenv("DEPLOYMENT_SLOT"));
            
            response.setHeader("X-Correlation-ID", correlationId);
            
            filterChain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }
    
    private String getClientIpAddress(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
```

## 🚀 **Caching Configuration**

### **Redis Cache Configuration**
```java
// src/main/java/com/yourcompany/javabackend1/config/CacheConfig.java
package com.yourcompany.javabackend1.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import java.time.Duration;

@Configuration
@EnableCaching
@Profile({"dev", "sqe", "ppr", "prod"})
public class CacheConfig {
    
    @Value("${spring.redis.url}")
    private String redisUrl;
    
    @Bean
    public RedisConnectionFactory redisConnectionFactory() {
        // Parse Redis URL (format: redis://host:port)
        String[] parts = redisUrl.replace("redis://", "").split(":");
        String host = parts[0];
        int port = Integer.parseInt(parts[1]);
        
        RedisStandaloneConfiguration config = new RedisStandaloneConfiguration(host, port);
        return new LettuceConnectionFactory(config);
    }
    
    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory connectionFactory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        
        // Serializers
        template.setKeySerializer(new StringRedisSerializer());
        template.setValueSerializer(new GenericJackson2JsonRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());
        template.setHashValueSerializer(new GenericJackson2JsonRedisSerializer());
        
        template.afterPropertiesSet();
        return template;
    }
    
    @Bean
    public CacheManager cacheManager(RedisConnectionFactory connectionFactory) {
        return RedisCacheManager.builder(connectionFactory)
                .cacheDefaults(org.springframework.data.redis.cache.RedisCacheConfiguration.defaultCacheConfig()
                        .entryTtl(Duration.ofMinutes(30))
                        .disableCachingNullValues())
                .build();
    }
}
```

## 📖 **API Documentation**

### **OpenAPI Configuration**
```java
// src/main/java/com/yourcompany/javabackend1/config/OpenApiConfig.java
package com.yourcompany.javabackend1.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class OpenApiConfig {
    
    @Value("${spring.profiles.active:local}")
    private String activeProfile;
    
    @Value("${deployment.slot:blue}")
    private String deploymentSlot;
    
    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Java Backend1 API")
                        .description("Microservice API with Blue-Green deployment support")
                        .version("1.0.0")
                        .contact(new Contact()
                                .name("DevOps Team")
                                .email("devops@yourcompany.com"))
                        .license(new License()
                                .name("MIT")
                                .url("https://opensource.org/licenses/MIT")))
                .servers(getServers());
    }
    
    private List<Server> getServers() {
        String serverUrl = switch (activeProfile) {
            case "dev" -> "https://dev.mydomain.com/backend1";
            case "sqe" -> "https://sqe.mydomain.com/backend1";
            case "ppr" -> "https://preprod.mydomain.com/backend1";
            case "prod" -> "https://api.mydomain.com/backend1";
            default -> "http://localhost:8080/backend1";
        };
        
        return List.of(new Server()
                .url(serverUrl)
                .description(activeProfile.toUpperCase() + " Environment" + 
                           (!"local".equals(activeProfile) ? " (" + deploymentSlot + " slot)" : "")));
    }
}
```

## ⚡ **Performance Optimization**

### **Application Performance Configuration**
```yaml
# Add to application.yml for production optimization
spring:
  jpa:
    properties:
      hibernate:
        # Query optimization
        jdbc:
          batch_size: 25
          fetch_size: 50
        order_inserts: true
        order_updates: true
        generate_statistics: false
        
        # Second level cache
        cache:
          use_second_level_cache: true
          use_query_cache: true
          region:
            factory_class: org.hibernate.cache.jcache.JCacheRegionFactory
        
        # Connection optimization
        connection:
          provider_disables_autocommit: true

  # Thread pool optimization
  task:
    execution:
      pool:
        core-size: 8
        max-size: 20
        queue-capacity: 100
        keep-alive: 60s
      thread-name-prefix: "async-"

# Server optimization
server:
  tomcat:
    threads:
      max: 200
      min-spare: 10
    max-connections: 8192
    connection-timeout: 20000
    keep-alive-timeout: 60000
    max-keep-alive-requests: 100
```

### **Async Configuration**
```java
// src/main/java/com/yourcompany/javabackend1/config/AsyncConfig.java
package com.yourcompany.javabackend1.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

@Configuration
@EnableAsync
public class AsyncConfig {
    
    @Bean(name = "taskExecutor")
    public Executor taskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(8);
        executor.setMaxPoolSize(20);
        executor.setQueueCapacity(100);
        executor.setKeepAliveSeconds(60);
        executor.setThreadNamePrefix("Async-");
        executor.setRejectedExecutionHandler(new java.util.concurrent.ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}
```

## 🔄 **Blue-Green Deployment Support**

### **Deployment Slot Configuration**
```java
// src/main/java/com/yourcompany/javabackend1/config/DeploymentConfig.java
package com.yourcompany.javabackend1.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

@Configuration
public class DeploymentConfig {
    
    @Value("${deployment.slot:blue}")
    private String deploymentSlot;
    
    @Value("${deployment.environment:local}")
    private String environment;
    
    public String getDeploymentSlot() {
        return deploymentSlot;
    }
    
    public String getEnvironment() {
        return environment;
    }
    
    public boolean isBlueSlot() {
        return "blue".equals(deploymentSlot);
    }
    
    public boolean isGreenSlot() {
        return "green".equals(deploymentSlot);
    }
    
    public boolean isProductionEnvironment() {
        return "prod".equals(environment) || "ppr".equals(environment);
    }
}
```

### **Deployment Info Endpoint**
```java
// src/main/java/com/yourcompany/javabackend1/controller/DeploymentInfoController.java
package com.yourcompany.javabackend1.controller;

import com.yourcompany.javabackend1.config.DeploymentConfig;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.Map;

@RestController
@RequestMapping("/api/deployment")
public class DeploymentInfoController {
    
    private final DeploymentConfig deploymentConfig;
    private final LocalDateTime startupTime = LocalDateTime.now();
    
    public DeploymentInfoController(DeploymentConfig deploymentConfig) {
        this.deploymentConfig = deploymentConfig;
    }
    
    @GetMapping("/info")
    public Map<String, Object> getDeploymentInfo() {
        return Map.of(
            "environment", deploymentConfig.getEnvironment(),
            "deploymentSlot", deploymentConfig.getDeploymentSlot(),
            "startupTime", startupTime,
            "uptime", java.time.Duration.between(startupTime, LocalDateTime.now()).toString(),
            "version", getClass().getPackage().getImplementationVersion(),
            "namespace", System.getenv("KUBERNETES_NAMESPACE")
        );
    }
}
```

## 📝 **Maven Configuration**

### **Updated `pom.xml` with Required Dependencies**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
        <relativePath/>
    </parent>
    
    <groupId>com.yourcompany</groupId>
    <artifactId>java-backend1</artifactId>
    <version>1.0.0</version>
    <name>java-backend1</name>
    <description>Java Backend1 microservice with Blue-Green deployment</description>
    
    <properties>
        <java.version>21</java.version>
        <spring-cloud.version>2023.0.0</spring-cloud.version>
        <azure-spring-boot.version>5.7.0</azure-spring-boot.version>
    </properties>
    
    <dependencies>
        <!-- Spring Boot Starters -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-cache</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        
        <!-- Azure Key Vault -->
        <dependency>
            <groupId>com.azure.spring</groupId>
            <artifactId>spring-cloud-azure-starter-keyvault-secrets</artifactId>
        </dependency>
        
        <!-- Database -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>org.flywaydb</groupId>
            <artifactId>flyway-core</artifactId>
        </dependency>
        
        <!-- JWT -->
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-api</artifactId>
            <version>0.12.3</version>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-impl</artifactId>
            <version>0.12.3</version>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-jackson</artifactId>
            <version>0.12.3</version>
            <scope>runtime</scope>
        </dependency>
        
        <!-- OpenAPI -->
        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
            <version>2.2.0</version>
        </dependency>
        
        <!-- Monitoring -->
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>
        
        <!-- Logging -->
        <dependency>
            <groupId>net.logstash.logback</groupId>
            <artifactId>logstash-logback-encoder</artifactId>
            <version>7.4</version>
        </dependency>
        
        <!-- Test -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>junit-jupiter</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>postgresql</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>com.azure.spring</groupId>
                <artifactId>spring-cloud-azure-dependencies</artifactId>
                <version>${azure-spring-boot.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

This comprehensive Spring Boot configuration guide provides everything needed to configure your application for Blue-Green deployment with Azure integration!