-- Schema definition for Java App
-- This file will be loaded during application startup

-- Drop tables if they exist (for development)
DROP TABLE IF EXISTS app_metadata;
DROP TABLE IF EXISTS app_config;
DROP TABLE IF EXISTS users;

-- Users table
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    environment VARCHAR(20) DEFAULT 'dev',
    active BOOLEAN DEFAULT TRUE
);

-- Application configuration table
CREATE TABLE app_config (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    config_key VARCHAR(100) NOT NULL,
    config_value TEXT NOT NULL,
    environment VARCHAR(20) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_config_env (config_key, environment)
);

-- Application metadata table
CREATE TABLE app_metadata (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    metadata_key VARCHAR(100) NOT NULL UNIQUE,
    metadata_value TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_environment ON users(environment);
CREATE INDEX idx_config_key ON app_config(config_key);
CREATE INDEX idx_config_environment ON app_config(environment);
CREATE INDEX idx_metadata_key ON app_metadata(metadata_key);