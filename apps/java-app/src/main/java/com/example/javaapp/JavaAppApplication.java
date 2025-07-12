package com.example.javaapp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.core.env.Environment;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;

@SpringBootApplication
@ConfigurationPropertiesScan
public class JavaAppApplication {

    private static final Logger logger = LoggerFactory.getLogger(JavaAppApplication.class);

    @Autowired
    private Environment environment;

    public static void main(String[] args) {
        SpringApplication.run(JavaAppApplication.class, args);
    }

    @PostConstruct
    public void printActiveProfiles() {
        String[] activeProfiles = environment.getActiveProfiles();
        logger.info("=== Spring Boot Application Started ===");
        logger.info("Application Name: {}", environment.getProperty("spring.application.name", "java-app"));
        logger.info("Active Profiles: {}", String.join(", ", activeProfiles));
        logger.info("Java Version: {}", System.getProperty("java.version"));
        logger.info("Spring Boot Version: {}", environment.getProperty("spring.boot.version"));
        logger.info("Environment: {}", environment.getProperty("app.environment", "unknown"));
        logger.info("Build Version: {}", environment.getProperty("app.build.version", "unknown"));
        logger.info("==========================================");
    }
}