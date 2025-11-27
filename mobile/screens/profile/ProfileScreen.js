import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert, ActivityIndicator, Modal, TextInput, Image } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import AnimatedBackground from '../../components/AnimatedBackground';
import BottomNavigation from '../../components/BottomNavigation';
import { COLORS, SPACING, TYPOGRAPHY } from '../../constants/colors';
import { useAuth } from '../../context/AuthContext';
import { submitFeedback } from '../../services/api';

export default function ProfileScreen({ navigation }) {
  const { user, logout, updateUserData } = useAuth();

  // Feedback modal state
  const [feedbackModalVisible, setFeedbackModalVisible] = useState(false);
  const [feedbackText, setFeedbackText] = useState('');
  const [feedbackImages, setFeedbackImages] = useState([]);
  const [feedbackSubmitting, setFeedbackSubmitting] = useState(false);

  const menuItems = [
    { id: 'language', label: 'Language', icon: 'language-outline', screen: 'Language' },
    { id: 'settings', label: 'Settings', icon: 'settings-outline', screen: 'Settings' },
    { id: 'history', label: 'Practice History', icon: 'time-outline', screen: 'History' },
    { id: 'privacy', label: 'Privacy', icon: 'shield-outline', screen: 'Privacy' },
    { id: 'help', label: 'Help & Support', icon: 'help-circle-outline', screen: null },
  ];

  const handleMenuPress = (item) => {
    if (item.screen) {
      navigation.navigate(item.screen);
    }
  };

  const handleLogout = () => {
    Alert.alert(
      'Log Out',
      'Are you sure you want to log out?',
      [
        {
          text: 'Cancel',
          style: 'cancel',
        },
        {
          text: 'Log Out',
          style: 'destructive',
          onPress: async () => {
            await logout();
          },
        },
      ],
      { cancelable: true }
    );
  };

  const handlePickImage = async () => {
    if (feedbackImages.length >= 5) {
      Alert.alert('Maximum Reached', 'You can only attach up to 5 images.');
      return;
    }

    const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('Permission Required', 'Please allow access to your photo library to attach images.');
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsMultipleSelection: false,
      quality: 0.8,
    });

    if (!result.canceled && result.assets && result.assets.length > 0) {
      const asset = result.assets[0];
      setFeedbackImages([...feedbackImages, {
        uri: asset.uri,
        name: `image_${Date.now()}.jpg`,
        type: 'image/jpeg',
      }]);
    }
  };

  const handleRemoveImage = (index) => {
    setFeedbackImages(feedbackImages.filter((_, i) => i !== index));
  };

  const handleSubmitFeedback = async () => {
    if (!feedbackText.trim()) {
      Alert.alert('Feedback Required', 'Please enter your feedback before submitting.');
      return;
    }

    if (feedbackText.length > 5000) {
      Alert.alert('Too Long', 'Feedback must be less than 5000 characters.');
      return;
    }

    setFeedbackSubmitting(true);

    try {
      await submitFeedback(feedbackText, feedbackImages);

      Alert.alert(
        'Thank You!',
        'Your feedback has been submitted successfully. We appreciate your input!',
        [{ text: 'OK', onPress: () => {
          setFeedbackModalVisible(false);
          setFeedbackText('');
          setFeedbackImages([]);
        }}]
      );
    } catch (error) {
      console.error('Error submitting feedback:', error);
      Alert.alert('Error', 'Failed to submit feedback. Please try again or email us directly.');
    } finally {
      setFeedbackSubmitting(false);
    }
  };

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <AnimatedBackground />

      <ScrollView style={styles.content}>
        <Text style={styles.title}>Profile</Text>

        <View style={styles.userInfoCard}>
          <View style={styles.avatar}>
            <Ionicons name="person" size={40} color={COLORS.primary} />
          </View>
          <Text style={styles.userName}>{user?.name || 'User Name'}</Text>
          <Text style={styles.userEmail}>{user?.email || 'user@example.com'}</Text>
        </View>

        <View style={styles.menuContainer}>
          {menuItems.map((item) => (
            <TouchableOpacity
              key={item.id}
              style={styles.menuItem}
              onPress={() => handleMenuPress(item)}
              activeOpacity={0.7}
            >
              <View style={styles.menuItemLeft}>
                <Ionicons name={item.icon} size={24} color={COLORS.text} />
                <Text style={styles.menuItemLabel}>{item.label}</Text>
              </View>
              <Ionicons name="chevron-forward" size={20} color={COLORS.textSecondary} />
            </TouchableOpacity>
          ))}
        </View>

        {/* Feedback Button */}
        <TouchableOpacity
          style={styles.feedbackButton}
          onPress={() => setFeedbackModalVisible(true)}
          activeOpacity={0.7}
        >
          <Ionicons name="chatbox-ellipses-outline" size={24} color={COLORS.primary} style={styles.feedbackIcon} />
          <Text style={styles.feedbackButtonText}>Share Feedback</Text>
          <Ionicons name="chevron-forward" size={20} color={COLORS.primary} />
        </TouchableOpacity>

        <TouchableOpacity style={styles.logoutButton} onPress={handleLogout} activeOpacity={0.7}>
          <Text style={styles.logoutText}>Log Out</Text>
        </TouchableOpacity>
      </ScrollView>

      <BottomNavigation activeScreen="profile" />

      {/* Feedback Modal */}
      <Modal
        visible={feedbackModalVisible}
        animationType="slide"
        transparent={true}
        onRequestClose={() => setFeedbackModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Share Your Feedback</Text>
              <TouchableOpacity
                onPress={() => setFeedbackModalVisible(false)}
                style={styles.modalCloseButton}
              >
                <Ionicons name="close" size={28} color={COLORS.text} />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.modalBody} showsVerticalScrollIndicator={false}>
              <Text style={styles.modalDescription}>
                We'd love to hear your thoughts, suggestions, or report any issues you've encountered.
              </Text>

              <TextInput
                style={styles.feedbackTextArea}
                value={feedbackText}
                onChangeText={setFeedbackText}
                placeholder="Tell us what's on your mind..."
                placeholderTextColor={COLORS.textMuted}
                multiline
                numberOfLines={8}
                maxLength={5000}
                textAlignVertical="top"
              />

              <View style={styles.characterCount}>
                <Text style={styles.characterCountText}>
                  {feedbackText.length} / 5000
                </Text>
              </View>

              {/* Image Attachments */}
              {feedbackImages.length > 0 && (
                <View style={styles.imagesContainer}>
                  <Text style={styles.imagesLabel}>Attachments ({feedbackImages.length}/5)</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                    {feedbackImages.map((image, index) => (
                      <View key={index} style={styles.imagePreview}>
                        <Image source={{ uri: image.uri }} style={styles.imagePreviewImage} />
                        <TouchableOpacity
                          style={styles.imageRemoveButton}
                          onPress={() => handleRemoveImage(index)}
                        >
                          <Ionicons name="close-circle" size={24} color={COLORS.danger} />
                        </TouchableOpacity>
                      </View>
                    ))}
                  </ScrollView>
                </View>
              )}

              <TouchableOpacity
                style={styles.addImageButton}
                onPress={handlePickImage}
                disabled={feedbackImages.length >= 5}
              >
                <Ionicons name="image-outline" size={20} color={feedbackImages.length >= 5 ? COLORS.textMuted : COLORS.primary} />
                <Text style={[styles.addImageButtonText, feedbackImages.length >= 5 && styles.addImageButtonTextDisabled]}>
                  {feedbackImages.length >= 5 ? 'Maximum images attached' : 'Attach Screenshot (Optional)'}
                </Text>
              </TouchableOpacity>
            </ScrollView>

            <View style={styles.modalFooter}>
              <TouchableOpacity
                style={[styles.submitFeedbackButton, feedbackSubmitting && styles.submitFeedbackButtonDisabled]}
                onPress={handleSubmitFeedback}
                disabled={feedbackSubmitting || !feedbackText.trim()}
                activeOpacity={0.8}
              >
                {feedbackSubmitting ? (
                  <ActivityIndicator color="#FFFFFF" />
                ) : (
                  <>
                    <Ionicons name="send" size={20} color="#FFFFFF" style={styles.submitIcon} />
                    <Text style={styles.submitFeedbackButtonText}>Submit Feedback</Text>
                  </>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  content: {
    flex: 1,
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.lg,
    paddingBottom: 100,
  },
  title: {
    ...TYPOGRAPHY.heading,
    color: COLORS.text,
    marginBottom: SPACING.xl,
  },
  userInfoCard: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    padding: SPACING.xl,
    alignItems: 'center',
    marginBottom: SPACING.lg,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: COLORS.selectedBackground,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: SPACING.md,
  },
  userName: {
    ...TYPOGRAPHY.subheading,
    color: COLORS.text,
    marginBottom: SPACING.xs,
  },
  userEmail: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
  },
  menuContainer: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 16,
    overflow: 'hidden',
    marginBottom: SPACING.xl,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  menuItemLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.md,
  },
  menuItemLabel: {
    ...TYPOGRAPHY.body,
    color: COLORS.text,
  },
  logoutButton: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    padding: SPACING.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.danger,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  logoutText: {
    ...TYPOGRAPHY.body,
    color: COLORS.danger,
    fontWeight: '600',
  },
  // Feedback button styles
  feedbackButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: COLORS.primary,
    padding: SPACING.md,
    marginBottom: SPACING.md,
    shadowColor: COLORS.primary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 8,
    elevation: 3,
  },
  feedbackIcon: {
    marginRight: SPACING.sm,
  },
  feedbackButtonText: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    fontWeight: '600',
    flex: 1,
  },
  // Feedback modal styles
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: COLORS.background,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: '90%',
    paddingBottom: SPACING.xl,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.lg,
    paddingBottom: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  modalTitle: {
    ...TYPOGRAPHY.heading,
    color: COLORS.text,
    fontWeight: '700',
  },
  modalCloseButton: {
    padding: SPACING.xs,
  },
  modalBody: {
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.md,
  },
  modalDescription: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    marginBottom: SPACING.md,
    lineHeight: 22,
  },
  feedbackTextArea: {
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    padding: SPACING.md,
    ...TYPOGRAPHY.body,
    color: COLORS.text,
    borderWidth: 1,
    borderColor: COLORS.border,
    minHeight: 150,
    maxHeight: 250,
  },
  characterCount: {
    alignItems: 'flex-end',
    marginTop: SPACING.xs,
    marginBottom: SPACING.md,
  },
  characterCountText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.textSecondary,
  },
  imagesContainer: {
    marginBottom: SPACING.md,
  },
  imagesLabel: {
    ...TYPOGRAPHY.body,
    color: COLORS.text,
    fontWeight: '600',
    marginBottom: SPACING.sm,
  },
  imagePreview: {
    position: 'relative',
    marginRight: SPACING.sm,
  },
  imagePreviewImage: {
    width: 100,
    height: 100,
    borderRadius: 8,
    backgroundColor: COLORS.border,
  },
  imageRemoveButton: {
    position: 'absolute',
    top: -8,
    right: -8,
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
  },
  addImageButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.cardBackground,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderStyle: 'dashed',
    padding: SPACING.md,
    marginBottom: SPACING.md,
  },
  addImageButtonText: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    marginLeft: SPACING.sm,
  },
  addImageButtonTextDisabled: {
    color: COLORS.textMuted,
  },
  modalFooter: {
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.md,
  },
  submitFeedbackButton: {
    flexDirection: 'row',
    backgroundColor: COLORS.primary,
    borderRadius: 12,
    padding: SPACING.md,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: COLORS.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 4,
  },
  submitFeedbackButtonDisabled: {
    opacity: 0.5,
  },
  submitFeedbackButtonText: {
    ...TYPOGRAPHY.body,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  submitIcon: {
    marginRight: SPACING.sm,
  },
});
