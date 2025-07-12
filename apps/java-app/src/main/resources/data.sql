-- Data initialization for Java App
-- This file will be loaded during application startup

-- Sample users table data
INSERT INTO users (id, username, email, created_at, environment) VALUES 
(1, 'admin', 'admin@example.com', CURRENT_TIMESTAMP, 'demo'),
(2, 'user1', 'user1@example.com', CURRENT_TIMESTAMP, 'demo'),
(3, 'user2', 'user2@example.com', CURRENT_TIMESTAMP, 'demo');

-- Sample configuration data
INSERT INTO app_config (config_key, config_value, environment, description) VALUES
('max_users', '1000', 'dev', 'Maximum number of users allowed in development'),
('max_users', '10000', 'staging', 'Maximum number of users allowed in staging'),
('max_users', '100000', 'prod', 'Maximum number of users allowed in production'),
('feature_toggle_cache', 'true', 'dev', 'Enable caching feature in development'),
('feature_toggle_cache', 'true', 'staging', 'Enable caching feature in staging'),
('feature_toggle_cache', 'true', 'prod', 'Enable caching feature in production'),
('debug_enabled', 'true', 'dev', 'Enable debug mode in development'),
('debug_enabled', 'false', 'staging', 'Disable debug mode in staging'),
('debug_enabled', 'false', 'prod', 'Disable debug mode in production');

-- Sample application metadata
INSERT INTO app_metadata (metadata_key, metadata_value, created_at) VALUES
('app_name', 'Java Spring Boot App', CURRENT_TIMESTAMP),
('app_description', 'Example application with multi-environment support', CURRENT_TIMESTAMP),
('supported_profiles', 'dev,staging,prod', CURRENT_TIMESTAMP),
('configuration_source', 'ConfigMap and Secret', CURRENT_TIMESTAMP);