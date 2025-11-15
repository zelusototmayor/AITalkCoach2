/**
 * Subscription Service
 *
 * Handles all Apple In-App Purchase operations via RevenueCat SDK
 */

import Purchases from 'react-native-purchases';
import { Platform } from 'react-native';
import {
  getRevenueCatApiKey,
  PRODUCT_IDS,
  REVENUECAT_CONFIG,
  getErrorMessage,
  isRecoverableError,
  isTestFlight,
} from '../config/revenueCat';

/**
 * Initialize RevenueCat SDK
 * Call this once when the app starts, before any purchase operations
 */
export async function initializePurchases(userId) {
  try {
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      const apiKey = getRevenueCatApiKey();

      // Enable debug logs in development
      if (__DEV__) {
        Purchases.setDebugLogsEnabled(true);
        console.log('🔧 RevenueCat Debug Mode: ON');
        console.log('🔑 Using API Key:', apiKey.substring(0, 4) + '...');
        console.log('👤 User ID:', userId);
        console.log('🏗️ TestFlight Mode:', isTestFlight());
      }

      // Configure RevenueCat
      await Purchases.configure({
        apiKey,
        appUserID: userId,
        observerMode: false, // Set to false to let RevenueCat handle purchases
        useAmazon: REVENUECAT_CONFIG.useAmazon,
      });

      console.log('✅ RevenueCat initialized successfully');

      // Log customer info for debugging
      if (__DEV__) {
        try {
          const customerInfo = await Purchases.getCustomerInfo();
          console.log('📱 Customer Info:', {
            userId: customerInfo.originalAppUserId,
            activeEntitlements: Object.keys(customerInfo.entitlements.active),
            managementURL: customerInfo.managementURL,
          });
        } catch (debugError) {
          console.log('📱 Could not fetch initial customer info:', debugError.message);
        }
      }

      return true;
    } else {
      console.warn('⚠️ RevenueCat not configured for this platform:', Platform.OS);
      return false;
    }
  } catch (error) {
    console.error('❌ Error initializing RevenueCat:', {
      message: error.message,
      code: error.code,
      userInfo: error.userInfo,
    });
    return false;
  }
}

/**
 * Validate RevenueCat configuration
 * Helps diagnose configuration issues
 */
export async function validateRevenueCatConfig() {
  const diagnostics = {
    initialized: false,
    hasOfferings: false,
    offeringsCount: 0,
    currentOffering: null,
    products: [],
    environment: __DEV__ ? 'development' : 'production',
    isTestFlight: isTestFlight(),
    errors: [],
  };

  try {
    // Check if RevenueCat is initialized
    const customerInfo = await Purchases.getCustomerInfo();
    diagnostics.initialized = true;
    diagnostics.customerId = customerInfo.originalAppUserId;

    // Check offerings
    const offerings = await Purchases.getOfferings();
    diagnostics.hasOfferings = offerings.current !== null;
    diagnostics.offeringsCount = offerings.current?.availablePackages?.length || 0;

    if (offerings.current) {
      diagnostics.currentOffering = offerings.current.identifier;
      diagnostics.products = offerings.current.availablePackages.map(pkg => ({
        id: pkg.product.identifier,
        price: pkg.product.priceString,
        type: pkg.packageType,
      }));
    }

    // Check product IDs match expected values
    const expectedProductIds = Object.values(PRODUCT_IDS);
    const actualProductIds = diagnostics.products.map(p => p.id);
    const missingProducts = expectedProductIds.filter(id => !actualProductIds.includes(id));

    if (missingProducts.length > 0) {
      diagnostics.errors.push(`Missing products: ${missingProducts.join(', ')}`);
    }

    console.log('📊 RevenueCat Diagnostics:', diagnostics);
    return diagnostics;
  } catch (error) {
    diagnostics.errors.push(error.message);
    console.error('❌ RevenueCat validation failed:', diagnostics);
    return diagnostics;
  }
}

/**
 * Get available subscription offerings from RevenueCat
 * Returns packages with pricing and product details
 */
export async function getOfferings() {
  try {
    console.log('🔍 Fetching offerings from RevenueCat...');
    const offerings = await Purchases.getOfferings();

    console.log('📦 Raw offerings response:', {
      current: offerings.current,
      all: Object.keys(offerings.all),
      hasCurrentOffering: offerings.current !== null,
      currentOfferingPackageCount: offerings.current?.availablePackages?.length || 0,
    });

    if (offerings.current !== null && offerings.current.availablePackages.length !== 0) {
      const packages = offerings.current.availablePackages;

      console.log('✅ Found packages:', packages.map(pkg => ({
        identifier: pkg.identifier,
        productId: pkg.product.identifier,
        price: pkg.product.priceString,
      })));

      // Map packages to a simpler format
      // IMPORTANT: Keep the original package object for purchasing
      return packages.map(pkg => ({
        // Original package object (needed for Purchases.purchasePackage())
        rcPackage: pkg,
        // Package metadata
        identifier: pkg.identifier,
        product: pkg.product,
        packageType: pkg.packageType,
        // Product details
        productId: pkg.product.identifier,
        title: pkg.product.title,
        description: pkg.product.description,
        price: pkg.product.priceString,
        priceValue: pkg.product.price,
        currency: pkg.product.currencyCode,
        // Subscription period
        introPrice: pkg.product.introPrice,
        subscriptionPeriod: pkg.product.subscriptionPeriod,
      }));
    }

    console.warn('⚠️ No offerings available from RevenueCat. Check dashboard configuration.');
    console.warn('All offerings:', offerings.all);
    return [];
  } catch (error) {
    console.error('❌ Error fetching offerings:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      stack: error.stack,
    });
    return [];
  }
}

/**
 * Purchase a subscription package
 * Handles the complete purchase flow
 */
export async function purchasePackage(packageToPurchase) {
  try {
    console.log('🛒 Starting purchase for package:', {
      identifier: packageToPurchase.identifier,
      productId: packageToPurchase.product?.identifier,
      price: packageToPurchase.product?.priceString,
    });

    const purchaseResult = await Purchases.purchasePackage(packageToPurchase);

    console.log('✅ Purchase successful:', {
      productIdentifier: purchaseResult.productIdentifier,
      transactionId: purchaseResult.transaction?.transactionIdentifier,
      customerInfo: {
        userId: purchaseResult.customerInfo.originalAppUserId,
        activeEntitlements: Object.keys(purchaseResult.customerInfo.entitlements.active),
      },
    });

    // Check if user now has active entitlement
    const hasActiveSubscription = Object.keys(
      purchaseResult.customerInfo.entitlements.active
    ).length > 0;

    return {
      success: true,
      customerInfo: purchaseResult.customerInfo,
      hasActiveSubscription,
      productIdentifier: purchaseResult.productIdentifier,
      transactionId: purchaseResult.transaction?.transactionIdentifier,
    };
  } catch (error) {
    // Log detailed error information
    console.error('❌ Purchase error details:', {
      code: error.code,
      message: error.message,
      userCancelled: error.userCancelled,
      underlyingErrorMessage: error.underlyingErrorMessage,
      readableErrorCode: error.readableErrorCode,
      userInfo: error.userInfo,
    });

    // User cancelled
    if (error.userCancelled) {
      console.log('🚫 User cancelled purchase');
      return {
        success: false,
        cancelled: true,
        error: 'Purchase cancelled',
        errorCode: error.code,
      };
    }

    // Get user-friendly error message
    const userMessage = getErrorMessage(error);
    const isRecoverable = isRecoverableError(error);

    console.error('❌ Purchase failed:', {
      userMessage,
      isRecoverable,
      originalError: error.message,
    });

    return {
      success: false,
      cancelled: false,
      error: userMessage,
      errorCode: error.code,
      isRecoverable,
      technicalDetails: __DEV__ ? {
        code: error.code,
        message: error.message,
        underlyingError: error.underlyingErrorMessage,
      } : undefined,
    };
  }
}

/**
 * Restore previous purchases
 * Useful for users who reinstalled the app or switched devices
 */
export async function restorePurchases() {
  try {
    const customerInfo = await Purchases.restorePurchases();

    const hasActiveSubscription = Object.keys(
      customerInfo.entitlements.active
    ).length > 0;

    console.log('Purchases restored:', {
      hasActiveSubscription,
      activeEntitlements: Object.keys(customerInfo.entitlements.active),
    });

    return {
      success: true,
      customerInfo,
      hasActiveSubscription,
    };
  } catch (error) {
    console.error('Error restoring purchases:', error);
    return {
      success: false,
      error: error.message || 'Failed to restore purchases',
    };
  }
}

/**
 * Get current customer information
 * Includes active subscriptions and entitlements
 */
export async function getCustomerInfo() {
  try {
    const customerInfo = await Purchases.getCustomerInfo();

    const hasActiveSubscription = Object.keys(
      customerInfo.entitlements.active
    ).length > 0;

    const activeSubscriptions = Object.keys(customerInfo.entitlements.active);

    return {
      success: true,
      customerInfo,
      hasActiveSubscription,
      activeSubscriptions,
      originalAppUserId: customerInfo.originalAppUserId,
    };
  } catch (error) {
    // If RevenueCat hasn't been initialized yet, return default state
    if (error.message && error.message.includes('singleton')) {
      console.log('RevenueCat not initialized yet');
      return {
        success: false,
        hasActiveSubscription: false,
        activeSubscriptions: [],
        error: 'Not initialized',
      };
    }

    console.error('Error getting customer info:', error);
    return {
      success: false,
      error: error.message || 'Failed to get customer info',
    };
  }
}

/**
 * Check if user has an active subscription
 * Returns boolean and details about the subscription
 */
export async function checkSubscriptionStatus() {
  try {
    const customerInfo = await Purchases.getCustomerInfo();

    const hasActiveSubscription = Object.keys(
      customerInfo.entitlements.active
    ).length > 0;

    if (hasActiveSubscription) {
      const activeEntitlements = customerInfo.entitlements.active;
      const firstEntitlement = Object.values(activeEntitlements)[0];

      return {
        isActive: true,
        expirationDate: firstEntitlement.expirationDate,
        productIdentifier: firstEntitlement.productIdentifier,
        willRenew: firstEntitlement.willRenew,
        periodType: firstEntitlement.periodType,
      };
    }

    return {
      isActive: false,
    };
  } catch (error) {
    // If RevenueCat hasn't been initialized yet, assume no active subscription
    if (error.message && error.message.includes('singleton')) {
      console.log('RevenueCat not initialized yet, assuming no subscription');
      return {
        isActive: false,
      };
    }

    console.error('Error checking subscription status:', error);
    return {
      isActive: false,
      error: error.message,
    };
  }
}

/**
 * Identify user with RevenueCat
 * Links purchases to specific user account
 */
export async function identifyUser(userId) {
  try {
    await Purchases.logIn(userId);
    console.log('User identified with RevenueCat:', userId);
    return true;
  } catch (error) {
    console.error('Error identifying user:', error);
    return false;
  }
}

/**
 * Log out current user from RevenueCat
 * Call this when user logs out of your app
 */
export async function logoutUser() {
  try {
    await Purchases.logOut();
    console.log('User logged out from RevenueCat');
    return true;
  } catch (error) {
    // If RevenueCat hasn't been initialized yet, there's nothing to log out from
    // This can happen if user logs out before ever reaching the paywall
    if (error.message && error.message.includes('singleton')) {
      console.log('RevenueCat not initialized, skipping logout');
      return true;
    }

    console.error('Error logging out user:', error);
    return false;
  }
}

export default {
  initializePurchases,
  getOfferings,
  purchasePackage,
  restorePurchases,
  getCustomerInfo,
  checkSubscriptionStatus,
  identifyUser,
  logoutUser,
  PRODUCT_IDS,
};
