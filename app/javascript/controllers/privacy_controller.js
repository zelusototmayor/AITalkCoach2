import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["privacyModeDetails", "retentionPreview"]
  
  togglePrivacyMode(event) {
    const isEnabled = event.target.checked
    const detailsElement = this.privacyModeDetailsTarget
    
    if (isEnabled) {
      detailsElement.style.display = 'block'
      this.showNotification('Privacy mode enabled - additional protections are now active', 'info')
    } else {
      detailsElement.style.display = 'none'
    }
  }
  
  toggleProcessedDeletion(event) {
    const isEnabled = event.target.checked
    
    if (isEnabled) {
      this.showNotification('Processed audio will be deleted after analysis completion', 'info')
    }
  }
  
  updateRetentionPreview(event) {
    const days = parseInt(event.target.value)
    const previewElement = this.retentionPreviewTarget
    
    if (days) {
      const cutoffDate = new Date()
      cutoffDate.setDate(cutoffDate.getDate() - days)
      
      previewElement.innerHTML = `
        <div class="info-card info-card-info">
          <div class="info-icon">📅</div>
          <div class="info-content">
            <h4>Updated Retention Policy</h4>
            <p>
              Audio files will be automatically deleted after <strong>${days} days</strong>.
              Files older than ${cutoffDate.toLocaleDateString('en-US', { 
                year: 'numeric', 
                month: 'long', 
                day: 'numeric' 
              })} will be removed in the next cleanup.
            </p>
          </div>
        </div>
      `
    } else {
      previewElement.innerHTML = `
        <div class="info-card info-card-neutral">
          <div class="info-icon">♾️</div>
          <div class="info-content">
            <h4>No Automatic Deletion</h4>
            <p>Your audio files will be kept indefinitely.</p>
          </div>
        </div>
      `
    }
  }
  
  exportData(event) {
    event.preventDefault()
    
    if (!confirm('This will generate a complete export of all your data. Continue?')) {
      return
    }
    
    const button = event.target
    const originalText = button.textContent
    button.textContent = '⏳ Generating export...'
    button.disabled = true
    
    // In a real implementation, this would trigger an API call to generate the export
    // For now, we'll simulate the process
    setTimeout(() => {
      this.showNotification('Data export has been generated and will be emailed to you shortly', 'success')
      button.textContent = originalText
      button.disabled = false
    }, 2000)
  }
  
  requestDataDeletion(event) {
    event.preventDefault()
    
    const confirmationText = 'DELETE ALL DATA'
    const userInput = prompt(
      `⚠️ WARNING: This will permanently delete ALL your data including:\n\n` +
      `• All recording sessions and audio files\n` +
      `• Analysis results and transcripts\n` +
      `• Progress history and insights\n` +
      `• Account settings and preferences\n\n` +
      `This action CANNOT be undone!\n\n` +
      `Type "${confirmationText}" to confirm:`
    )
    
    if (userInput !== confirmationText) {
      this.showNotification('Data deletion cancelled', 'info')
      return
    }
    
    const button = event.target
    const originalText = button.textContent
    button.textContent = '⏳ Deleting all data...'
    button.disabled = true
    
    // In a real implementation, this would trigger the deletion API
    setTimeout(() => {
      this.showNotification('Data deletion request submitted. You will receive a confirmation email.', 'success')
      button.textContent = originalText
      button.disabled = false
    }, 2000)
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
      border-radius: 6px;
      color: white;
      font-weight: 500;
      z-index: 1001;
      max-width: 400px;
      animation: slideInRight 0.3s ease-out;
    `
    
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
    
    setTimeout(() => {
      notification.style.animation = 'slideOutRight 0.3s ease-out'
      setTimeout(() => {
        if (notification.parentNode) {
          notification.remove()
        }
      }, 300)
    }, 5000)
  }
}