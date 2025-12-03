import React, { createContext, useContext, useState, useEffect } from 'react';
import * as SecureStore from 'expo-secure-store';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as authService from '../services/authService';
import * as oauthService from '../services/oauthService';
import analytics from '../services/analytics';
import * as subscriptionService from '../services/subscriptionService';

const AuthContext = createContext();

// Keys for storing tokens
const ACCESS_TOKEN_KEY = 'access_token';
const REFRESH_TOKEN_KEY = 'refresh_token';
const USER_DATA_KEY = 'user_data';

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  // Initialize auth state from stored tokens
  useEffect(() => {
    initializeAuth();
    // Configure Google Sign-In
    oauthService.configureGoogleSignIn();
  }, []);

  const initializeAuth = async () => {
    try {
      // Try to get stored access token
      const storedToken = await SecureStore.getItemAsync(ACCESS_TOKEN_KEY);
      const storedUserData = await AsyncStorage.getItem(USER_DATA_KEY);

      if (storedToken && storedUserData) {
        // Validate token by fetching current user
        const currentUser = await authService.getCurrentUser(storedToken);

        if (currentUser) {
          setUser(currentUser);
          setIsAuthenticated(true);

          // Initialize RevenueCat for subscription management
          await subscriptionService.initializePurchases(currentUser.id.toString());
        } else {
          // Token is invalid, try to refresh
          await tryRefreshToken();
        }
      }
    } catch (error) {
      console.error('Error initializing auth:', error);
      // Clear invalid tokens
      await clearAuth();
    } finally {
      setIsLoading(false);
    }
  };

  const tryRefreshToken = async () => {
    try {
      const refreshToken = await SecureStore.getItemAsync(REFRESH_TOKEN_KEY);

      if (refreshToken) {
        const response = await authService.refreshToken(refreshToken);

        if (response.success) {
          await SecureStore.setItemAsync(ACCESS_TOKEN_KEY, response.token);
          await AsyncStorage.setItem(USER_DATA_KEY, JSON.stringify(response.user));

          setUser(response.user);
          setIsAuthenticated(true);

          return true;
        }
      }
    } catch (error) {
      console.error('Error refreshing token:', error);
    }

    // Refresh failed, clear auth
    await clearAuth();
    return false;
  };

  const login = async (email, password) => {
    try {
      const response = await authService.login(email, password);

      if (response.success) {
        // Store tokens securely
        await SecureStore.setItemAsync(ACCESS_TOKEN_KEY, response.token);
        await SecureStore.setItemAsync(REFRESH_TOKEN_KEY, response.refresh_token);

        // Store user data
        await AsyncStorage.setItem(USER_DATA_KEY, JSON.stringify(response.user));

        setUser(response.user);
        setIsAuthenticated(true);

        // Initialize RevenueCat for subscription management
        await subscriptionService.initializePurchases(response.user.id.toString());

        // Track login and identify user
        analytics.identify(response.user.id.toString(), {
          name: response.user.name,
          email: response.user.email,
          onboarding_completed: response.user.onboarding_completed || false,
        });

        analytics.track('User Logged In', {
          user_id: response.user.id,
          email: response.user.email,
          method: 'email',
        });

        return { success: true };
      } else {
        // Track login failure
        analytics.track('Login Failed', {
          email: email,
          error: response.error || 'Login failed',
        });

        return {
          success: false,
          error: response.error || 'Login failed'
        };
      }
    } catch (error) {
      console.error('Login error:', error);

      // Track login error
      analytics.track('Login Error', {
        email: email,
        error: error.message || 'Network error',
      });

      return {
        success: false,
        error: error.message || 'Network error. Please try again.'
      };
    }
  };

  const signup = async (name, email, password, passwordConfirmation) => {
    try {
      const response = await authService.signup(name, email, password, passwordConfirmation);

      if (response.success) {
        // Store tokens securely
        await SecureStore.setItemAsync(ACCESS_TOKEN_KEY, response.token);
        await SecureStore.setItemAsync(REFRESH_TOKEN_KEY, response.refresh_token);

        // Store user data
        await AsyncStorage.setItem(USER_DATA_KEY, JSON.stringify(response.user));

        setUser(response.user);
        setIsAuthenticated(true);

        // Initialize RevenueCat for subscription management
        await subscriptionService.initializePurchases(response.user.id.toString());

        // Track signup and identify user
        analytics.identify(response.user.id.toString(), {
          name: response.user.name,
          email: response.user.email,
          signup_date: new Date().toISOString(),
          onboarding_completed: false,
        });

        analytics.track('User Signed Up', {
          user_id: response.user.id,
          email: response.user.email,
          name: response.user.name,
          method: 'email',
        });

        return { success: true };
      } else {
        // Track signup failure
        analytics.track('Signup Failed', {
          email: email,
          errors: response.errors || ['Signup failed'],
        });

        return {
          success: false,
          errors: response.errors || ['Signup failed']
        };
      }
    } catch (error) {
      console.error('Signup error:', error);

      // Track signup error
      analytics.track('Signup Error', {
        email: email,
        error: error.message || 'Network error',
      });

      return {
        success: false,
        errors: [error.message || 'Network error. Please try again.']
      };
    }
  };

  const loginWithGoogle = async () => {
    try {
      const response = await oauthService.signInWithGoogle();

      if (response.success) {
        // Store tokens securely
        await SecureStore.setItemAsync(ACCESS_TOKEN_KEY, response.token);
        await SecureStore.setItemAsync(REFRESH_TOKEN_KEY, response.refresh_token);

        // Store user data
        await AsyncStorage.setItem(USER_DATA_KEY, JSON.stringify(response.user));

        setUser(response.user);
        setIsAuthenticated(true);

        // Initialize RevenueCat for subscription management
        await subscriptionService.initializePurchases(response.user.id.toString());

        // Track login/signup and identify user
        analytics.identify(response.user.id.toString(), {
          name: response.user.name,
          email: response.user.email,
          auth_provider: 'google',
          onboarding_completed: response.user.onboarding_completed || false,
        });

        const eventName = response.is_new_user ? 'User Signed Up' : 'User Logged In';
        analytics.track(eventName, {
          user_id: response.user.id,
          email: response.user.email,
          method: 'google',
          was_linked: response.was_linked || false,
        });

        return { success: true, isNewUser: response.is_new_user };
      } else {
        return {
          success: false,
          error: response.error || 'Google login failed'
        };
      }
    } catch (error) {
      console.error('Google login error:', error);

      // Track login error
      analytics.track('Login Error', {
        method: 'google',
        error: error.message || 'Google sign-in failed',
      });

      return {
        success: false,
        error: error.message || 'Google sign-in failed. Please try again.'
      };
    }
  };

  const loginWithApple = async () => {
    try {
      // Check if Apple Sign In is available
      const isAvailable = await oauthService.isAppleSignInAvailable();
      if (!isAvailable) {
        return {
          success: false,
          error: 'Apple Sign In is not available on this device'
        };
      }

      const response = await oauthService.signInWithApple();

      if (response.success) {
        // Store tokens securely
        await SecureStore.setItemAsync(ACCESS_TOKEN_KEY, response.token);
        await SecureStore.setItemAsync(REFRESH_TOKEN_KEY, response.refresh_token);

        // Store user data
        await AsyncStorage.setItem(USER_DATA_KEY, JSON.stringify(response.user));

        setUser(response.user);
        setIsAuthenticated(true);

        // Initialize RevenueCat for subscription management
        await subscriptionService.initializePurchases(response.user.id.toString());

        // Track login/signup and identify user
        analytics.identify(response.user.id.toString(), {
          name: response.user.name,
          email: response.user.email,
          auth_provider: 'apple',
          onboarding_completed: response.user.onboarding_completed || false,
        });

        const eventName = response.is_new_user ? 'User Signed Up' : 'User Logged In';
        analytics.track(eventName, {
          user_id: response.user.id,
          email: response.user.email,
          method: 'apple',
          was_linked: response.was_linked || false,
        });

        return { success: true, isNewUser: response.is_new_user };
      } else {
        return {
          success: false,
          error: response.error || 'Apple login failed'
        };
      }
    } catch (error) {
      console.error('Apple login error:', error);

      // Track login error
      analytics.track('Login Error', {
        method: 'apple',
        error: error.message || 'Apple sign-in failed',
      });

      return {
        success: false,
        error: error.message || 'Apple sign-in failed. Please try again.'
      };
    }
  };

  const logout = async () => {
    try {
      // Track logout before clearing user data
      analytics.track('User Logged Out', {
        user_id: user?.id,
      });

      // Call logout API (optional - JWT tokens are stateless)
      const token = await SecureStore.getItemAsync(ACCESS_TOKEN_KEY);
      if (token) {
        await authService.logout(token);
      }

      // Sign out from Google if signed in
      await oauthService.signOutGoogle();

      // Log out from RevenueCat
      await subscriptionService.logoutUser();
    } catch (error) {
      console.error('Logout error:', error);
      // Continue with local logout even if API call fails
    }

    // Reset analytics (clears user identification)
    analytics.reset();

    // Clear local auth state
    await clearAuth();
  };

  const clearAuth = async () => {
    try {
      await SecureStore.deleteItemAsync(ACCESS_TOKEN_KEY);
      await SecureStore.deleteItemAsync(REFRESH_TOKEN_KEY);
      await AsyncStorage.removeItem(USER_DATA_KEY);
    } catch (error) {
      console.error('Error clearing auth:', error);
    }

    setUser(null);
    setIsAuthenticated(false);
  };

  const getAccessToken = async () => {
    try {
      const token = await SecureStore.getItemAsync(ACCESS_TOKEN_KEY);
      return token;
    } catch (error) {
      console.error('Error getting access token:', error);
      return null;
    }
  };

  const updateUserData = (updates) => {
    const updatedUser = { ...user, ...updates };
    setUser(updatedUser);
    AsyncStorage.setItem(USER_DATA_KEY, JSON.stringify(updatedUser));
  };

  const forgotPassword = async (email) => {
    try {
      const response = await authService.forgotPassword(email);
      return response;
    } catch (error) {
      console.error('Forgot password error:', error);
      return {
        success: false,
        error: error.message || 'Failed to send reset email'
      };
    }
  };

  const resetPassword = async (token, newPassword) => {
    try {
      const response = await authService.resetPassword(token, newPassword);
      return response;
    } catch (error) {
      console.error('Reset password error:', error);
      return {
        success: false,
        error: error.message || 'Failed to reset password'
      };
    }
  };

  const completeOnboarding = async (onboardingData = {}) => {
    try {
      const token = await getAccessToken();
      if (!token) {
        throw new Error('No access token found');
      }

      console.log('AuthContext: Completing onboarding with data:', onboardingData);

      const response = await authService.completeOnboarding(token, onboardingData);

      if (response.success && response.user) {
        // Update user with the complete user object from API (includes preferred_language)
        const updatedUser = { ...response.user, onboarding_completed: true };
        setUser(updatedUser);
        await AsyncStorage.setItem(USER_DATA_KEY, JSON.stringify(updatedUser));

        // Track onboarding completion with demographics
        analytics.track('Onboarding Completed', {
          user_id: updatedUser.id,
          language: onboardingData.language,
          communication_style: onboardingData.communicationStyle,
          age_range: onboardingData.ageRange,
        });

        analytics.setUserProperties({
          onboarding_completed: true,
          onboarding_completion_date: new Date().toISOString(),
          preferred_language: onboardingData.language,
        });

        return { success: true };
      }

      return { success: false, error: 'Failed to complete onboarding' };
    } catch (error) {
      console.error('Complete onboarding error:', error);
      return {
        success: false,
        error: error.message || 'Failed to complete onboarding'
      };
    }
  };

  const deleteAccount = async () => {
    try {
      // Track account deletion before clearing user data
      analytics.track('Account Deleted', {
        user_id: user?.id,
      });

      // Call delete account API
      const token = await getAccessToken();
      if (!token) {
        throw new Error('No access token found');
      }

      const response = await authService.deleteAccount(token);

      if (response.success) {
        // Log out from RevenueCat
        await subscriptionService.logoutUser();

        // Reset analytics (clears user identification)
        analytics.reset();

        // Clear local auth state
        await clearAuth();

        return { success: true };
      } else {
        return {
          success: false,
          error: response.error || 'Failed to delete account'
        };
      }
    } catch (error) {
      console.error('Delete account error:', error);
      return {
        success: false,
        error: error.message || 'Failed to delete account'
      };
    }
  };

  const value = {
    user,
    isLoading,
    isAuthenticated,
    login,
    signup,
    loginWithGoogle,
    loginWithApple,
    logout,
    getAccessToken,
    updateUserData,
    forgotPassword,
    resetPassword,
    completeOnboarding,
    deleteAccount,
    tryRefreshToken,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};