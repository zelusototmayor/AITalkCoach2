import React from 'react';
import { View, TouchableOpacity, Text, StyleSheet, Platform } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { COLORS, SPACING } from '../constants/colors';
import { useAppNavigation } from '../hooks/useAppNavigation';
import { useHaptics } from '../hooks/useHaptics';

export default function BottomNavigation({ activeScreen }) {
  const { navigateToScreen, getCurrentScreen } = useAppNavigation();
  const haptics = useHaptics();

  const navItems = [
    { id: 'progress', icon: 'trending-up', label: 'Progress' },
    { id: 'coach', icon: 'school-outline', label: 'Coach' },
    { id: 'practice', icon: 'mic', label: 'Practice' },
    { id: 'prompts', icon: 'bulb-outline', label: 'Prompts' },
    { id: 'profile', icon: 'person-outline', label: 'Profile' },
  ];

  const handleNavigation = (screenId) => {
    // Only trigger haptic if switching to a different screen
    if (screenId !== activeScreen) {
      haptics.medium();
    }
    navigateToScreen(screenId);
  };

  return (
    <View style={styles.container}>
      {navItems.map((item, index) => {
        const isActive = activeScreen === item.id;
        const isCenterButton = index === 2; // Practice button is in the center

        if (isCenterButton) {
          return (
            <TouchableOpacity
              key={item.id}
              style={styles.centerButton}
              onPress={() => handleNavigation(item.id)}
              activeOpacity={0.8}
            >
              <View style={styles.centerButtonCircle}>
                <Ionicons
                  name={item.icon}
                  size={28}
                  color="#FFFFFF"
                />
              </View>
            </TouchableOpacity>
          );
        }

        return (
          <TouchableOpacity
            key={item.id}
            style={styles.navItem}
            onPress={() => handleNavigation(item.id)}
            activeOpacity={0.7}
          >
            <Ionicons
              name={item.icon}
              size={24}
              color={isActive ? COLORS.primary : COLORS.textSecondary}
            />
            <Text style={[
              styles.navLabel,
              { color: isActive ? COLORS.primary : COLORS.textSecondary }
            ]}>
              {item.label}
            </Text>
          </TouchableOpacity>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    bottom: 20,
    left: 20,
    right: 20,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    backgroundColor: COLORS.cardBackground,
    borderRadius: 30,
    paddingVertical: 6,
    paddingHorizontal: 16,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 12,
    elevation: 12,
  },
  navItem: {
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 6,
    gap: 2,
  },
  navLabel: {
    fontSize: 11,
    fontWeight: '500',
    marginTop: 2,
  },
  centerButton: {
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: -30, // Lift the center button above the nav bar
  },
  centerButtonCircle: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: COLORS.primary,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: COLORS.primary,
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.4,
    shadowRadius: 8,
    elevation: 8,
    borderWidth: 4,
    borderColor: COLORS.cardBackground,
  },
});
