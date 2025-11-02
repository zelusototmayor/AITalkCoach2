// Authentication Service
// Handles all authentication API calls

const API_BASE_URL = __DEV__
  ? 'http://192.168.100.38:3002' // Local IP for development
  : 'https://app.aitalkcoach.com'; // Production URL

/**
 * Login with email and password
 * @param {string} email
 * @param {string} password
 * @returns {Promise<Object>} Response with user, token, and refresh_token
 */
export async function login(email, password) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/auth/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({ email, password }),
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Login failed');
    }

    return data;
  } catch (error) {
    console.error('Login API error:', error);
    throw error;
  }
}

/**
 * Sign up new user
 * @param {string} name
 * @param {string} email
 * @param {string} password
 * @param {string} passwordConfirmation
 * @returns {Promise<Object>} Response with user, token, and refresh_token
 */
export async function signup(name, email, password, passwordConfirmation) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/auth/signup`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        name,
        email,
        password,
        password_confirmation: passwordConfirmation,
      }),
    });

    const data = await response.json();

    // If response has success field, return it regardless of HTTP status
    // This allows proper error handling in AuthContext
    if (data.hasOwnProperty('success')) {
      return data;
    }

    // Only throw if unexpected error format
    if (!response.ok) {
      throw new Error('Signup failed');
    }

    return data;
  } catch (error) {
    console.error('Signup API error:', error);
    throw error;
  }
}

/**
 * Get current user with token
 * @param {string} token
 * @returns {Promise<Object>} User object
 */
export async function getCurrentUser(token) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/auth/me`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/json',
      },
    });

    if (!response.ok) {
      return null;
    }

    const data = await response.json();
    return data.user;
  } catch (error) {
    console.error('Get current user error:', error);
    return null;
  }
}

/**
 * Refresh access token
 * @param {string} refreshToken
 * @returns {Promise<Object>} Response with new token and user
 */
export async function refreshToken(refreshToken) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/auth/refresh`, {
      method: 'POST',
      headers: {
        'X-Refresh-Token': refreshToken,
        'Accept': 'application/json',
      },
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Token refresh failed');
    }

    return data;
  } catch (error) {
    console.error('Refresh token error:', error);
    throw error;
  }
}

/**
 * Logout (optional - JWT is stateless)
 * @param {string} token
 * @returns {Promise<Object>} Response
 */
export async function logout(token) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/auth/logout`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/json',
      },
    });

    return await response.json();
  } catch (error) {
    console.error('Logout API error:', error);
    // Don't throw - logout should succeed locally even if API fails
    return { success: true };
  }
}

/**
 * Request password reset email
 * @param {string} email
 * @returns {Promise<Object>} Response
 */
export async function forgotPassword(email) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/auth/forgot_password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({ email }),
    });

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Forgot password error:', error);
    throw error;
  }
}

/**
 * Reset password with token
 * @param {string} token
 * @param {string} password
 * @returns {Promise<Object>} Response
 */
export async function resetPassword(token, password) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/auth/reset_password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({ token, password }),
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Password reset failed');
    }

    return data;
  } catch (error) {
    console.error('Reset password error:', error);
    throw error;
  }
}

/**
 * Mark onboarding as complete
 * @param {string} token - Auth token
 * @returns {Promise<Object>} Response with updated user
 */
export async function completeOnboarding(token) {
  try {
    const response = await fetch(`${API_BASE_URL}/onboarding/complete`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Failed to complete onboarding');
    }

    return { success: true, user: data.user };
  } catch (error) {
    console.error('Complete onboarding error:', error);
    throw error;
  }
}