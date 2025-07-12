package com.example.javaapp.repository;

import com.example.javaapp.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    /**
     * Find user by username
     */
    Optional<User> findByUsername(String username);

    /**
     * Find user by email
     */
    Optional<User> findByEmail(String email);

    /**
     * Find all active users
     */
    List<User> findByActiveTrue();

    /**
     * Find users by environment
     */
    List<User> findByEnvironment(String environment);

    /**
     * Find active users by environment
     */
    List<User> findByEnvironmentAndActiveTrue(String environment);

    /**
     * Check if username exists
     */
    boolean existsByUsername(String username);

    /**
     * Check if email exists
     */
    boolean existsByEmail(String email);

    /**
     * Count users by environment
     */
    long countByEnvironment(String environment);

    /**
     * Count active users by environment
     */
    long countByEnvironmentAndActiveTrue(String environment);

    /**
     * Custom query to find users with custom conditions
     */
    @Query("SELECT u FROM User u WHERE u.environment = :environment AND u.active = :active ORDER BY u.createdAt DESC")
    List<User> findUsersByEnvironmentAndStatus(@Param("environment") String environment, @Param("active") Boolean active);

    /**
     * Custom query to find recent users
     */
    @Query("SELECT u FROM User u WHERE u.active = true ORDER BY u.createdAt DESC LIMIT :limit")
    List<User> findRecentActiveUsers(@Param("limit") int limit);
}