import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "display", "progressCircle", "percentage", "status", "timeDisplay",
    "startBtn", "cancelBtn", "durationText", "report",
    "form", "titleInput", "durationInput", "submitBtn"
  ]
  static values = {
    defaultDuration: Number
  }

  initialize() {
    this.selectedDuration = 60
    this.currentTime = 0
    this.timer = null
    this.isRunning = false
    this.enforceMinimum = true
    this.sessionData = null
  }

  connect() {
    this.defaultDurationValue = this.defaultDurationValue || 60
    this.selectedDuration = this.defaultDurationValue
    this.updateDisplay()

    // Set up global reference for cross-controller communication
    window.practiceTimerController = this

    // Listen for custom recording upload events
    this.element.addEventListener('recording:uploaded', this.handleRecordingUploadEvent.bind(this))
  }

  disconnect() {
    this.stopTimer()

    // Clean up global reference
    if (window.practiceTimerController === this) {
      window.practiceTimerController = null
    }

    // Remove event listener
    this.element.removeEventListener('recording:uploaded', this.handleRecordingUploadEvent.bind(this))
  }

  selectDuration(event) {
    if (this.isRunning) return // Don't allow changing duration while running

    this.selectedDuration = parseInt(event.target.dataset.duration)

    // Update UI
    document.querySelectorAll('.preset-btn').forEach(btn => {
      btn.classList.remove('active')
    })
    event.target.classList.add('active')

    // Update display
    this.updateDisplay()

    // Update duration text
    if (this.hasDurationTextTarget) {
      this.durationTextTarget.textContent = `${this.selectedDuration}s`
    }

    // Update hidden form field
    if (this.hasDurationInputTarget) {
      this.durationInputTarget.value = this.selectedDuration
    }
  }

  startSession() {
    if (this.isRunning) return

    // Validate required fields before starting
    if (!this.validatePreRecordingSetup()) {
      return
    }

    this.isRunning = true
    this.currentTime = 0

    // Hide the setup form and copy values to the hidden form
    this.completeSetup()

    // Update UI state
    this.updateButtonState('running')
    this.hideReport()

    // Start the countdown timer
    this.startTimer()
  }

  startTimer() {
    // Automatically start recording when timer begins
    this.startRecording()

    this.timer = setInterval(() => {
      this.currentTime++
      this.updateDisplay()

      // Check if minimum time completed
      if (this.currentTime >= this.selectedDuration) {
        this.completeSession()
      }
    }, 1000)
  }

  stopTimer() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  completeSession() {
    this.stopTimer()
    this.isRunning = false

    // Automatically stop recording when timer completes
    this.stopRecording()

    // Mark as timer completed
    this.updateButtonState('timer_completed')
    this.updateDisplay()

    // Generate auto title
    this.generateSessionTitle()

    // Show completion message
    this.showTimerCompletionNotification()

    // Show audio preview with choice buttons (not auto-submit)
    this.showRecordingChoiceInterface()
  }

  forceStop() {
    if (!this.isRunning) return

    const timeRemaining = this.selectedDuration - this.currentTime

    if (timeRemaining > 0 && this.enforceMinimum) {
      // Show warning about incomplete session
      this.showIncompleteWarning(timeRemaining)
      return false
    }

    this.stopTimer()
    this.isRunning = false
    this.updateButtonState('ready')
    return true
  }

  updateDisplay() {
    const timeRemaining = Math.max(this.selectedDuration - this.currentTime, 0)

    // Calculate progress: only reach 100% when currentTime equals selectedDuration
    const progress = this.currentTime >= this.selectedDuration ? 100 : (this.currentTime / this.selectedDuration) * 100

    // Update progress circle
    if (this.hasProgressCircleTarget) {
      const circumference = 2 * Math.PI * 36 // radius = 36 (matches HTML)
      const offset = circumference - (progress / 100) * circumference
      this.progressCircleTarget.style.strokeDasharray = `${circumference} ${circumference}`
      this.progressCircleTarget.style.strokeDashoffset = offset
    }

    // Update percentage
    if (this.hasPercentageTarget) {
      this.percentageTarget.textContent = `${Math.round(progress)}%`
    }

    // Update status
    if (this.hasStatusTarget) {
      if (this.isRunning) {
        if (timeRemaining > 0) {
          this.statusTarget.textContent = 'Speaking...'
        } else {
          this.statusTarget.textContent = 'Complete!'
        }
      } else {
        this.statusTarget.textContent = 'Ready'
      }
    }

    // Update time display
    if (this.hasTimeDisplayTarget) {
      this.timeDisplayTarget.textContent = `${this.currentTime}s / ${this.selectedDuration}s`
    }
  }

  updateButtonState(state) {
    if (!this.hasStartBtnTarget) return

    switch (state) {
      case 'ready':
        this.startBtnTarget.textContent = `▶ Start ${this.selectedDuration}s`
        this.startBtnTarget.disabled = false
        this.startBtnTarget.classList.remove('running', 'completed', 'timer-completed')
        this.startBtnTarget.style.display = 'inline-block'
        // Hide cancel button when ready
        if (this.hasCancelBtnTarget) {
          this.cancelBtnTarget.style.display = 'none'
        }
        break

      case 'running':
        this.startBtnTarget.textContent = `🎙️ Recording... (${this.selectedDuration}s)`
        this.startBtnTarget.disabled = true
        this.startBtnTarget.classList.add('running')
        // Show cancel button when recording
        if (this.hasCancelBtnTarget) {
          this.cancelBtnTarget.style.display = 'inline-block'
        }
        break

      case 'timer_completed':
        this.startBtnTarget.style.display = 'none'
        this.startBtnTarget.classList.remove('running')
        this.startBtnTarget.classList.add('timer-completed')
        // Hide cancel button when completed
        if (this.hasCancelBtnTarget) {
          this.cancelBtnTarget.style.display = 'none'
        }
        break

      case 'completed':
        this.startBtnTarget.textContent = '✅ Session Complete'
        this.startBtnTarget.disabled = true
        this.startBtnTarget.classList.remove('running', 'timer-completed')
        this.startBtnTarget.classList.add('completed')
        // Hide cancel button when completed
        if (this.hasCancelBtnTarget) {
          this.cancelBtnTarget.style.display = 'none'
        }
        break
    }
  }

  // Recording actions methods removed - now handled automatically

  generateSessionTitle() {
    const now = new Date()
    const timeString = now.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    })
    const title = `Practice Session - ${timeString}`

    if (this.hasTitleInputTarget) {
      this.titleInputTarget.value = title
    }
  }

  showTimerCompletionNotification() {
    this.showNotification(
      `Recording complete! Your ${this.selectedDuration}s session is ready for analysis.`,
      'success'
    )
  }

  showCompletionNotification() {
    this.showNotification(
      `Great job! You completed a ${this.selectedDuration}s practice session.`,
      'success'
    )
  }

  showIncompleteWarning(timeRemaining) {
    this.showNotification(
      `Please continue for ${timeRemaining} more seconds to complete the minimum time requirement.`,
      'warning'
    )
  }

  showRecordingChoiceInterface() {
    // Use the new post-recording actions section instead of the report
    const postRecordingActions = document.querySelector('[data-recorder-target="postRecordingActions"]')
    if (postRecordingActions) {
      // Update duration info
      const durationElement = postRecordingActions.querySelector('[data-recorder-target="recordingDuration"]')
      if (durationElement) {
        durationElement.textContent = `Duration: ${this.currentTime}s`
      }

      // Show the post-recording actions
      postRecordingActions.style.display = 'block'

      // Add smooth animation
      postRecordingActions.style.opacity = '0'
      postRecordingActions.style.transform = 'translateY(10px)'

      setTimeout(() => {
        postRecordingActions.style.transition = 'all 0.3s ease-out'
        postRecordingActions.style.opacity = '1'
        postRecordingActions.style.transform = 'translateY(0)'
      }, 50)
    }

    // Also hide the old report if it exists
    if (this.hasReportTarget) {
      this.reportTarget.style.display = 'none'
    }
  }

  showSessionReport() {
    if (!this.hasReportTarget) return

    // Basic report content (will be enhanced with real session data)
    const reportHTML = `
      <div class="report-metrics">
        <div class="metric">
          <span class="metric-label">Duration</span>
          <span class="metric-value">${this.currentTime}s</span>
        </div>
        <div class="metric">
          <span class="metric-label">Target</span>
          <span class="metric-value">${this.selectedDuration}s</span>
        </div>
        <div class="metric">
          <span class="metric-label">Status</span>
          <span class="metric-value">${this.currentTime >= this.selectedDuration ? 'Complete' : 'Incomplete'}</span>
        </div>
      </div>
    `

    this.reportTarget.querySelector('.report-content').innerHTML = reportHTML
    this.reportTarget.style.display = 'block'
  }

  hideReport() {
    if (this.hasReportTarget) {
      this.reportTarget.style.display = 'none'
    }
  }

  startNewSession() {
    // Reset everything for a new session
    this.currentTime = 0
    this.isRunning = false
    this.stopTimer()

    // Update UI
    this.updateButtonState('ready')
    this.updateDisplay()
    this.hideReport()

    // Show setup form again
    const setupForm = document.querySelector('.pre-recording-setup')
    if (setupForm) {
      setupForm.style.display = 'block'
    }

    // Clear all form fields
    if (this.hasTitleInputTarget) {
      this.titleInputTarget.value = ''
    }

    // Clear setup form fields
    const titleInput = document.querySelector('[data-recorder-target="titleInput"]')
    const languageSelect = document.querySelector('[data-recorder-target="languageSelect"]')
    const mediaKindSelect = document.querySelector('[data-recorder-target="mediaKindSelect"]')

    if (titleInput) {
      titleInput.value = ''
      titleInput.classList.remove('error')
    }

    if (languageSelect) {
      languageSelect.value = 'en' // Reset to default
      languageSelect.classList.remove('error')
    }

    if (mediaKindSelect) {
      mediaKindSelect.value = 'audio' // Reset to default
    }
  }

  createSession() {
    // Ensure we have a title
    if (!this.hasTitleInputTarget || !this.titleInputTarget.value.trim()) {
      this.generateSessionTitle()
    }

    console.log('Creating session with title:', this.titleInputTarget?.value)

    // Submit the form to create a session
    if (this.hasSubmitBtnTarget) {
      const form = this.submitBtnTarget.closest('form')
      console.log('Submitting form:', form)
      console.log('Form action:', form?.action)
      console.log('Form method:', form?.method)
      this.submitBtnTarget.click()
    } else {
      console.error('Submit button not found in practice timer')
    }
  }

  validatePreRecordingSetup() {
    // Find the title input in the setup form
    const titleInput = document.querySelector('[data-recorder-target="titleInput"]')
    const languageSelect = document.querySelector('[data-recorder-target="languageSelect"]')

    if (!titleInput || !titleInput.value.trim()) {
      this.showNotification('Please enter a session title before starting', 'error')
      if (titleInput) {
        titleInput.focus()
        titleInput.classList.add('error')
      }
      return false
    }

    if (!languageSelect || !languageSelect.value) {
      this.showNotification('Please select a language before starting', 'error')
      if (languageSelect) {
        languageSelect.focus()
        languageSelect.classList.add('error')
      }
      return false
    }

    return true
  }

  completeSetup() {
    // Copy values from setup form to hidden form and preview
    const titleInput = document.querySelector('[data-recorder-target="titleInput"]')
    const languageSelect = document.querySelector('[data-recorder-target="languageSelect"]')
    const mediaKindSelect = document.querySelector('[data-recorder-target="mediaKindSelect"]')

    // Update hidden form fields
    if (this.hasTitleInputTarget && titleInput) {
      this.titleInputTarget.value = titleInput.value
    }

    // Update form fields in the actual session form
    const sessionTitleField = document.querySelector('input[name="session[title]"]')
    const sessionLanguageField = document.querySelector('select[name="session[language]"]') ||
                                  document.querySelector('input[name="session[language]"]')
    const sessionMediaKindField = document.querySelector('select[name="session[media_kind]"]') ||
                                  document.querySelector('input[name="session[media_kind]"]')

    if (sessionTitleField && titleInput) {
      sessionTitleField.value = titleInput.value
    }

    if (sessionLanguageField && languageSelect) {
      sessionLanguageField.value = languageSelect.value
    }

    if (sessionMediaKindField && mediaKindSelect) {
      sessionMediaKindField.value = mediaKindSelect.value
    }

    // Hide the setup form
    const setupForm = document.querySelector('.pre-recording-setup')
    if (setupForm) {
      setupForm.style.display = 'none'
    }
  }

  showNotification(message, type = 'info', duration = 5000) {
    // Remove any existing notifications
    const existingNotifications = document.querySelectorAll('.practice-notification')
    existingNotifications.forEach(n => n.remove())

    const notification = document.createElement('div')
    notification.className = `practice-notification notification-${type}`
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

    // Auto-remove after specified duration
    setTimeout(() => {
      if (notification.parentNode) {
        notification.style.animation = 'slideOutRight 0.3s ease-out'
        setTimeout(() => {
          if (notification.parentNode) {
            notification.remove()
          }
        }, 300)
      }
    }, duration)
  }

  // Called when recording upload is successful
  onRecordingUploaded(sessionData) {
    console.log('Recording uploaded successfully:', sessionData)

    // Now we can mark the session as truly complete
    this.updateButtonState('completed')
    this.showCompletionNotification()

    // Store session data
    this.sessionData = sessionData


    // Update report with real session data
    if (sessionData) {
      this.updateReportWithSessionData(sessionData)
    }
  }

  // Handle custom event from recorder controller
  handleRecordingUploadEvent(event) {
    console.log('Received recording upload event:', event.detail)
    this.onRecordingUploaded(event.detail)
  }

  // Integration with recorder controller (legacy method)
  onRecordingComplete(sessionData) {
    this.onRecordingUploaded(sessionData)
  }

  updateReportWithSessionData(sessionData) {
    if (!this.hasReportTarget) return

    const reportHTML = `
      <div class="report-metrics">
        <div class="metric">
          <span class="metric-label">Duration</span>
          <span class="metric-value">${this.currentTime}s</span>
        </div>
        <div class="metric">
          <span class="metric-label">Status</span>
          <span class="metric-value">Processing...</span>
        </div>
        <div class="metric">
          <span class="metric-label">Session</span>
          <span class="metric-value">#${sessionData.id}</span>
        </div>
      </div>
      <p class="report-note">
        <small>Your session is being analyzed. Check back in a few minutes for detailed feedback.</small>
      </p>
    `

    this.reportTarget.querySelector('.report-content').innerHTML = reportHTML
  }

  // Recorder controller integration methods
  startRecording() {
    const recorderController = this.getRecorderController()
    if (recorderController) {
      console.log('Practice timer: Starting recording automatically')
      recorderController.startRecording()
    } else {
      console.warn('Practice timer: Recorder controller not found')
    }
  }

  stopRecording() {
    const recorderController = this.getRecorderController()
    if (recorderController) {
      console.log('Practice timer: Stopping recording automatically')
      recorderController.stopRecording()
    } else {
      console.warn('Practice timer: Recorder controller not found')
    }
  }

  requestAudioPreview() {
    const recorderController = this.getRecorderController()
    if (recorderController) {
      // Request audio preview be moved to our container
      const audioPreview = recorderController.hasAudioPreviewTarget ? recorderController.audioPreviewTarget : null
      if (audioPreview) {
        const container = document.getElementById('timer-audio-preview')
        if (container && audioPreview.src) {
          const clonedAudio = audioPreview.cloneNode(true)
          clonedAudio.controls = true
          clonedAudio.style.width = '100%'
          container.appendChild(clonedAudio)
        }
      }
    }
  }

  getRecorderController() {
    // Try multiple methods to find the recorder controller
    const recorderElement = document.querySelector('[data-controller*="recorder"]')
    if (recorderElement) {
      // Try to access via Stimulus application
      if (this.application) {
        try {
          return this.application.getControllerForElementAndIdentifier(recorderElement, 'recorder')
        } catch (e) {
          console.log('Could not get recorder via Stimulus API:', e.message)
        }
      }

      // Try direct property access
      if (recorderElement.recorderController) {
        return recorderElement.recorderController
      }
    }

    // Try global reference
    if (window.recorderController) {
      return window.recorderController
    }

    return null
  }

  // User choice handlers
  recordAgain() {
    console.log('Practice timer: User chose to record again')

    // Reset everything for a new recording
    this.currentTime = 0
    this.isRunning = false
    this.stopTimer()

    // Update UI back to ready state
    this.updateButtonState('ready')
    this.updateDisplay()
    this.hideReport()

    // Hide the new post-recording actions
    const postRecordingActions = document.querySelector('[data-recorder-target="postRecordingActions"]')
    if (postRecordingActions) {
      postRecordingActions.style.display = 'none'
    }

    // Clear any existing audio preview
    const container = document.getElementById('timer-audio-preview')
    if (container) {
      container.innerHTML = ''
    }

    this.showNotification('Ready to record again! Click "Start" when ready.', 'info')
  }

  analyzeRecording() {
    console.log('Practice timer: User chose to analyze recording')

    // Trigger submission via recorder controller
    const recorderController = this.getRecorderController()
    if (recorderController) {
      // Update our state to show uploading
      this.updateButtonState('completed')
      this.showNotification('🔄 Submitting recording for AI analysis...', 'info', 8000)

      // Submit the recording
      recorderController.submitRecording()
    } else {
      console.error('Could not find recorder controller to submit recording')
      this.showNotification('❌ Error: Could not submit recording. Please try again.', 'error')
    }
  }

  cancelSession() {
    if (!this.isRunning) return

    console.log('Practice timer: User cancelled recording session')

    // Stop the timer and recording
    this.stopTimer()
    this.isRunning = false

    // Stop the recording via recorder controller
    const recorderController = this.getRecorderController()
    if (recorderController) {
      console.log('Practice timer: Cancelling recording via recorder controller')
      recorderController.cancelRecording()
    }

    // Reset UI to ready state
    this.currentTime = 0
    this.updateButtonState('ready')
    this.updateDisplay()
    this.hideReport()

    // Hide any post-recording actions
    const postRecordingActions = document.querySelector('[data-recorder-target="postRecordingActions"]')
    if (postRecordingActions) {
      postRecordingActions.style.display = 'none'
    }

    // Show setup form again if it was hidden
    const setupForm = document.querySelector('.pre-recording-setup-compact')
    if (setupForm) {
      setupForm.style.display = 'block'
    }

    this.showNotification('Recording cancelled. You can start a new recording when ready.', 'info', 3000)
  }
}