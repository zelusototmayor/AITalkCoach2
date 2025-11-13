/**
 * RevenueCat Configuration
 * Handles environment-specific RevenueCat API keys and settings
 */

import Constants from 'expo-constants';
import { Platform } from 'react-native';

// Detect if we're in TestFlight/App Store Review (production build but sandbox environment)
const isTestFlight = () => {
  // In TestFlight or App Store Review, the receipt URL will be sandbox
  // This is a production build but uses sandbox purchases
  const isProduction = Constants.expoConfig?.extra?.environment === 'production';
  const buildChannel = Constants.expoConfig?.releaseChannel;

  // TestFlight builds have production environment but need sandbox handling
  return isProduction && !__DEV__;
};

// RevenueCat API Keys
// IMPORTANT: Use the same API key for both sandbox and production
// RevenueCat automatically handles sandbox vs production based on the receipt
const REVENUECAT_API_KEYS = {
  // Your production API key from RevenueCat dashboard
  // This key works for both sandbox (TestFlight/Review) and production (App Store)
  ios: process.env.REVENUECAT_IOS_API_KEY || 'appl_oToYWYVjzuIlhTrmhuhvxUXxhRL',
  android: process.env.REVENUECAT_ANDROID_API_KEY || 'YOUR_ANDROID_KEY_HERE',
};

// Product IDs from App Store Connect
export const PRODUCT_IDS = {
  MONTHLY: '02',
  YEARLY: '03',
};

// Get the appropriate API key for the current platform
export const getRevenueCatApiKey = () => {
  const platform = Platform.OS;
  return REVENUECAT_API_KEYS[platform] || REVENUECAT_API_KEYS.ios;
};

// Configuration settings
export const REVENUECAT_CONFIG = {
  // Enable debug logs in development
  debugLogsEnabled: __DEV__,

  // Use Amazon Appstore (set to false for Google Play/App Store)
  useAmazon: false,

  // Automatically check for promotional purchases (iOS 14+)
  shouldShowPromotionalOffers: true,

  // User identification
  appUserIDMode: 'CUSTOM', // We'll use our own user IDs
};

// Error code mapping for better user messages
export const PURCHASE_ERROR_CODES = {
  // RevenueCat error codes
  0: 'Unknown error occurred. Please try again.',
  1: 'Purchase was cancelled.',
  2: 'Unable to find the product. Please check your internet connection.',
  3: 'This product is not available for purchase.',
  4: 'This product is already active on your account.',
  5: 'This product is not available in your region.',
  6: 'Invalid receipt. Please contact support.',
  7: 'Network error. Please check your internet connection.',
  8: 'This device is not allowed to make purchases.',
  9: 'You are not allowed to make purchases.',
  10: 'Invalid App Store credentials.',
  11: 'Unexpected backend response. Please try again.',
  12: 'Receipt is already in use by another account.',
  13: 'Invalid product identifier.',
  14: 'Payment pending. Please check back later.',
  15: 'Store problem. Please try again later.',
  16: 'Configuration error. Please contact support.',
  17: 'Unsupported error. Please update the app.',
  18: 'Empty receipt. Please restore purchases.',
  19: 'Customer info error. Please try again.',
  20: 'API key error. Please contact support.',
  21: 'Offline connection error. Please check your internet.',
  22: 'Feature not available.',
  23: 'Signature verification failed.',
  24: 'Invalid purchase. Please contact support.',

  // StoreKit error codes (negative values)
  '-1005': 'Network connection lost. Please try again.',
  '-1009': 'No internet connection. Please check your connection.',
  '-1001': 'Request timed out. Please try again.',

  // Custom error codes
  'OFFERINGS_EMPTY': 'No subscription plans available. Please try again later.',
  'INIT_FAILED': 'Failed to initialize purchases. Please restart the app.',
};

// Helper to get user-friendly error message
export const getErrorMessage = (error) => {
  // Check for specific error properties
  if (error.userCancelled) {
    return 'Purchase cancelled.';
  }

  // Check RevenueCat error code
  if (error.code && PURCHASE_ERROR_CODES[error.code]) {
    return PURCHASE_ERROR_CODES[error.code];
  }

  // Check for network error codes
  if (error.code && error.code < 0 && PURCHASE_ERROR_CODES[error.code.toString()]) {
    return PURCHASE_ERROR_CODES[error.code.toString()];
  }

  // Check for custom error messages
  if (error.message) {
    // Don't expose technical details to users
    if (error.message.includes('network') || error.message.includes('Network')) {
      return 'Network error. Please check your internet connection.';
    }
    if (error.message.includes('receipt') || error.message.includes('Receipt')) {
      return 'Purchase verification failed. Please try again or restore purchases.';
    }
    if (error.message.includes('sandbox') || error.message.includes('Sandbox')) {
      return 'Purchase environment error. Please contact support.';
    }
  }

  // Default error message
  return error.message || 'An unexpected error occurred. Please try again.';
};

// Helper to check if error is recoverable
export const isRecoverableError = (error) => {
  const recoverableErrors = [7, 11, 15, 21, '-1005', '-1009', '-1001'];
  return recoverableErrors.includes(error.code?.toString());
};

export default {
  getRevenueCatApiKey,
  PRODUCT_IDS,
  REVENUECAT_CONFIG,
  PURCHASE_ERROR_CODES,
  getErrorMessage,
  isRecoverableError,
  isTestFlight,
};