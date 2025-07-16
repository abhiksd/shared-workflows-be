package com.example.javaapp.service;

import com.example.javaapp.config.AppProperties;
import com.example.javaapp.entity.User;
import com.example.javaapp.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@ActiveProfiles("test")
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private AppProperties appProperties;

    @InjectMocks
    private UserService userService;

    private User testUser;
    private List<User> testUsers;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(userService, "currentEnvironment", "test");
        
        testUser = new User();
        testUser.setId(1L);
        testUser.setUsername("testuser");
        testUser.setEmail("test@example.com");
        testUser.setEnvironment("test");
        testUser.setActive(true);

        User testUser2 = new User();
        testUser2.setId(2L);
        testUser2.setUsername("testuser2");
        testUser2.setEmail("test2@example.com");
        testUser2.setEnvironment("dev");
        testUser2.setActive(false);

        testUsers = Arrays.asList(testUser, testUser2);
    }

    @Test
    @DisplayName("Should return all users when getAllUsers is called")
    void testGetAllUsers() {
        // Given
        when(userRepository.findAll()).thenReturn(testUsers);

        // When
        List<User> result = userService.getAllUsers();

        // Then
        assertThat(result).hasSize(2);
        assertThat(result).containsExactly(testUser, testUsers.get(1));
        verify(userRepository).findAll();
    }

    @Test
    @DisplayName("Should return users by environment when getUsersByEnvironment is called")
    void testGetUsersByEnvironment() {
        // Given
        List<User> testEnvUsers = Arrays.asList(testUser);
        when(userRepository.findByEnvironment("test")).thenReturn(testEnvUsers);

        // When
        List<User> result = userService.getUsersByEnvironment("test");

        // Then
        assertThat(result).hasSize(1);
        assertThat(result.get(0).getEnvironment()).isEqualTo("test");
        verify(userRepository).findByEnvironment("test");
    }

    @Test
    @DisplayName("Should return user by ID when getUserById is called")
    void testGetUserById() {
        // Given
        when(userRepository.findById(1L)).thenReturn(Optional.of(testUser));

        // When
        Optional<User> result = userService.getUserById(1L);

        // Then
        assertThat(result).isPresent();
        assertThat(result.get().getId()).isEqualTo(1L);
        assertThat(result.get().getUsername()).isEqualTo("testuser");
        verify(userRepository).findById(1L);
    }

    @Test
    @DisplayName("Should return empty when user not found by ID")
    void testGetUserByIdNotFound() {
        // Given
        when(userRepository.findById(999L)).thenReturn(Optional.empty());

        // When
        Optional<User> result = userService.getUserById(999L);

        // Then
        assertThat(result).isEmpty();
        verify(userRepository).findById(999L);
    }

    @Test
    @DisplayName("Should create user when createUser is called")
    void testCreateUser() {
        // Given
        User newUser = new User();
        newUser.setUsername("newuser");
        newUser.setEmail("new@example.com");
        
        when(userRepository.save(any(User.class))).thenReturn(testUser);

        // When
        User result = userService.createUser(newUser);

        // Then
        assertThat(result).isNotNull();
        assertThat(result.getId()).isEqualTo(1L);
        verify(userRepository).save(any(User.class));
    }

    @Test
    @DisplayName("Should update user when updateUser is called")
    void testUpdateUser() {
        // Given
        when(userRepository.findById(1L)).thenReturn(Optional.of(testUser));
        when(userRepository.save(any(User.class))).thenReturn(testUser);

        User updateData = new User();
        updateData.setUsername("updateduser");
        updateData.setEmail("updated@example.com");

        // When
        Optional<User> result = userService.updateUser(1L, updateData);

        // Then
        assertThat(result).isPresent();
        verify(userRepository).findById(1L);
        verify(userRepository).save(any(User.class));
    }

    @Test
    @DisplayName("Should return empty when updating non-existent user")
    void testUpdateUserNotFound() {
        // Given
        when(userRepository.findById(999L)).thenReturn(Optional.empty());

        User updateData = new User();
        updateData.setUsername("updateduser");

        // When
        Optional<User> result = userService.updateUser(999L, updateData);

        // Then
        assertThat(result).isEmpty();
        verify(userRepository).findById(999L);
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    @DisplayName("Should delete user when deleteUser is called")
    void testDeleteUser() {
        // Given
        when(userRepository.existsById(1L)).thenReturn(true);
        doNothing().when(userRepository).deleteById(1L);

        // When
        boolean result = userService.deleteUser(1L);

        // Then
        assertThat(result).isTrue();
        verify(userRepository).existsById(1L);
        verify(userRepository).deleteById(1L);
    }

    @Test
    @DisplayName("Should return false when deleting non-existent user")
    void testDeleteUserNotFound() {
        // Given
        when(userRepository.existsById(999L)).thenReturn(false);

        // When
        boolean result = userService.deleteUser(999L);

        // Then
        assertThat(result).isFalse();
        verify(userRepository).existsById(999L);
        verify(userRepository, never()).deleteById(999L);
    }

    @Test
    @DisplayName("Should return active users when getActiveUsers is called")
    void testGetActiveUsers() {
        // Given
        List<User> activeUsers = Arrays.asList(testUser);
        when(userRepository.findByActiveTrue()).thenReturn(activeUsers);

        // When
        List<User> result = userService.getActiveUsers();

        // Then
        assertThat(result).hasSize(1);
        assertThat(result.get(0).isActive()).isTrue();
        verify(userRepository).findByActiveTrue();
    }
}