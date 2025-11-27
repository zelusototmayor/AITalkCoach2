// API Service for AI Talk Coach Mobile App
// Connects to Rails backend for session management

import * as SecureStore from 'expo-secure-store';

// TODO: Replace with your actual backend URL
// For development: use your local IP or ngrok URL
// For production: use your production domain
const API_BASE_URL = __DEV__
  ? 'http://192.168.100.42:3002' // Local IP for development (iOS simulator needs actual IP)
  : 'https://app.aitalkcoach.com';

/**
 * Get the stored access token
 * @returns {Promise<string|null>} Access token or null
 */
async function getAccessToken() {
  try {
    return await SecureStore.getItemAsync('access_token');
  } catch (error) {
    console.error('Error getting access token:', error);
    return null;
  }
}

/**
 * Get headers with authentication
 * @returns {Promise<Object>} Headers object with authorization
 */
async function getAuthHeaders() {
  const token = await getAccessToken();
  const headers = {
    'Accept': 'application/json',
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  return headers;
}

/**
 * Upload audio file and create a new session
 * @param {Object} audioFile - Audio file object with uri, name, type
 * @param {Object} options - Additional session options (title, target_seconds, etc.)
 * @returns {Promise<Object>} Session object with id
 */
export async function createSession(audioFile, options = {}) {
  const formData = new FormData();

  // Add audio file (using media_files[] array format for ActiveStorage)
  formData.append('session[media_files][]', {
    uri: audioFile.uri,
    name: audioFile.name || 'recording.m4a',
    type: audioFile.type || 'audio/m4a',
  });

  // Add required options
  formData.append('session[media_kind]', options.media_kind || 'audio');
  formData.append('session[language]', options.language || 'en');

  // Add optional parameters
  if (options.title) {
    formData.append('session[title]', options.title);
  }

  if (options.target_seconds) {
    formData.append('session[target_seconds]', options.target_seconds);
  }

  if (options.weekly_focus_id) {
    formData.append('session[weekly_focus_id]', options.weekly_focus_id);
  }

  if (options.speech_context) {
    formData.append('session[speech_context]', options.speech_context);
  }

  if (options.retake_count !== undefined) {
    formData.append('session[retake_count]', options.retake_count);
  }

  if (options.is_retake !== undefined) {
    formData.append('session[is_retake]', options.is_retake);
  }

  if (options.prompt_identifier) {
    formData.append('session[prompt_identifier]', options.prompt_identifier);
  }

  if (options.prompt_text) {
    formData.append('session[prompt_text]', options.prompt_text);
  }

  try {
    const headers = await getAuthHeaders();
    // Don't set Content-Type for FormData - let browser set it with boundary

    const response = await fetch(`${API_BASE_URL}/api/v1/sessions`, {
      method: 'POST',
      headers: headers,
      body: formData,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || errorData.errors?.join(', ') || `HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error creating session:', error);
    throw error;
  }
}

/**
 * Poll session status until processing is complete
 * @param {number} sessionId - Session ID
 * @param {function} onProgress - Callback for progress updates (progress_percent, processing_state)
 * @param {number} pollInterval - Polling interval in milliseconds (default 1500)
 * @returns {Promise<Object>} Complete session data
 */
export async function pollSessionStatus(sessionId, onProgress = null, pollInterval = 1500) {
  return new Promise((resolve, reject) => {
    const poll = async () => {
      try {
        const headers = await getAuthHeaders();
        const response = await fetch(`${API_BASE_URL}/api/v1/sessions/${sessionId}/status`, {
          headers: {
            ...headers,
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        });

        if (!response.ok) {
          clearInterval(intervalId);
          reject(new Error(`HTTP error! status: ${response.status}`));
          return;
        }

        const data = await response.json();

        // Call progress callback if provided
        if (onProgress) {
          onProgress({
            progress_percent: data.progress_percent || 0,
            processing_state: data.processing_state,
          });
        }

        // Check if processing is complete
        if (data.processing_state === 'completed') {
          clearInterval(intervalId);
          resolve(data);
        } else if (data.processing_state === 'failed') {
          clearInterval(intervalId);
          reject(new Error('Session processing failed'));
        }
      } catch (error) {
        clearInterval(intervalId);
        reject(error);
      }
    };

    // Start polling
    const intervalId = setInterval(poll, pollInterval);

    // Do first poll immediately
    poll();
  });
}

/**
 * Get full session report data
 * @param {number} sessionId - Session ID
 * @returns {Promise<Object>} Session with analysis_json, issues, etc.
 */
export async function getSessionReport(sessionId) {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/v1/sessions/${sessionId}`, {
      headers: headers,
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching session report:', error);
    throw error;
  }
}

// =============================================================================
// TRIAL SESSION FUNCTIONS (for onboarding)
// =============================================================================

/**
 * Upload audio file and create a new trial session (for onboarding)
 * @param {Object} audioFile - Audio file object with uri, name, type
 * @param {Object} options - Additional options (language, etc.)
 * @returns {Promise<Object>} Response with trial_token
 */
export async function createTrialSession(audioFile, options = {}) {
  const formData = new FormData();

  // Add audio file
  formData.append('audio_file', {
    uri: audioFile.uri,
    name: audioFile.name || 'recording.m4a',
    type: audioFile.type || 'audio/m4a',
  });

  // Mark as trial recording
  formData.append('trial_recording', 'true');

  // Add optional parameters
  if (options.language) {
    formData.append('language', options.language);
  }

  if (options.media_kind) {
    formData.append('media_kind', options.media_kind);
  }

  if (options.target_seconds) {
    formData.append('target_seconds', options.target_seconds);
  }

  try {
    const headers = await getAuthHeaders();

    const response = await fetch(`${API_BASE_URL}/api/trial_sessions`, {
      method: 'POST',
      headers: headers,
      body: formData,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || errorData.errors?.join(', ') || `HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data; // Should contain { trial_token: "..." }
  } catch (error) {
    console.error('Error creating trial session:', error);
    throw error;
  }
}

/**
 * Poll trial session status until processing is complete
 * @param {string} trialToken - Trial session token
 * @param {function} onProgress - Callback for progress updates
 * @param {number} pollInterval - Polling interval in milliseconds (default 1500)
 * @returns {Promise<Object>} Complete trial session status
 */
export async function pollTrialSessionStatus(trialToken, onProgress = null, pollInterval = 1500) {
  return new Promise((resolve, reject) => {
    const poll = async () => {
      try {
        const response = await fetch(`${API_BASE_URL}/api/trial_sessions/${trialToken}/status`, {
          headers: {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        });

        if (!response.ok) {
          clearInterval(intervalId);
          reject(new Error(`HTTP error! status: ${response.status}`));
          return;
        }

        const data = await response.json();

        // Call progress callback if provided
        if (onProgress) {
          onProgress({
            progress: data.progress_info?.progress || 0,
            step: data.progress_info?.step || 'Processing...',
            processing_state: data.processing_state,
          });
        }

        // Check if processing is complete (ready for display)
        if (data.completed) {
          clearInterval(intervalId);
          resolve(data);
        } else if (data.processing_state === 'failed') {
          clearInterval(intervalId);
          reject(new Error(data.incomplete_reason || 'Trial session processing failed'));
        }
      } catch (error) {
        clearInterval(intervalId);
        reject(error);
      }
    };

    // Start polling
    const intervalId = setInterval(poll, pollInterval);

    // Do first poll immediately
    poll();
  });
}

/**
 * Get full trial session results
 * @param {string} trialToken - Trial session token
 * @returns {Promise<Object>} Trial session with metrics, transcript, etc.
 */
export async function getTrialSessionResults(trialToken) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/trial_sessions/${trialToken}`, {
      headers: {
        'Accept': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data.trial_session; // Returns the trial_session object
  } catch (error) {
    console.error('Error fetching trial session results:', error);
    throw error;
  }
}

/**
 * Get coach recommendations for user
 * @returns {Promise<Object>} Coach recommendation data with focus areas
 */
export async function getCoachRecommendations() {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/v1/coach`, {
      headers: headers,
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching coach recommendations:', error);
    throw error;
  }
}

/**
 * Get user's current weekly focus
 * @returns {Promise<Object|null>} Current weekly focus or null
 */
export async function getCurrentWeeklyFocus() {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/v1/weekly_focuses/current`, {
      headers: headers,
    });

    if (response.status === 404) {
      return null; // No active weekly focus
    }

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching weekly focus:', error);
    throw error;
  }
}

/**
 * Get list of user's sessions
 * @param {Object} options - Query options (limit, offset, etc.)
 * @returns {Promise<Array>} Array of session objects
 */
export async function getSessions(options = {}) {
  const params = new URLSearchParams(options);

  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/v1/sessions?${params}`, {
      headers: headers,
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data.sessions || [];
  } catch (error) {
    console.error('Error fetching sessions:', error);
    throw error;
  }
}

/**
 * Get progress metrics over time
 * @param {string} timeRange - Time range ('7', '30', 'lifetime')
 * @returns {Promise<Object>} Progress data with metrics over time
 */
export async function getProgressMetrics(timeRange = '7') {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/v1/progress?range=${timeRange}`, {
      headers: headers,
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching progress metrics:', error);
    throw error;
  }
}

/**
 * Get list of practice prompts
 * @returns {Promise<Object>} Prompts data with categories
 */
export async function getPrompts() {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/v1/prompts`, {
      headers: headers,
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching prompts:', error);
    throw error;
  }
}

/**
 * Helper function to get processing stage info
 * @param {number} progressPercent - Progress percentage (0-100)
 * @returns {Object} Stage info with name and description
 */
export function getProcessingStage(progressPercent) {
  if (progressPercent <= 15) {
    return {
      stage: 1,
      name: 'Media Extraction',
      description: 'Extracting audio from your recording...',
    };
  } else if (progressPercent <= 35) {
    return {
      stage: 2,
      name: 'Transcription',
      description: 'Converting speech to text...',
    };
  } else if (progressPercent <= 60) {
    return {
      stage: 3,
      name: 'Rule Analysis',
      description: 'Detecting filler words and pauses...',
    };
  } else if (progressPercent <= 80) {
    return {
      stage: 4,
      name: 'AI Refinement',
      description: 'Analyzing with AI for deeper insights...',
    };
  } else if (progressPercent < 100) {
    return {
      stage: 5,
      name: 'Metrics Calculation',
      description: 'Calculating your scores...',
    };
  } else {
    return {
      stage: 6,
      name: 'Complete',
      description: 'Your report is ready!',
    };
  }
}

/**
 * Update user's preferred language
 * @param {string} languageCode - ISO language code (e.g., 'en', 'pt', 'es')
 * @returns {Promise<Object>} Updated user object
 */
export async function updateLanguage(languageCode) {
  try {
    const headers = await getAuthHeaders();

    const response = await fetch(`${API_BASE_URL}/api/v1/auth/update_language`, {
      method: 'PATCH',
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ language: languageCode }),
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Failed to update language');
    }

    return data;
  } catch (error) {
    console.error('Error updating language:', error);
    throw error;
  }
}

/**
 * Update user's target speaking pace (WPM)
 * @param {number|null} targetWpm - Target words per minute (60-240), or null to reset to default
 * @returns {Promise<Object>} Updated user object with WPM settings
 */
export async function updateTargetWPM(targetWpm) {
  try {
    const headers = await getAuthHeaders();

    const response = await fetch(`${API_BASE_URL}/api/v1/auth/update_target_wpm`, {
      method: 'PATCH',
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ target_wpm: targetWpm }),
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Failed to update target WPM');
    }

    return data;
  } catch (error) {
    console.error('Error updating target WPM:', error);
    throw error;
  }
}

/**
 * Initiate a retake for a session that failed relevance check
 * @param {string} sessionId - Session ID to retake
 * @returns {Promise<Object>} Session information for retake
 */
export async function retakeSession(sessionId) {
  try {
    const headers = await getAuthHeaders();

    const response = await fetch(`${API_BASE_URL}/api/v1/sessions/${sessionId}/retake`, {
      method: 'POST',
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Failed to initiate retake');
    }

    return data;
  } catch (error) {
    console.error('Error initiating retake:', error);
    throw error;
  }
}

/**
 * Continue with analysis for a session that failed relevance check
 * @param {string} sessionId - Session ID to continue
 * @returns {Promise<Object>} Session information
 */
export async function continueSession(sessionId) {
  try {
    const headers = await getAuthHeaders();

    const response = await fetch(`${API_BASE_URL}/api/v1/sessions/${sessionId}/continue_anyway`, {
      method: 'POST',
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Failed to continue session');
    }

    return data;
  } catch (error) {
    console.error('Error continuing session:', error);
    throw error;
  }
}

/**
 * Get daily recommended prompt based on user's weekly focus
 * @returns {Promise<Object>} Prompt object with text, category, difficulty, duration, identifier
 */
export async function getDailyPrompt() {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/v1/prompts/daily`, {
      method: 'GET',
      headers,
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Failed to fetch daily prompt');
    }

    return data.prompt;
  } catch (error) {
    console.error('Error fetching daily prompt:', error);
    // Fallback prompt if API fails
    return {
      identifier: 'fallback_default',
      text: 'What did you enjoy most about last week and why?',
      category: 'Reflection',
      difficulty: 'intermediate',
      duration: 60
    };
  }
}

/**
 * Get a random shuffled prompt
 * @returns {Promise<Object>} Prompt object with text, category, difficulty, duration, identifier
 */
export async function shufflePrompt() {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/v1/prompts/shuffle`, {
      method: 'GET',
      headers,
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Failed to shuffle prompt');
    }

    return data.prompt;
  } catch (error) {
    console.error('Error shuffling prompt:', error);
    throw error;
  }
}

/**
 * Mark a prompt as completed
 * @param {string} promptIdentifier - The unique identifier for the prompt
 * @param {number} sessionId - The ID of the session where it was completed (optional)
 * @returns {Promise<Object>} Success response
 */
export async function markPromptCompleted(promptIdentifier, sessionId = null) {
  try {
    const headers = await getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    const response = await fetch(`${API_BASE_URL}/api/v1/prompts/complete`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        prompt_identifier: promptIdentifier,
        session_id: sessionId
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || 'Failed to mark prompt as completed');
    }

    return data;
  } catch (error) {
    console.error('Error marking prompt as completed:', error);
    throw error;
  }
}

/**
 * Submit feedback with optional images
 * @param {string} feedbackText - Feedback text (max 5000 characters)
 * @param {Array} images - Array of image objects with uri, name, type (max 5 images)
 * @returns {Promise<Object>} Success response
 */
export async function submitFeedback(feedbackText, images = []) {
  try {
    const formData = new FormData();

    // Add feedback text
    formData.append('feedback_text', feedbackText);

    // Add images if provided (max 5)
    if (images && images.length > 0) {
      images.slice(0, 5).forEach((image, index) => {
        formData.append('images[]', {
          uri: image.uri,
          name: image.name || `image_${index}.jpg`,
          type: image.type || 'image/jpeg',
        });
      });
    }

    const headers = await getAuthHeaders();
    // Don't set Content-Type for FormData - let browser set it with boundary

    const response = await fetch(`${API_BASE_URL}/feedback`, {
      method: 'POST',
      headers: headers,
      body: formData,
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || data.errors?.join(', ') || 'Failed to submit feedback');
    }

    return data;
  } catch (error) {
    console.error('Error submitting feedback:', error);
    throw error;
  }
}
