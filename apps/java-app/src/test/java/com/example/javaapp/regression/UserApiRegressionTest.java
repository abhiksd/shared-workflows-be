package com.example.javaapp.regression;

import com.example.javaapp.entity.User;
import com.example.javaapp.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.TestMethodOrder;
import org.junit.jupiter.api.MethodOrderer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureWebMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.assertj.core.api.Assertions.*;

@SpringBootTest
@AutoConfigureWebMvc
@Transactional
@ActiveProfiles("test")
@Tag("regression")
@TestMethodOrder(MethodOrderer.DisplayName.class)
class UserApiRegressionTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("Regression: Core API endpoints maintain expected response structure")
    void testApiResponseStructure() throws Exception {
        // Test home endpoint maintains expected structure
        mockMvc.perform(get("/api/v1/"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").exists())
                .andExpect(jsonPath("$.environment").exists())
                .andExpect(jsonPath("$.version").exists())
                .andExpect(jsonPath("$.timestamp").exists())
                .andExpect(jsonPath("$.status").value("OK"));

        // Test info endpoint maintains expected structure
        mockMvc.perform(get("/api/v1/info"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON));

        // Test health endpoint maintains expected structure
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON));
    }

    @Test
    @DisplayName("Regression: User CRUD operations maintain backward compatibility")
    void testUserCrudBackwardCompatibility() throws Exception {
        // Create user with all legacy fields
        User user = new User();
        user.setUsername("regressionuser");
        user.setEmail("regression@example.com");
        user.setEnvironment("test");
        user.setActive(true);

        // Create user
        String response = mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(user)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.username").value("regressionuser"))
                .andExpect(jsonPath("$.email").value("regression@example.com"))
                .andExpect(jsonPath("$.environment").value("test"))
                .andExpect(jsonPath("$.active").value(true))
                .andReturn().getResponse().getContentAsString();

        User createdUser = objectMapper.readValue(response, User.class);
        Long userId = createdUser.getId();

        // Read user
        mockMvc.perform(get("/api/v1/users/" + userId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId))
                .andExpect(jsonPath("$.username").value("regressionuser"));

        // Update user
        user.setUsername("updateduser");
        mockMvc.perform(put("/api/v1/users/" + userId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(user)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("updateduser"));

        // Delete user
        mockMvc.perform(delete("/api/v1/users/" + userId))
                .andExpect(status().isNoContent());

        // Verify deletion
        mockMvc.perform(get("/api/v1/users/" + userId))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("Regression: Environment-specific user filtering works correctly")
    void testEnvironmentFilteringRegression() throws Exception {
        // Create users in different environments
        User devUser = createUser("devuser", "dev@example.com", "dev");
        User stagingUser = createUser("staginguser", "staging@example.com", "staging");
        User prodUser = createUser("produser", "prod@example.com", "prod");

        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(devUser)))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(stagingUser)))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(prodUser)))
                .andExpect(status().isCreated());

        // Test environment filtering for each environment
        mockMvc.perform(get("/api/v1/users/environment/dev"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].environment").value("dev"));

        mockMvc.perform(get("/api/v1/users/environment/staging"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].environment").value("staging"));

        mockMvc.perform(get("/api/v1/users/environment/prod"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].environment").value("prod"));
    }

    @Test
    @DisplayName("Regression: Error handling maintains consistent format")
    void testErrorHandlingRegression() throws Exception {
        // Test 404 for non-existent user
        mockMvc.perform(get("/api/v1/users/99999"))
                .andExpect(status().isNotFound());

        // Test 400 for invalid user data
        User invalidUser = new User();
        invalidUser.setUsername(""); // Invalid
        invalidUser.setEmail("invalid-email"); // Invalid

        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(invalidUser)))
                .andExpect(status().isBadRequest());

        // Test 404 for non-existent environment
        mockMvc.perform(get("/api/v1/users/environment/nonexistent"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    @DisplayName("Regression: Performance benchmarks for user operations")
    void testPerformanceRegression() throws Exception {
        // Create multiple users to test performance
        for (int i = 0; i < 100; i++) {
            User user = createUser("user" + i, "user" + i + "@example.com", "test");
            mockMvc.perform(post("/api/v1/users")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(user)))
                    .andExpect(status().isCreated());
        }

        // Test that fetching all users performs within reasonable time
        long startTime = System.currentTimeMillis();
        mockMvc.perform(get("/api/v1/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(100));
        long endTime = System.currentTimeMillis();

        // Assert performance is within acceptable limits (< 1 second)
        assertThat(endTime - startTime).isLessThan(1000);
    }

    @Test
    @DisplayName("Regression: Data consistency across operations")
    void testDataConsistencyRegression() throws Exception {
        // Create user
        User user = createUser("consistencyuser", "consistency@example.com", "test");
        String response = mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(user)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        User createdUser = objectMapper.readValue(response, User.class);
        Long userId = createdUser.getId();

        // Verify user appears in all lists
        mockMvc.perform(get("/api/v1/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.id == " + userId + ")].username").value("consistencyuser"));

        mockMvc.perform(get("/api/v1/users/environment/test"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.id == " + userId + ")].username").value("consistencyuser"));

        // Update user and verify consistency
        user.setUsername("updatedconsistency");
        mockMvc.perform(put("/api/v1/users/" + userId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(user)))
                .andExpect(status().isOk());

        // Verify update is reflected in all endpoints
        mockMvc.perform(get("/api/v1/users/" + userId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("updatedconsistency"));

        mockMvc.perform(get("/api/v1/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.id == " + userId + ")].username").value("updatedconsistency"));
    }

    @Test
    @DisplayName("Regression: Security headers and CORS settings")
    void testSecurityRegression() throws Exception {
        // Test that security headers are present
        mockMvc.perform(get("/api/v1/"))
                .andExpect(status().isOk())
                .andExpect(header().exists("Content-Type"));
                // Add more security header checks as needed

        // Test CORS preflight
        mockMvc.perform(options("/api/v1/users")
                .header("Origin", "http://localhost:3000")
                .header("Access-Control-Request-Method", "POST")
                .header("Access-Control-Request-Headers", "Content-Type"))
                .andExpect(status().isOk());
    }

    private User createUser(String username, String email, String environment) {
        User user = new User();
        user.setUsername(username);
        user.setEmail(email);
        user.setEnvironment(environment);
        user.setActive(true);
        return user;
    }
}