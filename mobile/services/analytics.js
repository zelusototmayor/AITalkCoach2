import { Mixpanel } from 'mixpanel-react-native';
import { Platform } from 'react-native';
import Constants from 'expo-constants';

class AnalyticsService {
  constructor() {
    this.mixpanel = null;
    this.initialized = false;
    this.debug = __DEV__; // Enable debug logging in development
  }

  /**
   * Initialize Mixpanel analytics
   * @param {string} token - Mixpanel project token
   */
  async init(token) {
    if (this.initialized) {
      console.log('⚠️ Analytics already initialized');
      return;
    }

    try {
      // trackAutomaticEvents: false - we'll track manually
      // useNative: false - required for Expo compatibility
      const trackAutomaticEvents = false;
      const useNative = false;

      this.mixpanel = new Mixpanel(token, trackAutomaticEvents, useNative);
      await this.mixpanel.init();
      this.initialized = true;

      // Register super properties (sent with every event)
      this.mixpanel.registerSuperProperties({
        platform: Platform.OS,
        app_version: Constants.expoConfig?.version || '1.0.0',
        device_model: Constants.deviceName || 'Unknown',
        os_version: Platform.Version,
      });

      if (this.debug) {
        console.log('✅ Analytics initialized successfully', {
          platform: Platform.OS,
          version: Constants.expoConfig?.version,
        });
      }
    } catch (error) {
      console.error('❌ Analytics initialization failed:', error);
    }
  }

  /**
   * Identify a user
   * @param {string} userId - Unique user identifier
   * @param {object} traits - User properties
   */
  identify(userId, traits = {}) {
    if (!this.initialized) {
      if (this.debug) console.log('⚠️ Analytics not initialized, skipping identify');
      return;
    }

    try {
      this.mixpanel.identify(userId);
      this.mixpanel.getPeople().set({
        $name: traits.name || '',
        $email: traits.email || '',
        ...traits,
      });

      if (this.debug) {
        console.log('👤 User identified:', userId);
      }
    } catch (error) {
      console.error('❌ Analytics identify failed:', error);
    }
  }

  /**
   * Track an event
   * @param {string} eventName - Name of the event
   * @param {object} properties - Event properties
   */
  track(eventName, properties = {}) {
    if (!this.initialized) {
      if (this.debug) console.log('⚠️ Analytics not initialized, skipping track');
      return;
    }

    try {
      const enrichedProperties = {
        ...properties,
        timestamp: new Date().toISOString(),
      };

      this.mixpanel.track(eventName, enrichedProperties);

      if (this.debug) {
        console.log(`📊 Event tracked: ${eventName}`, enrichedProperties);
      }
    } catch (error) {
      console.error('❌ Analytics track failed:', error);
    }
  }

  /**
   * Track a screen view
   * @param {string} screenName - Name of the screen
   * @param {object} properties - Additional properties
   */
  trackScreen(screenName, properties = {}) {
    this.track('Screen Viewed', {
      screen_name: screenName,
      ...properties,
    });
  }

  /**
   * Set user properties
   * @param {object} properties - Properties to set
   */
  setUserProperties(properties) {
    if (!this.initialized) {
      if (this.debug) console.log('⚠️ Analytics not initialized, skipping setUserProperties');
      return;
    }

    try {
      this.mixpanel.getPeople().set(properties);

      if (this.debug) {
        console.log('User properties set:', properties);
      }
    } catch (error) {
      console.error('❌ Analytics setUserProperties failed:', error);
    }
  }

  /**
   * Increment a user property
   * @param {string} property - Property name
   * @param {number} value - Value to increment by (default 1)
   */
  incrementProperty(property, value = 1) {
    if (!this.initialized) {
      if (this.debug) console.log('⚠️ Analytics not initialized, skipping increment');
      return;
    }

    try {
      this.mixpanel.getPeople().increment(property, value);

      if (this.debug) {
        console.log(`Incremented ${property} by ${value}`);
      }
    } catch (error) {
      console.error('❌ Analytics increment failed:', error);
    }
  }

  /**
   * Start timing an event
   * @param {string} eventName - Name of the event to time
   */
  timeEvent(eventName) {
    if (!this.initialized) {
      if (this.debug) console.log('⚠️ Analytics not initialized, skipping timeEvent');
      return;
    }

    try {
      this.mixpanel.timeEvent(eventName);

      if (this.debug) {
        console.log(`⏱️ Started timing: ${eventName}`);
      }
    } catch (error) {
      console.error('❌ Analytics timeEvent failed:', error);
    }
  }

  /**
   * Reset analytics (call on logout)
   */
  reset() {
    if (!this.initialized) {
      if (this.debug) console.log('⚠️ Analytics not initialized, skipping reset');
      return;
    }

    try {
      this.mixpanel.reset();

      if (this.debug) {
        console.log('🔄 Analytics reset (user logged out)');
      }
    } catch (error) {
      console.error('❌ Analytics reset failed:', error);
    }
  }

  /**
   * Register super properties (sent with all events)
   * @param {object} properties - Properties to register
   */
  registerSuperProperties(properties) {
    if (!this.initialized) {
      if (this.debug) console.log('⚠️ Analytics not initialized, skipping registerSuperProperties');
      return;
    }

    try {
      this.mixpanel.registerSuperProperties(properties);

      if (this.debug) {
        console.log('Super properties registered:', properties);
      }
    } catch (error) {
      console.error('❌ Analytics registerSuperProperties failed:', error);
    }
  }

  /**
   * Get the current distinct ID
   * @returns {Promise<string>} The distinct ID
   */
  async getDistinctId() {
    if (!this.initialized) {
      return null;
    }

    try {
      return await this.mixpanel.getDistinctId();
    } catch (error) {
      console.error('❌ Analytics getDistinctId failed:', error);
      return null;
    }
  }
}

// Export singleton instance
export default new AnalyticsService();
