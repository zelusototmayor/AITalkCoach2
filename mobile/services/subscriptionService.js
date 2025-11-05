/**
 * Subscription Service
 *
 * Handles all Apple In-App Purchase operations via RevenueCat SDK
 */

import Purchases from 'react-native-purchases';
import { Platform } from 'react-native';

// RevenueCat API Key
const REVENUECAT_API_KEY = '7P9X6YCT4U';

// Product IDs from App Store Connect
const PRODUCT_IDS = {
  MONTHLY: '02',
  YEARLY: '03',
};

/**
 * Initialize RevenueCat SDK
 * Call this once when the app starts, before any purchase operations
 */
export async function initializePurchases(userId) {
  try {
    if (Platform.OS === 'ios') {
      await Purchases.configure({ apiKey: REVENUECAT_API_KEY, appUserID: userId });
      console.log('RevenueCat initialized successfully');
      return true;
    } else {
      console.warn('RevenueCat only configured for iOS');
      return false;
    }
  } catch (error) {
    console.error('Error initializing RevenueCat:', error);
    return false;
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
      return packages.map(pkg => ({
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
    const purchaseResult = await Purchases.purchasePackage(packageToPurchase);

    console.log('Purchase successful:', {
      productIdentifier: purchaseResult.productIdentifier,
      customerInfo: purchaseResult.customerInfo,
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
    };
  } catch (error) {
    // User cancelled
    if (error.userCancelled) {
      console.log('User cancelled purchase');
      return {
        success: false,
        cancelled: true,
        error: 'Purchase cancelled',
      };
    }

    console.error('Error purchasing package:', error);
    return {
      success: false,
      cancelled: false,
      error: error.message || 'Purchase failed',
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
