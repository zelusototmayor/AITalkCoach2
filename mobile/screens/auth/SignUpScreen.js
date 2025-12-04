import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import AnimatedBackground from '../../components/AnimatedBackground';
import { COLORS, SPACING } from '../../constants/colors';
import { useAuth } from '../../context/AuthContext';
import * as oauthService from '../../services/oauthService';

export default function SignUpScreen({ navigation }) {
  const { signup, loginWithGoogle, loginWithApple } = useAuth();
  const [isAppleAvailable, setIsAppleAvailable] = useState(false);
  const [isGoogleAvailable, setIsGoogleAvailable] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
    confirmPassword: '',
  });
  const [errors, setErrors] = useState({});
  const [isLoading, setIsLoading] = useState(false);
  const [isOAuthLoading, setIsOAuthLoading] = useState(false);

  // Check OAuth availability
  useEffect(() => {
    const checkOAuthAvailability = async () => {
      // Google Sign-In requires native module (not available in Expo Go)
      setIsGoogleAvailable(oauthService.isGoogleSignInAvailable());

      // On iOS, always show the Apple button - the system will handle unavailability
      if (Platform.OS === 'ios') {
        setIsAppleAvailable(true);
      } else {
        const available = await oauthService.isAppleSignInAvailable();
        setIsAppleAvailable(available);
      }
    };
    checkOAuthAvailability();
  }, []);

  const validateForm = () => {
    const newErrors = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Name is required';
    }

    if (!formData.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(formData.email)) {
      newErrors.email = 'Email is invalid';
    }

    if (!formData.password) {
      newErrors.password = 'Password is required';
    } else if (formData.password.length < 6) {
      newErrors.password = 'Password must be at least 6 characters';
    }

    if (!formData.confirmPassword) {
      newErrors.confirmPassword = 'Please confirm your password';
    } else if (formData.password !== formData.confirmPassword) {
      newErrors.confirmPassword = 'Passwords do not match';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSignUp = async () => {
    if (!validateForm()) {
      return;
    }

    setIsLoading(true);
    setErrors({});

    try {
      const result = await signup(
        formData.name,
        formData.email,
        formData.password,
        formData.confirmPassword
      );

      if (result.success) {
        // Navigation will be handled automatically by MainNavigator
        // based on authentication state change
      } else {
        // Handle signup errors
        if (result.errors && Array.isArray(result.errors)) {
          const errorObj = {};
          result.errors.forEach(error => {
            if (error.toLowerCase().includes('email')) {
              errorObj.email = error;
            } else if (error.toLowerCase().includes('password')) {
              errorObj.password = error;
            } else if (error.toLowerCase().includes('name')) {
              errorObj.name = error;
            } else {
              errorObj.general = error;
            }
          });
          setErrors(errorObj);
        } else {
          setErrors({ general: 'Signup failed. Please try again.' });
        }
      }
    } catch (error) {
      console.error('Signup error:', error);
      setErrors({ general: 'Network error. Please check your connection and try again.' });
    } finally {
      setIsLoading(false);
    }
  };

  const handleInputChange = (field, value) => {
    setFormData({ ...formData, [field]: value });
    // Clear error for this field when user starts typing
    if (errors[field]) {
      setErrors({ ...errors, [field]: null });
    }
  };

  const handleGoogleSignUp = async () => {
    setIsOAuthLoading(true);
    setErrors({});

    try {
      const result = await loginWithGoogle();

      if (!result.success) {
        setErrors({ general: result.error || 'Google sign-up failed. Please try again.' });
      }
      // Navigation handled automatically on success
    } catch (error) {
      console.error('Google sign-up error:', error);
      setErrors({ general: 'Google sign-up failed. Please try again.' });
    } finally {
      setIsOAuthLoading(false);
    }
  };

  const handleAppleSignUp = async () => {
    setIsOAuthLoading(true);
    setErrors({});

    try {
      const result = await loginWithApple();

      if (!result.success) {
        setErrors({ general: result.error || 'Apple sign-up failed. Please try again.' });
      }
      // Navigation handled automatically on success
    } catch (error) {
      console.error('Apple sign-up error:', error);
      setErrors({ general: 'Apple sign-up failed. Please try again.' });
    } finally {
      setIsOAuthLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <AnimatedBackground />
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.header}>
          <Text style={styles.title}>Welcome to AI Coach</Text>
          <Text style={styles.subtitle}>
            Congrats on taking the first step to becoming a master communicator.
          </Text>
          {errors.general && (
            <View style={styles.errorContainer}>
              <Text style={styles.generalError}>{errors.general}</Text>
            </View>
          )}
        </View>

        <View style={styles.form}>
          <View style={styles.inputGroup}>
            <Text style={styles.label}>Name</Text>
            <TextInput
              style={[styles.input, errors.name && styles.inputError]}
              placeholder="Enter your full name"
              placeholderTextColor={COLORS.textSecondary}
              value={formData.name}
              onChangeText={(value) => handleInputChange('name', value)}
              autoCapitalize="words"
              autoCorrect={false}
            />
            {errors.name && <Text style={styles.errorText}>{errors.name}</Text>}
          </View>

          <View style={styles.inputGroup}>
            <Text style={styles.label}>Email</Text>
            <TextInput
              style={[styles.input, errors.email && styles.inputError]}
              placeholder="Enter your email address"
              placeholderTextColor={COLORS.textSecondary}
              value={formData.email}
              onChangeText={(value) => handleInputChange('email', value)}
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
            />
            {errors.email && <Text style={styles.errorText}>{errors.email}</Text>}
          </View>

          <View style={styles.inputGroup}>
            <Text style={styles.label}>Password</Text>
            <TextInput
              style={[styles.input, errors.password && styles.inputError]}
              placeholder="Choose a secure password (min 6 characters)"
              placeholderTextColor={COLORS.textSecondary}
              value={formData.password}
              onChangeText={(value) => handleInputChange('password', value)}
              secureTextEntry
              autoCapitalize="none"
            />
            {errors.password && <Text style={styles.errorText}>{errors.password}</Text>}
          </View>

          <View style={styles.inputGroup}>
            <Text style={styles.label}>Confirm Password</Text>
            <TextInput
              style={[styles.input, errors.confirmPassword && styles.inputError]}
              placeholder="Confirm your password"
              placeholderTextColor={COLORS.textSecondary}
              value={formData.confirmPassword}
              onChangeText={(value) => handleInputChange('confirmPassword', value)}
              secureTextEntry
              autoCapitalize="none"
            />
            {errors.confirmPassword && (
              <Text style={styles.errorText}>{errors.confirmPassword}</Text>
            )}
          </View>
        </View>

        <TouchableOpacity
          style={[styles.continueButton, (isLoading || isOAuthLoading) && styles.continueButtonDisabled]}
          onPress={handleSignUp}
          disabled={isLoading || isOAuthLoading}
        >
          <Text style={styles.continueButtonText}>
            {isLoading ? 'Creating account...' : 'Continue'}
          </Text>
        </TouchableOpacity>

        {/* OAuth Divider */}
        <View style={styles.dividerContainer}>
          <View style={styles.divider} />
          <Text style={styles.dividerText}>or sign up with</Text>
          <View style={styles.divider} />
        </View>

        {/* Social Sign Up Buttons */}
        <View style={styles.socialButtonsContainer}>
          <TouchableOpacity
            style={[styles.socialButton, (isLoading || isOAuthLoading) && styles.socialButtonDisabled]}
            onPress={handleGoogleSignUp}
            disabled={isLoading || isOAuthLoading}
          >
            <Text style={styles.socialButtonText}>
              {isOAuthLoading ? 'Signing up...' : 'Continue with Google'}
            </Text>
          </TouchableOpacity>

          {isAppleAvailable && (
            <TouchableOpacity
              style={[styles.socialButton, styles.appleButton, (isLoading || isOAuthLoading) && styles.socialButtonDisabled]}
              onPress={handleAppleSignUp}
              disabled={isLoading || isOAuthLoading}
            >
              <Text style={[styles.socialButtonText, styles.appleButtonText]}>
                {isOAuthLoading ? 'Signing up...' : 'Continue with Apple'}
              </Text>
            </TouchableOpacity>
          )}
        </View>

        <TouchableOpacity
          style={styles.loginLink}
          onPress={() => navigation.navigate('Login')}
        >
          <Text style={styles.loginLinkText}>
            Already have an account? <Text style={styles.loginLinkBold}>Login</Text>
          </Text>
        </TouchableOpacity>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  scrollContent: {
    flexGrow: 1,
    paddingHorizontal: SPACING.lg,
    paddingTop: 60,
    paddingBottom: 40,
  },
  header: {
    alignItems: 'center',
    marginBottom: SPACING.xxl,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: COLORS.text,
    marginBottom: SPACING.sm,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    color: COLORS.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
    paddingHorizontal: SPACING.lg,
  },
  form: {
    marginBottom: SPACING.xl,
  },
  inputGroup: {
    marginBottom: SPACING.lg,
  },
  label: {
    fontSize: 14,
    fontWeight: '500',
    color: COLORS.text,
    marginBottom: SPACING.xs,
  },
  input: {
    backgroundColor: COLORS.cardBackground,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 12,
    paddingVertical: 14,
    paddingHorizontal: 16,
    fontSize: 16,
    color: COLORS.text,
  },
  inputError: {
    borderColor: '#ef4444',
  },
  errorText: {
    color: '#ef4444',
    fontSize: 12,
    marginTop: 4,
    marginLeft: 4,
  },
  continueButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    marginBottom: SPACING.lg,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  continueButtonText: {
    color: COLORS.background,
    fontSize: 16,
    fontWeight: '600',
    letterSpacing: 0.5,
  },
  loginLink: {
    alignItems: 'center',
    paddingVertical: SPACING.sm,
  },
  loginLinkText: {
    fontSize: 14,
    color: COLORS.textSecondary,
  },
  loginLinkBold: {
    fontWeight: '600',
    color: COLORS.primary,
  },
  errorContainer: {
    backgroundColor: '#fee',
    borderRadius: 8,
    padding: SPACING.sm,
    marginTop: SPACING.md,
    width: '100%',
  },
  generalError: {
    color: '#c00',
    fontSize: 14,
    textAlign: 'center',
  },
  continueButtonDisabled: {
    opacity: 0.6,
  },
  dividerContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: SPACING.lg,
  },
  divider: {
    flex: 1,
    height: 1,
    backgroundColor: COLORS.border,
  },
  dividerText: {
    marginHorizontal: SPACING.md,
    fontSize: 14,
    color: COLORS.textSecondary,
  },
  socialButtonsContainer: {
    gap: SPACING.sm,
    marginBottom: SPACING.lg,
  },
  socialButton: {
    backgroundColor: COLORS.cardBackground,
    borderWidth: 1,
    borderColor: COLORS.border,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
  },
  socialButtonDisabled: {
    opacity: 0.6,
  },
  socialButtonText: {
    color: COLORS.text,
    fontSize: 16,
    fontWeight: '500',
  },
  appleButton: {
    backgroundColor: '#000',
    borderColor: '#000',
  },
  appleButtonText: {
    color: '#fff',
  },
});