package com.example.javaapp.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestController
public class HelloController {

    @Value("${spring.application.name:java-app}")
    private String applicationName;

    @Value("${app.version:1.0.0}")
    private String version;

    @GetMapping("/")
    public Map<String, Object> home() {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Hello from Spring Boot!");
        response.put("application", applicationName);
        response.put("version", version);
        response.put("timestamp", LocalDateTime.now());
        response.put("status", "UP");
        return response;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("application", applicationName);
        response.put("timestamp", LocalDateTime.now());
        return response;
    }

    @GetMapping("/info")
    public Map<String, Object> info() {
        Map<String, Object> response = new HashMap<>();
        response.put("application", applicationName);
        response.put("version", version);
        response.put("java.version", System.getProperty("java.version"));
        response.put("java.vendor", System.getProperty("java.vendor"));
        response.put("os.name", System.getProperty("os.name"));
        response.put("timestamp", LocalDateTime.now());
        return response;
    }
}