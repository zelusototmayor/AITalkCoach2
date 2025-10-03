import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    sessionId: Number,
    sessionToken: String,
    apiEndpoint: String,
    pollInterval: Number,
    autoRefresh: Boolean
  }
  
  static targets = ["status", "progressBar", "statusText", "estimatedTime", "step"]

  initialize() {
    this.pollIntervalValue = this.pollIntervalValue || 3000 // Default 3 seconds
    this.autoRefreshValue = this.autoRefreshValue ?? true
    this.pollTimer = null
    this.isPolling = false
  }

  connect() {
    const identifier = this.sessionIdValue || this.sessionTokenValue || 'unknown'
    console.log(`[Progress Controller] Connected for session ${identifier}`)
    if (this.shouldStartPolling()) {
      console.log('[Progress Controller] Starting polling')
      this.startPolling()
    } else {
      console.log('[Progress Controller] Not starting polling - conditions not met')
    }
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    if (this.isPolling || (!this.sessionIdValue && !this.sessionTokenValue)) return

    this.isPolling = true
    this.poll() // Initial poll

    this.pollTimer = setInterval(() => {
      this.poll()
    }, this.pollIntervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
    this.isPolling = false
  }

  async poll() {
    try {
      const identifier = this.sessionIdValue || this.sessionTokenValue
      console.log(`[Progress Controller] Polling status for session ${identifier}`)

      // Use custom API endpoint if provided (for trial sessions), otherwise use default
      const apiUrl = this.apiEndpointValue || `/api/sessions/${this.sessionIdValue}/status`

      const response = await fetch(apiUrl, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      console.log(`[Progress Controller] Status API response:`, {
        status: response.status,
        statusText: response.statusText,
        ok: response.ok
      })

      if (!response.ok) {
        throw new Error(`Status check failed: ${response.status}`)
      }

      const data = await response.json()
      console.log('[Progress Controller] Status data received:', data)
      
      this.updateProgress(data)
      
      // Stop polling if completed or failed
      if (data.processing_state === 'completed' || data.processing_state === 'failed') {
        console.log(`[Progress Controller] Stopping polling - session is ${data.processing_state}`)
        this.stopPolling()
        
        if (data.processing_state === 'completed' && this.autoRefreshValue) {
          console.log('[Progress Controller] Scheduling page refresh for completed session')
          this.schedulePageRefresh()
        }
      }

    } catch (error) {
      console.error('[Progress Controller] Progress polling error:', error)
      
      // Stop polling on persistent errors but show a notification
      this.stopPolling()
      this.showErrorNotification('Unable to check processing status')
    }
  }

  updateProgress(data) {
    const { processing_state, progress_info } = data
    
    console.log(`[Progress Controller] Updating progress - state: ${processing_state}`, progress_info)
    
    if (this.hasProgressBarTarget && progress_info?.progress !== undefined) {
      console.log(`[Progress Controller] Updating progress bar to ${progress_info.progress}%`)
      this.progressBarTarget.style.width = `${progress_info.progress}%`
      this.progressBarTarget.setAttribute('aria-valuenow', progress_info.progress)
    }

    if (this.hasStatusTextTarget && progress_info?.step) {
      console.log(`[Progress Controller] Updating status text to: ${progress_info.step}`)
      this.statusTextTarget.textContent = progress_info.step
    }

    if (this.hasEstimatedTimeTarget && progress_info?.estimated_time) {
      console.log(`[Progress Controller] Updating estimated time to: ${progress_info.estimated_time}`)
      this.estimatedTimeTarget.textContent = progress_info.estimated_time
    }

    if (this.hasStepTarget && progress_info?.step) {
      console.log(`[Progress Controller] Updating step to: ${progress_info.step}`)
      this.stepTarget.textContent = progress_info.step
    }

    // Update the overall status container class
    if (this.hasStatusTarget) {
      const newClass = `processing-status status-${processing_state}`
      console.log(`[Progress Controller] Updating status container class to: ${newClass}`)
      this.statusTarget.className = newClass
    }

    // Show success message when completed
    if (processing_state === 'completed') {
      console.log('[Progress Controller] Session completed - showing success notification')
      this.showSuccessNotification('Analysis complete! Page will refresh shortly.')
    } else if (processing_state === 'failed') {
      console.log('[Progress Controller] Session failed - showing error notification')
      this.showErrorNotification('Processing failed. Please try reprocessing the session.')
    }
  }

  schedulePageRefresh() {
    setTimeout(() => {
      window.location.reload()
    }, 500) // Wait 0.5 seconds before refreshing
  }

  shouldStartPolling() {
    // Only poll if we have a session ID or token and the initial state indicates processing
    if (!this.sessionIdValue && !this.sessionTokenValue) return false

    // Check if there's a processing status element indicating we should poll
    const statusElement = document.querySelector('.processing-status')
    if (!statusElement) return false

    const currentState = statusElement.classList.contains('status-pending') ||
                        statusElement.classList.contains('status-processing')

    return currentState
  }

  showSuccessNotification(message) {
    this.showNotification(message, 'success')
  }

  showErrorNotification(message) {
    this.showNotification(message, 'error')
  }

  showNotification(message, type = 'info') {
    // Remove any existing progress notifications
    const existingNotifications = document.querySelectorAll('.progress-notification')
    existingNotifications.forEach(n => n.remove())

    const notification = document.createElement('div')
    notification.className = `progress-notification notification-${type}`
    notification.textContent = message
    
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 12px 20px;
      border-radius: 6px;
      color: white;
      font-weight: 500;
      z-index: 1001;
      max-width: 400px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      animation: slideInRight 0.3s ease-out;
    `
    
    // Set background color based on type
    switch (type) {
      case 'success':
        notification.style.backgroundColor = '#10b981'
        break
      case 'error':
        notification.style.backgroundColor = '#ef4444'
        break
      case 'warning':
        notification.style.backgroundColor = '#f59e0b'
        break
      default:
        notification.style.backgroundColor = '#3b82f6'
    }
    
    document.body.appendChild(notification)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.style.animation = 'slideOutRight 0.3s ease-out'
        setTimeout(() => {
          if (notification.parentNode) {
            notification.remove()
          }
        }, 300)
      }
    }, 5000)
  }

  // Manual actions
  forceRefresh() {
    window.location.reload()
  }

  retryProcessing() {
    // Trigger reprocess action
    const reprocessButton = document.querySelector('[data-action*="session#reprocess"]')
    if (reprocessButton) {
      reprocessButton.click()
    }
  }
}