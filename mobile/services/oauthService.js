// OAuth Service
// Handles Google and Apple authentication flows

import { Platform } from 'react-native';
import * as AppleAuthentication from 'expo-apple-authentication';

const API_BASE_URL = __DEV__
  ? 'http://192.168.100.47:3002'
  : 'https://app.aitalkcoach.com';

// Dynamically import Google Sign-In to avoid crash in Expo Go
let GoogleSignin = null;
let statusCodes = null;
let googleSignInAvailable = false;

try {
  const googleModule = require('@react-native-google-signin/google-signin');
  GoogleSignin = googleModule.GoogleSignin;
  statusCodes = googleModule.statusCodes;
  googleSignInAvailable = true;
} catch (e) {
  console.log('Google Sign-In native module not available (expected in Expo Go)');
}

// Configure Google Sign-In
// Note: You need to set the webClientId and iosClientId from Google Cloud Console
export function configureGoogleSignIn() {
  if (!googleSignInAvailable || !GoogleSignin) {
    console.log('Google Sign-In not available - skipping configuration');
    return;
  }

  GoogleSignin.configure({
    // Get from Google Cloud Console -> Credentials -> OAuth 2.0 Client IDs
    webClientId: process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID || '204728762120-fck6u9oqfj97mosoai568ova6fkp2fic.apps.googleusercontent.com',
    iosClientId: process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID || '204728762120-4rs348t5dqaf6o3utqarsjg4gd7nadf6.apps.googleusercontent.com',
    offlineAccess: false,
  });
}

/**
 * Check if Google Sign-In is available
 * @returns {boolean}
 */
export function isGoogleSignInAvailable() {
  return googleSignInAvailable;
}

/**
 * Sign in with Google
 * @returns {Promise<Object>} Response with user, token, refresh_token
 */
export async function signInWithGoogle() {
  if (!googleSignInAvailable || !GoogleSignin) {
    throw new Error('Google Sign-In is not available. Please use a development build.');
  }

  try {
    // Check if Google Play Services are available (Android)
    await GoogleSignin.hasPlayServices();

    // Trigger the sign-in flow
    const response = await GoogleSignin.signIn();

    if (!response.data?.idToken) {
      throw new Error('No ID token received from Google');
    }

    // Send the ID token to our backend for verification
    const backendResponse = await sendGoogleTokenToBackend(
      response.data.idToken,
      response.data.user?.name
    );

    return backendResponse;
  } catch (error) {
    if (statusCodes && error.code === statusCodes.SIGN_IN_CANCELLED) {
      throw new Error('Google sign-in was cancelled');
    } else if (statusCodes && error.code === statusCodes.IN_PROGRESS) {
      throw new Error('Google sign-in already in progress');
    } else if (statusCodes && error.code === statusCodes.PLAY_SERVICES_NOT_AVAILABLE) {
      throw new Error('Google Play Services not available');
    }
    console.error('Google sign-in error:', error);
    throw error;
  }
}

/**
 * Send Google ID token to backend for verification
 * @param {string} idToken - Google ID token
 * @param {string} name - User's name from Google
 * @returns {Promise<Object>} Backend response with user and JWT tokens
 */
async function sendGoogleTokenToBackend(idToken, name) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/auth/google`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        id_token: idToken,
        name: name,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Google authentication failed');
    }

    return data;
  } catch (error) {
    console.error('Google backend auth error:', error);
    throw error;
  }
}

/**
 * Check if Apple Sign In is available
 * @returns {Promise<boolean>}
 */
export async function isAppleSignInAvailable() {
  if (Platform.OS !== 'ios') {
    return false;
  }
  return await AppleAuthentication.isAvailableAsync();
}

/**
 * Sign in with Apple
 * @returns {Promise<Object>} Response with user, token, refresh_token
 */
export async function signInWithApple() {
  try {
    const credential = await AppleAuthentication.signInAsync({
      requestedScopes: [
        AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
        AppleAuthentication.AppleAuthenticationScope.EMAIL,
      ],
    });

    if (!credential.identityToken) {
      throw new Error('No identity token received from Apple');
    }

    // Apple only provides user info on first authorization
    // We need to pass it along to the backend
    const userData = {
      email: credential.email,
      name: credential.fullName
        ? [credential.fullName.givenName, credential.fullName.familyName]
            .filter(Boolean)
            .join(' ')
        : null,
    };

    // Send the identity token to our backend for verification
    const backendResponse = await sendAppleTokenToBackend(
      credential.identityToken,
      userData
    );

    return backendResponse;
  } catch (error) {
    if (error.code === 'ERR_REQUEST_CANCELED') {
      throw new Error('Apple sign-in was cancelled');
    }
    console.error('Apple sign-in error:', error);
    throw error;
  }
}

/**
 * Send Apple identity token to backend for verification
 * @param {string} identityToken - Apple identity token
 * @param {Object} userData - User data from Apple (name, email)
 * @returns {Promise<Object>} Backend response with user and JWT tokens
 */
async function sendAppleTokenToBackend(identityToken, userData) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/auth/apple`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        id_token: identityToken,
        user: userData,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Apple authentication failed');
    }

    return data;
  } catch (error) {
    console.error('Apple backend auth error:', error);
    throw error;
  }
}

/**
 * Sign out from Google (clears cached credentials)
 */
export async function signOutGoogle() {
  if (!googleSignInAvailable || !GoogleSignin) {
    return;
  }

  try {
    await GoogleSignin.signOut();
  } catch (error) {
    console.error('Google sign-out error:', error);
  }
}
