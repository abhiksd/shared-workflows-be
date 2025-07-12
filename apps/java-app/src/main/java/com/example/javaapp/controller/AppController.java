package com.example.javaapp.controller;

import com.example.javaapp.config.AppProperties;
import com.example.javaapp.entity.User;
import com.example.javaapp.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1")
public class AppController {

    @Autowired
    private AppProperties appProperties;

    @Autowired
    private Environment environment;

    @Autowired
    private UserService userService;

    @Value("${app.name:unknown}")
    private String appName;

    @Value("${app.environment:unknown}")
    private String appEnvironment;

    @Value("${app.build.version:unknown}")
    private String buildVersion;

    @GetMapping("/")
    public ResponseEntity<Map<String, Object>> home() {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Welcome to " + appName);
        response.put("environment", appEnvironment);
        response.put("version", buildVersion);
        response.put("timestamp", LocalDateTime.now());
        response.put("status", "OK");
        return ResponseEntity.ok(response);
    }

    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> getAppInfo() {
        Map<String, Object> info = new HashMap<>();
        
        // Basic app information
        info.put("name", appProperties.getName());
        info.put("environment", appProperties.getEnvironment());
        info.put("version", appProperties.getVersion());
        info.put("description", appProperties.getDescription());
        
        // Build information
        Map<String, Object> buildInfo = new HashMap<>();
        buildInfo.put("version", appProperties.getBuild().getVersion());
        buildInfo.put("date", appProperties.getBuild().getDate());
        buildInfo.put("revision", appProperties.getBuild().getRevision());
        info.put("build", buildInfo);
        
        // Runtime information
        Map<String, Object> runtime = new HashMap<>();
        runtime.put("activeProfiles", environment.getActiveProfiles());
        runtime.put("javaVersion", System.getProperty("java.version"));
        runtime.put("timestamp", LocalDateTime.now());
        info.put("runtime", runtime);
        
        return ResponseEntity.ok(info);
    }

    @GetMapping("/config")
    public ResponseEntity<Map<String, Object>> getConfiguration() {
        Map<String, Object> config = new HashMap<>();
        
        // Features configuration (from ConfigMap)
        Map<String, Object> features = new HashMap<>();
        features.put("cacheEnabled", appProperties.getFeatures().isCacheEnabled());
        features.put("metricsEnabled", appProperties.getFeatures().isMetricsEnabled());
        features.put("auditEnabled", appProperties.getFeatures().isAuditEnabled());
        features.put("debugMode", appProperties.getFeatures().isDebugMode());
        config.put("features", features);
        
        // Monitoring configuration (from ConfigMap)
        Map<String, Object> monitoring = new HashMap<>();
        monitoring.put("enabled", appProperties.getMonitoring().isEnabled());
        monitoring.put("metricsPort", appProperties.getMonitoring().getMetricsPort());
        monitoring.put("metricsPath", appProperties.getMonitoring().getMetricsPath());
        monitoring.put("healthCheckInterval", appProperties.getMonitoring().getHealthCheckInterval());
        config.put("monitoring", monitoring);
        
        // Database configuration (from ConfigMap - excluding sensitive info)
        Map<String, Object> database = new HashMap<>();
        database.put("host", appProperties.getDatabase().getHost());
        database.put("port", appProperties.getDatabase().getPort());
        database.put("name", appProperties.getDatabase().getName());
        database.put("username", appProperties.getDatabase().getUsername());
        database.put("maxPoolSize", appProperties.getDatabase().getMaxPoolSize());
        database.put("showSql", appProperties.getDatabase().isShowSql());
        // Note: password is not included for security
        config.put("database", database);
        
        // Security configuration (from Secret - excluding sensitive info)
        Map<String, Object> security = new HashMap<>();
        security.put("corsEnabled", appProperties.getSecurity().isCorsEnabled());
        security.put("allowedOrigins", appProperties.getSecurity().getAllowedOrigins());
        security.put("jwtExpirationMs", appProperties.getSecurity().getJwtExpirationMs());
        // Note: JWT secret is not included for security
        config.put("security", security);
        
        return ResponseEntity.ok(config);
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> health = new HashMap<>();
        health.put("status", "UP");
        health.put("timestamp", LocalDateTime.now());
        health.put("environment", appEnvironment);
        health.put("version", buildVersion);
        
        // Add custom health checks
        Map<String, Object> checks = new HashMap<>();
        checks.put("database", "UP");
        checks.put("cache", appProperties.getFeatures().isCacheEnabled() ? "UP" : "DISABLED");
        checks.put("metrics", appProperties.getFeatures().isMetricsEnabled() ? "UP" : "DISABLED");
        health.put("checks", checks);
        
        return ResponseEntity.ok(health);
    }

    @GetMapping("/environment")
    public ResponseEntity<Map<String, Object>> getEnvironmentInfo() {
        Map<String, Object> envInfo = new HashMap<>();
        
        // Environment variables that are safe to expose
        envInfo.put("environment", environment.getProperty("app.environment"));
        envInfo.put("activeProfiles", environment.getActiveProfiles());
        envInfo.put("springProfilesActive", environment.getProperty("spring.profiles.active"));
        envInfo.put("serverPort", environment.getProperty("server.port"));
        envInfo.put("applicationName", environment.getProperty("spring.application.name"));
        
        // Container/Kubernetes information
        envInfo.put("hostname", environment.getProperty("HOSTNAME"));
        envInfo.put("podName", environment.getProperty("POD_NAME"));
        envInfo.put("namespace", environment.getProperty("POD_NAMESPACE"));
        envInfo.put("nodeName", environment.getProperty("NODE_NAME"));
        
        return ResponseEntity.ok(envInfo);
    }

    @PostMapping("/test")
    public ResponseEntity<Map<String, Object>> testEndpoint(@RequestBody(required = false) Map<String, Object> payload) {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Test endpoint called successfully");
        response.put("timestamp", LocalDateTime.now());
        response.put("environment", appEnvironment);
        response.put("receivedPayload", payload);
        response.put("featuresEnabled", Map.of(
            "cache", appProperties.getFeatures().isCacheEnabled(),
            "metrics", appProperties.getFeatures().isMetricsEnabled(),
            "audit", appProperties.getFeatures().isAuditEnabled(),
            "debug", appProperties.getFeatures().isDebugMode()
        ));
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/config/reload")
    public ResponseEntity<Map<String, Object>> reloadConfig() {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Configuration reload requested");
        response.put("timestamp", LocalDateTime.now());
        response.put("environment", appEnvironment);
        response.put("note", "In a real application, this would trigger configuration refresh");
        
        return ResponseEntity.ok(response);
    }

    // User Management Endpoints

    @GetMapping("/users")
    public ResponseEntity<Map<String, Object>> getAllUsers() {
        List<User> users = userService.getAllUsers();
        UserService.UserStatistics stats = userService.getUserStatistics();
        
        Map<String, Object> response = new HashMap<>();
        response.put("users", users);
        response.put("statistics", stats);
        response.put("timestamp", LocalDateTime.now());
        response.put("environment", appEnvironment);
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/users/active")
    public ResponseEntity<Map<String, Object>> getActiveUsers() {
        List<User> users = userService.getActiveUsers();
        
        Map<String, Object> response = new HashMap<>();
        response.put("users", users);
        response.put("count", users.size());
        response.put("timestamp", LocalDateTime.now());
        response.put("environment", appEnvironment);
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/users/environment/{environment}")
    public ResponseEntity<Map<String, Object>> getUsersByEnvironment(@PathVariable String environment) {
        List<User> users = userService.getUsersByEnvironment(environment);
        
        Map<String, Object> response = new HashMap<>();
        response.put("users", users);
        response.put("count", users.size());
        response.put("requestedEnvironment", environment);
        response.put("currentEnvironment", appEnvironment);
        response.put("timestamp", LocalDateTime.now());
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/users/{id}")
    public ResponseEntity<Map<String, Object>> getUserById(@PathVariable Long id) {
        return userService.getUserById(id)
                .map(user -> {
                    Map<String, Object> response = new HashMap<>();
                    response.put("user", user);
                    response.put("timestamp", LocalDateTime.now());
                    response.put("environment", appEnvironment);
                    return ResponseEntity.ok(response);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/users")
    public ResponseEntity<Map<String, Object>> createUser(@RequestBody Map<String, String> userRequest) {
        try {
            String username = userRequest.get("username");
            String email = userRequest.get("email");
            
            if (username == null || email == null) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "Username and email are required");
                errorResponse.put("timestamp", LocalDateTime.now());
                return ResponseEntity.badRequest().body(errorResponse);
            }
            
            User user = userService.createUser(username, email);
            
            Map<String, Object> response = new HashMap<>();
            response.put("message", "User created successfully");
            response.put("user", user);
            response.put("timestamp", LocalDateTime.now());
            response.put("environment", appEnvironment);
            
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", e.getMessage());
            errorResponse.put("timestamp", LocalDateTime.now());
            return ResponseEntity.badRequest().body(errorResponse);
        }
    }

    @PutMapping("/users/{id}")
    public ResponseEntity<Map<String, Object>> updateUser(@PathVariable Long id, @RequestBody Map<String, String> userRequest) {
        try {
            String username = userRequest.get("username");
            String email = userRequest.get("email");
            
            if (username == null || email == null) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "Username and email are required");
                errorResponse.put("timestamp", LocalDateTime.now());
                return ResponseEntity.badRequest().body(errorResponse);
            }
            
            User user = userService.updateUser(id, username, email);
            
            Map<String, Object> response = new HashMap<>();
            response.put("message", "User updated successfully");
            response.put("user", user);
            response.put("timestamp", LocalDateTime.now());
            response.put("environment", appEnvironment);
            
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", e.getMessage());
            errorResponse.put("timestamp", LocalDateTime.now());
            return ResponseEntity.badRequest().body(errorResponse);
        }
    }

    @PutMapping("/users/{id}/deactivate")
    public ResponseEntity<Map<String, Object>> deactivateUser(@PathVariable Long id) {
        try {
            userService.deactivateUser(id);
            
            Map<String, Object> response = new HashMap<>();
            response.put("message", "User deactivated successfully");
            response.put("userId", id);
            response.put("timestamp", LocalDateTime.now());
            response.put("environment", appEnvironment);
            
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", e.getMessage());
            errorResponse.put("timestamp", LocalDateTime.now());
            return ResponseEntity.badRequest().body(errorResponse);
        }
    }

    @PutMapping("/users/{id}/activate")
    public ResponseEntity<Map<String, Object>> activateUser(@PathVariable Long id) {
        try {
            userService.activateUser(id);
            
            Map<String, Object> response = new HashMap<>();
            response.put("message", "User activated successfully");
            response.put("userId", id);
            response.put("timestamp", LocalDateTime.now());
            response.put("environment", appEnvironment);
            
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", e.getMessage());
            errorResponse.put("timestamp", LocalDateTime.now());
            return ResponseEntity.badRequest().body(errorResponse);
        }
    }

    @GetMapping("/users/statistics")
    public ResponseEntity<Map<String, Object>> getUserStatistics() {
        UserService.UserStatistics stats = userService.getUserStatistics();
        
        Map<String, Object> response = new HashMap<>();
        response.put("statistics", stats);
        response.put("timestamp", LocalDateTime.now());
        response.put("configurationSource", "ConfigMap and Secret");
        response.put("featuresEnabled", Map.of(
            "cache", appProperties.getFeatures().isCacheEnabled(),
            "metrics", appProperties.getFeatures().isMetricsEnabled(),
            "audit", appProperties.getFeatures().isAuditEnabled(),
            "debug", appProperties.getFeatures().isDebugMode()
        ));
        
        return ResponseEntity.ok(response);
    }
}