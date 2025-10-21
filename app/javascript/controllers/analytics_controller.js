import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    enabled: Boolean,
    debug: Boolean
  }

  static targets = []

  connect() {
    // Enable analytics in production or when explicitly enabled
    this.enabledValue = this.enabledValue ?? (window.location.hostname !== 'localhost')
    this.debugValue = this.debugValue ?? false

    // Initialize Mixpanel
    this.initializeMixpanel()

    // Track initial page view
    this.trackPageView()

    // Check for signup completion tracking
    this.checkSignupCompletion()

    // Set up global analytics instance for other controllers to use
    window.analyticsController = this

    if (this.debugValue) {
      console.log('Analytics controller connected', {
        enabled: this.enabledValue,
        userType: this.getUserType()
      })
    }
  }

  disconnect() {
    window.analyticsController = null
  }

  // Initialize Mixpanel with super properties
  initializeMixpanel() {
    if (!this.enabledValue || typeof mixpanel === 'undefined') {
      if (this.debugValue) {
        console.log('Mixpanel disabled or not available')
      }
      return
    }

    // Identify user if logged in
    const userId = this.element.dataset.userId
    const userEmail = this.element.dataset.userEmail
    const userName = this.element.dataset.userName

    if (userId) {
      mixpanel.identify(userId)
      mixpanel.people.set({
        '$email': userEmail,
        '$name': userName,
        'User Type': 'authenticated'
      })

      if (this.debugValue) {
        console.log('Mixpanel user identified:', userId)
      }
    }

    // Set super properties (sent with every event)
    mixpanel.register({
      'User Type': this.getUserType(),
      'Environment': window.location.hostname === 'localhost' ? 'development' : 'production',
      'Platform': 'Web'
    })

    if (this.debugValue) {
      console.log('Mixpanel initialized with super properties')
    }
  }

  // Core tracking method - supports both GA and Mixpanel
  trackEvent(eventName, parameters = {}) {
    if (!this.enabledValue) {
      if (this.debugValue) {
        console.log('Analytics disabled:', eventName, parameters)
      }
      return
    }

    // Add common parameters to all events
    const enrichedParameters = {
      user_type: this.getUserType(),
      page_title: document.title,
      page_location: window.location.href,
      timestamp: new Date().toISOString(),
      ...parameters
    }

    // Track with Google Analytics
    if (typeof gtag !== 'undefined') {
      gtag('event', eventName, enrichedParameters)
    }

    // Track with Mixpanel
    if (typeof mixpanel !== 'undefined') {
      // Convert snake_case to Title Case for Mixpanel
      const mixpanelEventName = this.formatEventName(eventName)
      const mixpanelProperties = this.formatPropertiesForMixpanel(enrichedParameters)

      mixpanel.track(mixpanelEventName, mixpanelProperties)
    }

    if (this.debugValue) {
      console.log('Analytics event tracked:', eventName, enrichedParameters)
    }
  }

  // Format event names for Mixpanel (Title Case)
  formatEventName(eventName) {
    return eventName
      .split('_')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ')
  }

  // Format properties for Mixpanel (Title Case keys)
  formatPropertiesForMixpanel(properties) {
    const formatted = {}
    for (const [key, value] of Object.entries(properties)) {
      const formattedKey = key
        .split('_')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ')
      formatted[formattedKey] = value
    }
    return formatted
  }

  // Page view tracking
  trackPageView(pagePath = null) {
    if (!this.enabledValue) {
      return
    }

    const parameters = {
      page_title: document.title,
      user_type: this.getUserType()
    }

    if (pagePath) {
      parameters.page_location = pagePath
    }

    // Track with Google Analytics
    if (typeof gtag !== 'undefined') {
      gtag('config', 'G-KM66Q2D5T3', parameters)
    }

    // Track with Mixpanel
    if (typeof mixpanel !== 'undefined') {
      mixpanel.track_pageview({
        'Page Title': document.title,
        'User Type': this.getUserType()
      })
    }

    if (this.debugValue) {
      console.log('Page view tracked:', parameters)
    }
  }

  // Specific event tracking methods
  trackLandingPageView() {
    this.trackEvent('landing_page_view', {
      event_category: 'engagement',
      event_label: 'homepage'
    })
  }

  trackTrialStarted(source = 'unknown') {
    this.trackEvent('trial_started', {
      event_category: 'conversion',
      event_label: source,
      value: 1
    })
  }

  trackTrialCompleted(duration_seconds = null, target_seconds = null) {
    const parameters = {
      event_category: 'conversion',
      event_label: 'trial_recording_completed',
      value: 1
    }

    if (duration_seconds) {
      parameters.session_duration = duration_seconds
    }
    if (target_seconds) {
      parameters.target_duration = target_seconds
    }

    this.trackEvent('trial_completed', parameters)
  }

  trackTrialAnalysisView(analysis_data = null) {
    const parameters = {
      event_category: 'engagement',
      event_label: 'trial_results_viewed'
    }

    if (analysis_data) {
      parameters.wpm = analysis_data.wpm
      parameters.filler_count = analysis_data.filler_count
    }

    this.trackEvent('trial_analysis_view', parameters)
  }

  trackSignupClicked(source = 'unknown') {
    this.trackEvent('signup_clicked', {
      event_category: 'conversion',
      event_label: source,
      value: 1
    })
  }

  trackSignupCompleted(user_id = null) {
    const parameters = {
      event_category: 'conversion',
      event_label: 'registration_completed',
      value: 10 // Higher value for actual conversions
    }

    if (user_id) {
      parameters.user_id = user_id
    }

    this.trackEvent('signup_completed', parameters)
  }

  trackRealSessionStarted(session_data = {}) {
    const parameters = {
      event_category: 'engagement',
      event_label: 'authenticated_session_started',
      value: 1
    }

    if (session_data.target_seconds) {
      parameters.target_duration = session_data.target_seconds
    }
    if (session_data.prompt_category) {
      parameters.prompt_category = session_data.prompt_category
    }

    this.trackEvent('real_session_started', parameters)
  }

  trackRealSessionCompleted(session_data = {}) {
    const parameters = {
      event_category: 'engagement',
      event_label: 'authenticated_session_completed',
      value: 2
    }

    if (session_data.duration_seconds) {
      parameters.session_duration = session_data.duration_seconds
    }
    if (session_data.target_seconds) {
      parameters.target_duration = session_data.target_seconds
    }

    this.trackEvent('real_session_completed', parameters)
  }

  trackRealAnalysisView(session_data = {}) {
    const parameters = {
      event_category: 'engagement',
      event_label: 'authenticated_analysis_viewed'
    }

    if (session_data.metrics) {
      parameters.wpm = session_data.metrics.wpm
      parameters.clarity_score = session_data.metrics.clarity_score
      parameters.filler_rate = session_data.metrics.filler_rate
    }

    this.trackEvent('real_analysis_view', parameters)
  }

  // Utility methods
  getUserType() {
    // Check if user is logged in by looking for user-specific elements
    const userInfo = document.querySelector('.nav-user')
    const loginLink = document.querySelector('[href*="login"]')
    const trialMode = document.querySelector('.practice-interface.trial-mode')

    if (userInfo) {
      return 'authenticated'
    } else if (trialMode) {
      return 'trial'
    } else {
      return 'anonymous'
    }
  }

  isTrialMode() {
    return this.getUserType() === 'trial'
  }

  isAuthenticated() {
    return this.getUserType() === 'authenticated'
  }

  // Check for signup completion (triggered after redirect from registration)
  checkSignupCompletion() {
    // Check if we have a signup completion indicator in the URL or flash message
    const urlParams = new URLSearchParams(window.location.search)
    const notice = document.querySelector('.flash.notice')

    // Check for signup success notice message
    if (notice && notice.textContent.includes('Account created successfully')) {
      // Track signup completion
      this.trackSignupCompleted()

      // Remove the signup tracking flag if it exists in URL
      if (urlParams.has('signup_completed')) {
        const newUrl = new URL(window.location)
        newUrl.searchParams.delete('signup_completed')
        window.history.replaceState({}, '', newUrl.toString())
      }
    }
  }

  // Action methods for data-action bindings
  handleLandingPageView(event) {
    this.trackLandingPageView()
  }

  handleTrialClick(event) {
    const source = event.target.closest('[data-source]')?.dataset.source || 'landing_page'
    this.trackTrialStarted(source)
  }

  handleSignupClick(event) {
    const source = event.target.closest('[data-source]')?.dataset.source || 'navigation'
    this.trackSignupClicked(source)
  }

  handleRealSessionStart(event) {
    // Track when authenticated users access the practice interface
    this.trackRealSessionStarted()
  }

  handleRealAnalysisView(event) {
    // Track when authenticated users view session analysis
    const sessionData = {
      metrics: this.extractSessionMetrics()
    }
    this.trackRealAnalysisView(sessionData)
  }

  handleTrialAnalysisView(event) {
    // Track when trial users view their analysis results
    const analysisData = this.extractTrialAnalysisData()
    this.trackTrialAnalysisView(analysisData)
  }

  // Helper methods to extract data from page
  extractSessionMetrics() {
    const metricsElements = document.querySelectorAll('[data-metric-value]')
    const metrics = {}

    metricsElements.forEach(element => {
      const metricName = element.dataset.metricName
      const metricValue = parseFloat(element.dataset.metricValue)
      if (metricName && !isNaN(metricValue)) {
        metrics[metricName] = metricValue
      }
    })

    return metrics
  }

  extractTrialAnalysisData() {
    // Extract basic trial metrics from the page
    const wpmElement = document.querySelector('[data-trial-wpm]')
    const fillerElement = document.querySelector('[data-trial-filler-count]')

    // Also try to extract from metric display elements
    const wpmDisplay = document.querySelector('.metric-value-large:contains("WPM")')
    const fillerDisplay = document.querySelector('.trial-metric-card .metric-value-large')

    let wpm = null
    let filler_count = null

    if (wpmElement) {
      wpm = parseInt(wpmElement.dataset.trialWpm)
    } else if (wpmDisplay) {
      const wpmText = wpmDisplay.textContent.match(/(\d+)/)?.[1]
      wpm = wpmText ? parseInt(wpmText) : null
    }

    if (fillerElement) {
      filler_count = parseInt(fillerElement.dataset.trialFillerCount)
    } else if (fillerDisplay) {
      const fillerText = fillerDisplay.textContent.match(/(\d+)/)?.[1]
      filler_count = fillerText ? parseInt(fillerText) : null
    }

    return {
      wpm: wpm,
      filler_count: filler_count
    }
  }
}