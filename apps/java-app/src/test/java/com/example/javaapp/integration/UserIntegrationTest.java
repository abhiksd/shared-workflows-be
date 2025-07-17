package com.example.javaapp.integration;

import com.example.javaapp.entity.User;
import com.example.javaapp.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureWebMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureWebMvc
@Transactional
@ActiveProfiles("test")
class UserIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
        
        testUser = new User();
        testUser.setUsername("integrationuser");
        testUser.setEmail("integration@example.com");
        testUser.setEnvironment("test");
        testUser.setActive(true);
    }

    @Test
    @DisplayName("Integration: Should create user via REST API and persist to database")
    void testCreateUserEndToEnd() throws Exception {
        // When: Create user via REST API
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(testUser)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.username").value("integrationuser"))
                .andExpect(jsonPath("$.email").value("integration@example.com"));

        // Then: Verify user is persisted in database
        assertThat(userRepository.count()).isEqualTo(1);
        User savedUser = userRepository.findAll().get(0);
        assertThat(savedUser.getUsername()).isEqualTo("integrationuser");
        assertThat(savedUser.getEmail()).isEqualTo("integration@example.com");
    }

    @Test
    @DisplayName("Integration: Should retrieve user via REST API from database")
    void testGetUserEndToEnd() throws Exception {
        // Given: User exists in database
        User savedUser = userRepository.save(testUser);

        // When: Get user via REST API
        mockMvc.perform(get("/api/v1/users/" + savedUser.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(savedUser.getId()))
                .andExpect(jsonPath("$.username").value("integrationuser"))
                .andExpect(jsonPath("$.email").value("integration@example.com"));
    }

    @Test
    @DisplayName("Integration: Should update user via REST API and persist changes")
    void testUpdateUserEndToEnd() throws Exception {
        // Given: User exists in database
        User savedUser = userRepository.save(testUser);
        
        // When: Update user via REST API
        testUser.setUsername("updateduser");
        testUser.setEmail("updated@example.com");
        
        mockMvc.perform(put("/api/v1/users/" + savedUser.getId())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("updateduser"))
                .andExpect(jsonPath("$.email").value("updated@example.com"));

        // Then: Verify changes are persisted
        User updatedUser = userRepository.findById(savedUser.getId()).orElseThrow();
        assertThat(updatedUser.getUsername()).isEqualTo("updateduser");
        assertThat(updatedUser.getEmail()).isEqualTo("updated@example.com");
    }

    @Test
    @DisplayName("Integration: Should delete user via REST API and remove from database")
    void testDeleteUserEndToEnd() throws Exception {
        // Given: User exists in database
        User savedUser = userRepository.save(testUser);
        assertThat(userRepository.count()).isEqualTo(1);

        // When: Delete user via REST API
        mockMvc.perform(delete("/api/v1/users/" + savedUser.getId()))
                .andExpect(status().isNoContent());

        // Then: Verify user is removed from database
        assertThat(userRepository.count()).isEqualTo(0);
        assertThat(userRepository.findById(savedUser.getId())).isEmpty();
    }

    @Test
    @DisplayName("Integration: Should get users by environment from database")
    void testGetUsersByEnvironmentEndToEnd() throws Exception {
        // Given: Users with different environments exist
        User testUser1 = new User();
        testUser1.setUsername("testuser1");
        testUser1.setEmail("test1@example.com");
        testUser1.setEnvironment("test");
        testUser1.setActive(true);
        
        User prodUser = new User();
        prodUser.setUsername("produser");
        prodUser.setEmail("prod@example.com");
        prodUser.setEnvironment("prod");
        prodUser.setActive(true);

        userRepository.save(testUser1);
        userRepository.save(prodUser);

        // When: Get users by environment
        mockMvc.perform(get("/api/v1/users/environment/test"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].environment").value("test"))
                .andExpect(jsonPath("$[0].username").value("testuser1"));
    }

    @Test
    @DisplayName("Integration: Should handle application health check")
    void testHealthCheckEndToEnd() throws Exception {
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON));
    }

    @Test
    @DisplayName("Integration: Should handle application info endpoint")
    void testInfoEndToEnd() throws Exception {
        mockMvc.perform(get("/api/v1/info"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON));
    }

    @Test
    @DisplayName("Integration: Should validate user input and return appropriate errors")
    void testUserValidationEndToEnd() throws Exception {
        // Given: Invalid user data
        User invalidUser = new User();
        invalidUser.setUsername(""); // Invalid empty username
        invalidUser.setEmail("invalid-email"); // Invalid email format

        // When: Try to create invalid user
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(invalidUser)))
                .andExpect(status().isBadRequest());

        // Then: No user should be created
        assertThat(userRepository.count()).isEqualTo(0);
    }
}