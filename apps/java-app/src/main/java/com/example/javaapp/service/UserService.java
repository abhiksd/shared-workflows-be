package com.example.javaapp.service;

import com.example.javaapp.config.AppProperties;
import com.example.javaapp.entity.User;
import com.example.javaapp.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class UserService {

    private static final Logger logger = LoggerFactory.getLogger(UserService.class);

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private AppProperties appProperties;

    @Value("${app.environment:unknown}")
    private String currentEnvironment;

    /**
     * Get all users
     */
    @Transactional(readOnly = true)
    public List<User> getAllUsers() {
        logger.info("Fetching all users in environment: {}", currentEnvironment);
        return userRepository.findAll();
    }

    /**
     * Get users by environment
     */
    @Transactional(readOnly = true)
    public List<User> getUsersByEnvironment(String environment) {
        logger.info("Fetching users for environment: {}", environment);
        return userRepository.findByEnvironment(environment);
    }

    /**
     * Get active users
     */
    @Transactional(readOnly = true)
    public List<User> getActiveUsers() {
        logger.info("Fetching active users");
        return userRepository.findByActiveTrue();
    }

    /**
     * Get active users by environment
     */
    @Transactional(readOnly = true)
    public List<User> getActiveUsersByEnvironment(String environment) {
        logger.info("Fetching active users for environment: {}", environment);
        return userRepository.findByEnvironmentAndActiveTrue(environment);
    }

    /**
     * Get user by ID
     */
    @Transactional(readOnly = true)
    public Optional<User> getUserById(Long id) {
        logger.debug("Fetching user with ID: {}", id);
        return userRepository.findById(id);
    }

    /**
     * Get user by username
     */
    @Transactional(readOnly = true)
    public Optional<User> getUserByUsername(String username) {
        logger.debug("Fetching user with username: {}", username);
        return userRepository.findByUsername(username);
    }

    /**
     * Get user by email
     */
    @Transactional(readOnly = true)
    public Optional<User> getUserByEmail(String email) {
        logger.debug("Fetching user with email: {}", email);
        return userRepository.findByEmail(email);
    }

    /**
     * Create a new user
     */
    public User createUser(String username, String email) {
        logger.info("Creating new user: {} in environment: {}", username, currentEnvironment);
        
        // Check if username already exists
        if (userRepository.existsByUsername(username)) {
            throw new IllegalArgumentException("Username already exists: " + username);
        }
        
        // Check if email already exists
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email already exists: " + email);
        }
        
        User user = new User(username, email, currentEnvironment);
        User savedUser = userRepository.save(user);
        
        logger.info("Created user with ID: {} in environment: {}", savedUser.getId(), currentEnvironment);
        return savedUser;
    }

    /**
     * Update user
     */
    public User updateUser(Long id, String username, String email) {
        logger.info("Updating user with ID: {}", id);
        
        User user = userRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + id));
        
        // Check if username is being changed and if it already exists
        if (!user.getUsername().equals(username) && userRepository.existsByUsername(username)) {
            throw new IllegalArgumentException("Username already exists: " + username);
        }
        
        // Check if email is being changed and if it already exists
        if (!user.getEmail().equals(email) && userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email already exists: " + email);
        }
        
        user.setUsername(username);
        user.setEmail(email);
        
        User updatedUser = userRepository.save(user);
        logger.info("Updated user with ID: {}", updatedUser.getId());
        
        return updatedUser;
    }

    /**
     * Deactivate user (soft delete)
     */
    public void deactivateUser(Long id) {
        logger.info("Deactivating user with ID: {}", id);
        
        User user = userRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + id));
        
        user.setActive(false);
        userRepository.save(user);
        
        logger.info("Deactivated user with ID: {}", id);
    }

    /**
     * Activate user
     */
    public void activateUser(Long id) {
        logger.info("Activating user with ID: {}", id);
        
        User user = userRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + id));
        
        user.setActive(true);
        userRepository.save(user);
        
        logger.info("Activated user with ID: {}", id);
    }

    /**
     * Delete user (hard delete)
     */
    public void deleteUser(Long id) {
        logger.warn("Permanently deleting user with ID: {}", id);
        
        if (!userRepository.existsById(id)) {
            throw new IllegalArgumentException("User not found with ID: " + id);
        }
        
        userRepository.deleteById(id);
        logger.warn("Permanently deleted user with ID: {}", id);
    }

    /**
     * Get user statistics
     */
    @Transactional(readOnly = true)
    public UserStatistics getUserStatistics() {
        logger.debug("Generating user statistics for environment: {}", currentEnvironment);
        
        long totalUsers = userRepository.count();
        long activeUsers = userRepository.findByActiveTrue().size();
        long usersInCurrentEnv = userRepository.countByEnvironment(currentEnvironment);
        long activeUsersInCurrentEnv = userRepository.countByEnvironmentAndActiveTrue(currentEnvironment);
        
        return new UserStatistics(totalUsers, activeUsers, usersInCurrentEnv, activeUsersInCurrentEnv, currentEnvironment);
    }

    /**
     * Check if audit is enabled from configuration
     */
    private boolean isAuditEnabled() {
        return appProperties.getFeatures().isAuditEnabled();
    }

    /**
     * Check if debug mode is enabled from configuration
     */
    private boolean isDebugMode() {
        return appProperties.getFeatures().isDebugMode();
    }

    // Inner class for user statistics
    public static class UserStatistics {
        private final long totalUsers;
        private final long activeUsers;
        private final long usersInEnvironment;
        private final long activeUsersInEnvironment;
        private final String environment;

        public UserStatistics(long totalUsers, long activeUsers, long usersInEnvironment, 
                            long activeUsersInEnvironment, String environment) {
            this.totalUsers = totalUsers;
            this.activeUsers = activeUsers;
            this.usersInEnvironment = usersInEnvironment;
            this.activeUsersInEnvironment = activeUsersInEnvironment;
            this.environment = environment;
        }

        // Getters
        public long getTotalUsers() { return totalUsers; }
        public long getActiveUsers() { return activeUsers; }
        public long getUsersInEnvironment() { return usersInEnvironment; }
        public long getActiveUsersInEnvironment() { return activeUsersInEnvironment; }
        public String getEnvironment() { return environment; }
    }
}