import React from 'react';
import { TouchableOpacity, StyleSheet, Alert } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useAuth } from '../context/AuthContext';
import { COLORS } from '../constants/colors';

export default function QuitOnboardingButton() {
  const { logout } = useAuth();

  const handleQuit = () => {
    Alert.alert(
      'Quit Onboarding?',
      'Are you sure you want to quit? You\'ll need to start over.',
      [
        {
          text: 'Cancel',
          style: 'cancel',
        },
        {
          text: 'Quit',
          style: 'destructive',
          onPress: async () => {
            await logout();
          },
        },
      ],
      { cancelable: true }
    );
  };

  return (
    <TouchableOpacity
      style={styles.quitButton}
      onPress={handleQuit}
      activeOpacity={0.7}
    >
      <Ionicons name="close" size={20} color={COLORS.textSecondary} />
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  quitButton: {
    position: 'absolute',
    top: 50,
    left: 20,
    width: 32,
    height: 32,
    borderRadius: 8,
    backgroundColor: '#f1f5f9',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 100,
  },
});
