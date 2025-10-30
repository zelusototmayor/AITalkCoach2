import React, { useState } from 'react';
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
import { COLORS, SPACING } from '../../constants/colors';
import { useOnboarding } from '../../context/OnboardingContext';

export default function LoginScreen({ navigation }) {
  const { updateOnboardingData } = useOnboarding();
  const [formData, setFormData] = useState({
    email: '',
    password: '',
  });
  const [errors, setErrors] = useState({});

  const validateForm = () => {
    const newErrors = {};

    if (!formData.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(formData.email)) {
      newErrors.email = 'Email is invalid';
    }

    if (!formData.password) {
      newErrors.password = 'Password is required';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleLogin = () => {
    if (validateForm()) {
      // TODO: Implement actual login API call
      updateOnboardingData({ user: { email: formData.email } });

      // Navigate to the practice page (main app) instead of onboarding
      // TODO: When main app screens are implemented, navigate there
      // For now, we'll navigate to the practice page placeholder
      Alert.alert(
        'Login Successful',
        'You would be redirected to the practice page. (To be implemented)',
        [
          {
            text: 'OK',
            onPress: () => {
              // Temporary: Navigate to onboarding for demo purposes
              // Replace with: navigation.navigate('Practice') when available
              navigation.navigate('ValueProp');
            },
          },
        ]
      );
    }
  };

  const handleInputChange = (field, value) => {
    setFormData({ ...formData, [field]: value });
    // Clear error for this field when user starts typing
    if (errors[field]) {
      setErrors({ ...errors, [field]: null });
    }
  };

  const handleForgotPassword = () => {
    Alert.alert(
      'Forgot Password',
      'Password reset functionality coming soon!',
      [{ text: 'OK' }]
    );
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.header}>
          <Text style={styles.title}>Welcome back</Text>
          <Text style={styles.subtitle}>
            Login to continue improving your speaking skills
          </Text>
        </View>

        <View style={styles.form}>
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
              autoFocus={true}
            />
            {errors.email && <Text style={styles.errorText}>{errors.email}</Text>}
          </View>

          <View style={styles.inputGroup}>
            <Text style={styles.label}>Password</Text>
            <TextInput
              style={[styles.input, errors.password && styles.inputError]}
              placeholder="Enter your password"
              placeholderTextColor={COLORS.textSecondary}
              value={formData.password}
              onChangeText={(value) => handleInputChange('password', value)}
              secureTextEntry
              autoCapitalize="none"
            />
            {errors.password && <Text style={styles.errorText}>{errors.password}</Text>}

            <TouchableOpacity style={styles.forgotPassword} onPress={handleForgotPassword}>
              <Text style={styles.forgotPasswordText}>Forgot your password?</Text>
            </TouchableOpacity>
          </View>
        </View>

        <TouchableOpacity style={styles.loginButton} onPress={handleLogin}>
          <Text style={styles.loginButtonText}>Login</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.signupLink}
          onPress={() => navigation.navigate('SignUp')}
        >
          <Text style={styles.signupLinkText}>
            Don't have an account? <Text style={styles.signupLinkBold}>Sign up here</Text>
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.backLink}
          onPress={() => navigation.navigate('Welcome')}
        >
          <Text style={styles.backLinkText}>← Back to home</Text>
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
    paddingTop: 80,
    paddingBottom: 40,
  },
  header: {
    alignItems: 'center',
    marginBottom: SPACING.xxl * 1.5,
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
  forgotPassword: {
    alignSelf: 'flex-end',
    marginTop: SPACING.sm,
  },
  forgotPasswordText: {
    fontSize: 14,
    color: COLORS.primary,
    fontWeight: '500',
  },
  loginButton: {
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
  loginButtonText: {
    color: COLORS.background,
    fontSize: 16,
    fontWeight: '600',
    letterSpacing: 0.5,
  },
  signupLink: {
    alignItems: 'center',
    paddingVertical: SPACING.sm,
    marginBottom: SPACING.lg,
  },
  signupLinkText: {
    fontSize: 14,
    color: COLORS.textSecondary,
  },
  signupLinkBold: {
    fontWeight: '600',
    color: COLORS.primary,
  },
  backLink: {
    alignItems: 'center',
    paddingVertical: SPACING.sm,
  },
  backLinkText: {
    fontSize: 14,
    color: COLORS.primary,
    fontWeight: '500',
  },
});