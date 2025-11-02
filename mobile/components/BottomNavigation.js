import React from 'react';
import { View, TouchableOpacity, Text, StyleSheet, Platform } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { COLORS, SPACING } from '../constants/colors';

export default function BottomNavigation({ activeScreen, onNavigate }) {
  const navItems = [
    { id: 'progress', icon: 'trending-up', label: 'Progress' },
    { id: 'coach', icon: 'school-outline', label: 'Coach' },
    { id: 'practice', icon: 'mic', label: 'Practice' },
    { id: 'prompts', icon: 'bulb-outline', label: 'Prompts' },
    { id: 'profile', icon: 'person-outline', label: 'Profile' },
  ];

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
              onPress={() => onNavigate(item.id)}
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
            onPress={() => onNavigate(item.id)}
            activeOpacity={0.7}
          >
            <Ionicons
              name={item.icon}
              size={24}
              color={isActive ? COLORS.primary : COLORS.textSecondary}
            />
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
    paddingVertical: 12,
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
    alignItems: 'center',
    justifyContent: 'center',
    padding: 12,
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
