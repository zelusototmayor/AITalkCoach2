import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: String }
  
  exportSession(event) {
    event.preventDefault()
    
    const exportMenu = this.createExportMenu()
    this.showExportMenu(exportMenu, event.target)
  }
  
  createExportMenu() {
    const menu = document.createElement('div')
    menu.className = 'export-menu'
    menu.innerHTML = `
      <div class="export-options">
        <h4>Export Session</h4>
        <button class="export-option" data-format="json" data-action="click->session#downloadExport">
          📊 Complete Analysis (JSON)
        </button>
        <button class="export-option" data-format="txt" data-action="click->session#downloadExport">
          📄 Transcript & Issues (TXT)  
        </button>
        <button class="export-option" data-format="csv" data-action="click->session#downloadExport">
          📈 Issues Summary (CSV)
        </button>
        <button class="export-close" data-action="click->session#closeExportMenu">
          ✕ Close
        </button>
      </div>
    `
    return menu
  }
  
  showExportMenu(menu, triggerButton) {
    document.body.appendChild(menu)
    
    const rect = triggerButton.getBoundingClientRect()
    menu.style.position = 'absolute'
    menu.style.top = `${rect.bottom + 5}px`
    menu.style.left = `${rect.left}px`
    menu.style.zIndex = '1000'
    
    // Close menu when clicking outside
    setTimeout(() => {
      document.addEventListener('click', this.closeExportMenuOnOutsideClick.bind(this))
    }, 100)
    
    this.currentExportMenu = menu
  }
  
  closeExportMenuOnOutsideClick(event) {
    if (this.currentExportMenu && !this.currentExportMenu.contains(event.target)) {
      this.closeExportMenu()
    }
  }
  
  closeExportMenu() {
    if (this.currentExportMenu) {
      this.currentExportMenu.remove()
      this.currentExportMenu = null
      document.removeEventListener('click', this.closeExportMenuOnOutsideClick.bind(this))
    }
  }
  
  downloadExport(event) {
    event.preventDefault()
    const format = event.target.dataset.format
    
    const url = `/api/sessions/${this.idValue}/export.${format}`
    
    // Show loading state
    const originalText = event.target.textContent
    event.target.textContent = '⏳ Preparing...'
    event.target.disabled = true
    
    fetch(url)
      .then(response => {
        if (!response.ok) {
          if (response.status === 404) {
            throw new Error("Session not found")
          } else if (response.status === 403) {
            throw new Error("Access denied")
          } else if (response.status === 500) {
            throw new Error("Server error - please try again later")
          } else {
            throw new Error(`Export failed (${response.status})`)
          }
        }
        return response.blob()
      })
      .then(blob => {
        // Create download link
        const downloadUrl = window.URL.createObjectURL(blob)
        const link = document.createElement('a')
        link.href = downloadUrl
        
        // Set filename based on format
        const sessionTitle = document.querySelector('h1').textContent.trim()
        const timestamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-')
        
        switch (format) {
          case 'json':
            link.download = `${sessionTitle.toLowerCase().replace(/\s+/g, '-')}-analysis-${timestamp}.json`
            break
          case 'txt':
            link.download = `${sessionTitle.toLowerCase().replace(/\s+/g, '-')}-transcript-${timestamp}.txt`
            break
          case 'csv':
            link.download = `${sessionTitle.toLowerCase().replace(/\s+/g, '-')}-issues-${timestamp}.csv`
            break
        }
        
        // Trigger download
        document.body.appendChild(link)
        link.click()
        document.body.removeChild(link)
        window.URL.revokeObjectURL(downloadUrl)
        
        // Show success message
        this.showNotification(`Export downloaded successfully!`, 'success')
        this.closeExportMenu()
      })
      .catch(error => {
        console.error('Export error:', error)
        this.showNotification(`Export failed: ${error.message}`, 'error')
      })
      .finally(() => {
        // Restore button state
        event.target.textContent = originalText
        event.target.disabled = false
      })
  }
  
  reprocess(event) {
    event.preventDefault()
    
    console.log(`[Session Controller] Starting reprocess for session ${this.idValue}`)
    
    if (!confirm('Are you sure you want to reprocess this session? This will re-analyze the audio with fresh AI insights.')) {
      console.log('[Session Controller] Reprocess cancelled by user')
      return
    }
    
    const button = event.target
    const originalText = button.textContent
    button.textContent = '⏳ Reprocessing...'
    button.disabled = true
    
    console.log(`[Session Controller] Making reprocess API call to /api/sessions/${this.idValue}/reprocess_ai`)
    
    fetch(`/api/sessions/${this.idValue}/reprocess_ai`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => {
      console.log(`[Session Controller] Reprocess API response:`, {
        status: response.status,
        statusText: response.statusText,
        ok: response.ok
      })
      
      if (!response.ok) {
        // Log the response for debugging
        return response.json().then(errorData => {
          console.error('[Session Controller] API Error Response:', errorData)
          
          if (response.status === 422) {
            throw new Error(errorData.error || 'Session cannot be reprocessed in current state')
          } else if (response.status === 404) {
            throw new Error('Session not found')
          } else if (response.status === 500) {
            throw new Error('Server error - please try again later')
          } else {
            throw new Error(`Request failed (${response.status}): ${errorData.error || response.statusText}`)
          }
        }).catch(jsonError => {
          // If response.json() fails, throw original error
          console.error('[Session Controller] Failed to parse error response:', jsonError)
          throw new Error(`Request failed (${response.status})`)
        })
      }
      return response.json()
    })
    .then(data => {
      console.log('[Session Controller] Reprocess success response:', data)
      
      if (data.message) {
        this.showNotification(data.message, 'success')
        console.log(`[Session Controller] Session state changed to: ${data.new_state}`)
        
        // Refresh page after a short delay to show updated processing state
        setTimeout(() => {
          console.log('[Session Controller] Refreshing page to show updated state')
          window.location.reload()
        }, 2000)
      } else {
        throw new Error(data.error || 'Reprocessing failed')
      }
    })
    .catch(error => {
      console.error('[Session Controller] Reprocess error:', error)
      let userMessage = error.message
      
      // Handle network errors
      if (error.name === 'TypeError' && error.message.includes('fetch')) {
        userMessage = 'Network error - please check your connection'
        console.error('[Session Controller] Network error detected')
      } else if (error.name === 'AbortError') {
        userMessage = 'Request was cancelled - please try again'
        console.error('[Session Controller] Request aborted')
      }
      
      console.log(`[Session Controller] Showing error notification: ${userMessage}`)
      this.showNotification(`Reprocessing failed: ${userMessage}`, 'error')
      button.textContent = originalText
      button.disabled = false
    })
  }
  
  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `notification notification-${type}`
    notification.textContent = message
    
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 12px 20px;
      border-radius: 4px;
      color: white;
      font-weight: 500;
      z-index: 1001;
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
      default:
        notification.style.backgroundColor = '#3b82f6'
    }
    
    document.body.appendChild(notification)
    
    // Auto-remove after 3 seconds
    setTimeout(() => {
      notification.style.animation = 'slideOutRight 0.3s ease-out'
      setTimeout(() => {
        if (notification.parentNode) {
          notification.remove()
        }
      }, 300)
    }, 3000)
  }
}