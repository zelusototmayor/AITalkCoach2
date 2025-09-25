import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoRefresh: Boolean,
    refreshInterval: Number
  }

  initialize() {
    this.refreshTimer = null
    this.refreshIntervalValue = this.refreshIntervalValue || 30000 // 30 seconds default
  }

  connect() {
    console.log('[Session History] Controller connected')

    if (this.autoRefreshValue) {
      console.log(`[Session History] Starting auto-refresh with ${this.refreshIntervalValue}ms interval`)
      this.startAutoRefresh()
    }

    // Check for newly created sessions and refresh once
    this.checkForNewSessions()
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  startAutoRefresh() {
    if (this.refreshTimer) return

    this.refreshTimer = setInterval(() => {
      this.refreshSilently()
    }, this.refreshIntervalValue)
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }

  refresh() {
    console.log('[Session History] Manual refresh triggered')
    this.showNotification('Refreshing session list...', 'info')
    setTimeout(() => {
      window.location.reload()
    }, 500)
  }

  refreshSilently() {
    console.log('[Session History] Silent refresh check')

    // Check if there are any new sessions by making a simple count request
    fetch('/api/sessions/count', {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.json())
    .then(data => {
      const currentSessionCount = document.querySelectorAll('.session-card').length

      if (data.count > currentSessionCount) {
        console.log('[Session History] New sessions detected, refreshing page')
        this.showNotification('New sessions found. Refreshing...', 'success')
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      }
    })
    .catch(error => {
      console.log('[Session History] Silent refresh check failed:', error)
      // Fail silently for background checks
    })
  }

  checkForNewSessions() {
    // Check if we came from a session creation by looking at the referrer or params
    const urlParams = new URLSearchParams(window.location.search)
    const fromSession = urlParams.get('from_session')
    const justCreated = urlParams.get('created')

    if (fromSession || justCreated) {
      console.log('[Session History] Detected navigation from session creation, refreshing')
      // Small delay then refresh to ensure the session is properly saved
      setTimeout(() => {
        window.location.href = window.location.pathname // Remove query params and refresh
      }, 1000)
    }
  }

  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `session-history-notification notification-${type}`
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
      max-width: 300px;
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

    // Auto-remove after 3 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.style.animation = 'slideOutRight 0.3s ease-out'
        setTimeout(() => {
          if (notification.parentNode) {
            notification.remove()
          }
        }, 300)
      }
    }, 3000)
  }
}