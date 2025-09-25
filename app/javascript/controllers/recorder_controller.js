import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recordBtn", "status", "statusText", "indicator", "preview", "form", "timer", "progressBar", "videoPreview", "audioPreview", "fileInput", "submitBtn", "countdownDisplay", "durationInput", "titleInput", "titleError", "languageSelect", "mediaKindSelect", "titleInputPreview", "languageSelectPreview", "mediaKindSelectPreview"]
  static values = { 
    maxDurationSec: Number, 
    maxFileSizeMb: Number,
    audioOnly: Boolean,
    videoWidth: Number,
    videoHeight: Number
  }

  initialize() {
    this.mediaRecorder = null
    this.recordedChunks = []
    this.stream = null
    this.startTime = null
    this.maxDurationTimer = null
    this.countdownTimer = null
    this.selectedDuration = 60 // Default duration
  }

  connect() {
    this.maxDurationSecValue = this.maxDurationSecValue || 300
    this.maxFileSizeMbValue = this.maxFileSizeMbValue || 50
    this.audioOnlyValue = this.audioOnlyValue ?? false
    this.videoWidthValue = this.videoWidthValue || 640
    this.videoHeightValue = this.videoHeightValue || 480

    // Set up global reference for practice timer integration
    window.recorderController = this

    // Check if we're in a practice timer context
    this.isPracticeTimerMode = document.querySelector('[data-controller*="practice-timer"]') !== null

    this.updateUI("ready")
  }

  selectDuration(event) {
    const duration = parseInt(event.target.dataset.duration)
    this.selectedDuration = duration
    this.maxDurationSecValue = duration
    
    // Update hidden form field
    if (this.hasDurationInputTarget) {
      this.durationInputTarget.value = duration
    }
    
    // Update active button
    document.querySelectorAll('.preset-btn').forEach(btn => {
      btn.classList.remove('active')
    })
    event.target.classList.add('active')
    
    // Update button text if recording
    if (this.hasRecordBtnTarget && this.recordBtnTarget.querySelector('.btn-text')) {
      const btnText = this.recordBtnTarget.querySelector('.btn-text')
      if (btnText.textContent.includes('Start')) {
        btnText.textContent = `Start ${duration}s Recording`
      }
    }
  }

  disconnect() {
    this.stopRecording()
    this.releaseStream()
  }

  async startRecording() {
    try {
      this.updateUI("requesting")
      
      // Check if getUserMedia is supported
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error("Media recording is not supported in this browser")
      }
      
      // Check if MediaRecorder is supported
      if (!window.MediaRecorder) {
        throw new Error("Media recording is not supported in this browser")
      }
      
      const constraints = this.getMediaConstraints()
      this.stream = await navigator.mediaDevices.getUserMedia(constraints)
      
      this.setupMediaRecorder()
      this.updateUI("recording")
      
      this.mediaRecorder.start()
      this.startTime = Date.now()
      
      this.maxDurationTimer = setTimeout(() => {
        this.stopRecording()
      }, this.maxDurationSecValue * 1000)
      
    } catch (error) {
      console.error("Recording failed:", error)
      this.handleRecordingError(error)
    }
  }

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
      this.mediaRecorder.stop()
    }
    
    if (this.maxDurationTimer) {
      clearTimeout(this.maxDurationTimer)
      this.maxDurationTimer = null
    }
    
    this.updateUI("processing")
  }

  getMediaConstraints() {
    const constraints = {
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        sampleRate: 44100,
        channelCount: 1
      }
    }

    if (!this.audioOnlyValue) {
      constraints.video = {
        width: { ideal: this.videoWidthValue },
        height: { ideal: this.videoHeightValue },
        frameRate: { ideal: 30 }
      }
    }

    return constraints
  }

  setupMediaRecorder() {
    const mimeType = this.getSupportedMimeType()
    this.mediaRecorder = new MediaRecorder(this.stream, { mimeType })
    
    this.recordedChunks = []
    
    this.mediaRecorder.ondataavailable = (event) => {
      if (event.data.size > 0) {
        this.recordedChunks.push(event.data)
      }
    }
    
    this.mediaRecorder.onstop = () => {
      this.processRecording()
    }
    
    this.mediaRecorder.onerror = (event) => {
      console.error("MediaRecorder error:", event.error)
      this.updateUI("error", "Recording failed")
    }
  }

  getSupportedMimeType() {
    const videoTypes = [
      'video/webm;codecs=vp9,opus',
      'video/webm;codecs=vp8,opus',
      'video/webm',
      'video/mp4'
    ]
    
    const audioTypes = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/mp4',
      'audio/mpeg'
    ]
    
    const types = this.audioOnlyValue ? audioTypes : videoTypes
    
    for (const type of types) {
      if (MediaRecorder.isTypeSupported(type)) {
        return type
      }
    }
    
    return this.audioOnlyValue ? 'audio/webm' : 'video/webm'
  }

  processRecording() {
    const blob = new Blob(this.recordedChunks, {
      type: this.getSupportedMimeType()
    })

    if (this.validateFileSize(blob)) {
      this.createPreview(blob)
      this.attachToForm(blob)

      // In practice timer mode, don't show the recorder UI
      if (this.isPracticeTimerMode) {
        // Just mark as ready for submission, practice timer will handle UI
        console.log('Recorder: Recording complete in practice timer mode')
      } else {
        this.updateUI("ready_to_submit")
      }
    } else {
      this.updateUI("error", `File too large (${(blob.size / 1024 / 1024).toFixed(1)}MB). Maximum: ${this.maxFileSizeMbValue}MB`)
    }

    this.releaseStream()
  }

  validateFileSize(blob) {
    const sizeMb = blob.size / 1024 / 1024
    return sizeMb <= this.maxFileSizeMbValue
  }

  createPreview(blob) {
    const url = URL.createObjectURL(blob)
    
    if (this.audioOnlyValue) {
      if (this.hasAudioPreviewTarget) {
        this.audioPreviewTarget.src = url
        this.audioPreviewTarget.style.display = "block"
      }
      if (this.hasVideoPreviewTarget) {
        this.videoPreviewTarget.style.display = "none"
      }
    } else {
      if (this.hasVideoPreviewTarget) {
        this.videoPreviewTarget.src = url
        this.videoPreviewTarget.style.display = "block"
      }
      if (this.hasAudioPreviewTarget) {
        this.audioPreviewTarget.style.display = "none"
      }
    }
  }

  createAudioPreview(url) {
    const audio = document.createElement("audio")
    audio.src = url
    audio.controls = true
    audio.className = "w-full mt-2"
    return audio
  }

  createVideoPreview(url) {
    const video = document.createElement("video")
    video.src = url
    video.controls = true
    video.className = "w-full mt-2 rounded"
    video.style.maxHeight = "300px"
    return video
  }

  attachToForm(blob) {
    if (!this.hasFileInputTarget) {
      console.error('File input target not found')
      return
    }

    const file = new File([blob], this.generateFileName(), {
      type: blob.type
    })

    console.log('Attaching file to form:', file.name, file.size, 'bytes')

    const dataTransfer = new DataTransfer()
    dataTransfer.items.add(file)

    this.fileInputTarget.files = dataTransfer.files

    console.log('File attached. Input files:', this.fileInputTarget.files.length)
  }

  generateFileName() {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const extension = this.audioOnlyValue ? 'webm' : 'webm'
    return `recording-${timestamp}.${extension}`
  }

  releaseStream() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }
  }

  updateUI(state, message = "") {
    const hasRecordBtn = this.hasRecordBtnTarget
    const hasStatusText = this.hasStatusTextTarget
    const hasIndicator = this.hasIndicatorTarget
    const hasTimer = this.hasTimerTarget
    const hasSubmitBtn = this.hasSubmitBtnTarget

    // When ready to submit, populate preview form
    if (state === "ready_to_submit") {
      this.populatePreviewForm()
    }

    switch (state) {
      case "ready":
        if (hasRecordBtn) {
          this.recordBtnTarget.disabled = false
          const btnText = this.recordBtnTarget.querySelector('.btn-text')
          if (btnText) btnText.textContent = "🎙️ Start Recording"
          this.recordBtnTarget.classList.remove('recording', 'processing')
          this.recordBtnTarget.classList.add('ready')
        }
        if (hasStatusText) this.statusTextTarget.textContent = "Ready to record your response"
        if (hasIndicator) this.indicatorTarget.className = "status-indicator ready"
        if (hasTimer) this.timerTarget.style.display = "none"
        if (hasSubmitBtn) this.submitBtnTarget.disabled = true
        break

      case "requesting":
        if (hasRecordBtn) {
          this.recordBtnTarget.disabled = true
          const btnText = this.recordBtnTarget.querySelector('.btn-text')
          if (btnText) btnText.textContent = "🔐 Requesting Permissions..."
          this.recordBtnTarget.classList.add('requesting')
        }
        if (hasStatusText) this.statusTextTarget.textContent = "Requesting microphone access..."
        if (hasIndicator) this.indicatorTarget.className = "status-indicator requesting"
        break

      case "recording":
        if (hasRecordBtn) {
          this.recordBtnTarget.disabled = false
          const btnText = this.recordBtnTarget.querySelector('.btn-text')
          if (btnText) btnText.textContent = "⏹️ Stop Recording"
          this.recordBtnTarget.classList.remove('ready', 'requesting')
          this.recordBtnTarget.classList.add('recording')
        }
        if (hasStatusText) {
          this.statusTextTarget.textContent = `🔴 Recording... ${this.formatTime(this.maxDurationSecValue)} remaining`
          this.startRecordingTimer()
        }
        if (hasIndicator) {
          this.indicatorTarget.className = "status-indicator recording"
          // Add pulsing animation
          this.indicatorTarget.style.animation = "pulse 1.5s ease-in-out infinite"
        }
        if (hasTimer) {
          this.timerTarget.style.display = "block"
          if (this.hasCountdownDisplayTarget) {
            this.countdownDisplayTarget.textContent = this.formatTime(this.maxDurationSecValue)
          }
        }
        break

      case "processing":
        if (hasRecordBtn) {
          this.recordBtnTarget.disabled = true
          const btnText = this.recordBtnTarget.querySelector('.btn-text')
          if (btnText) btnText.textContent = "⚙️ Processing..."
          this.recordBtnTarget.classList.remove('recording')
          this.recordBtnTarget.classList.add('processing')
        }
        if (hasStatusText) this.statusTextTarget.textContent = "Processing your recording..."
        if (hasIndicator) {
          this.indicatorTarget.className = "status-indicator processing"
          this.indicatorTarget.style.animation = "spin 2s linear infinite"
        }
        this.stopRecordingTimer()
        break

      case "ready_to_submit":
        if (hasRecordBtn) {
          this.recordBtnTarget.disabled = false
          const btnText = this.recordBtnTarget.querySelector('.btn-text')
          if (btnText) btnText.textContent = "🔄 Record Again"
          this.recordBtnTarget.classList.remove('recording', 'processing')
          this.recordBtnTarget.classList.add('ready')
        }
        if (hasStatusText) this.statusTextTarget.textContent = "✅ Recording complete! Review below or record again."
        if (hasIndicator) {
          this.indicatorTarget.className = "status-indicator ready"
          this.indicatorTarget.style.animation = "none"
        }
        if (hasSubmitBtn) {
          this.submitBtnTarget.disabled = false
          const btnText = this.submitBtnTarget.querySelector('.btn-text')
          if (btnText) btnText.textContent = "📊 Analyze Recording"
        }
        this.showPreview()
        break

      case "error":
        if (hasRecordBtn) {
          this.recordBtnTarget.disabled = false
          const btnText = this.recordBtnTarget.querySelector('.btn-text')
          if (btnText) btnText.textContent = "🔄 Try Again"
          this.recordBtnTarget.classList.remove('recording', 'processing')
          this.recordBtnTarget.classList.add('error')
        }
        if (hasStatusText) {
          this.statusTextTarget.textContent = `❌ Error: ${message}`
          this.statusTextTarget.className = this.statusTextTarget.className.replace(/text-\w+-\d+/, 'text-red-600')
        }
        if (hasIndicator) {
          this.indicatorTarget.className = "status-indicator error"
          this.indicatorTarget.style.animation = "none"
        }
        this.stopRecordingTimer()
        break
    }
  }

  startRecordingTimer() {
    if (!this.hasStatusTextTarget) return
    
    this.countdownTimer = setInterval(() => {
      const elapsed = Math.floor((Date.now() - this.startTime) / 1000)
      const remaining = this.maxDurationSecValue - elapsed
      
      if (this.hasStatusTextTarget) {
        this.statusTextTarget.textContent = `Recording... ${this.formatTime(remaining)} remaining`
      }
      
      // Update countdown display
      if (this.hasCountdownDisplayTarget) {
        this.countdownDisplayTarget.textContent = this.formatTime(remaining)
      }
      
      // Update progress bar (countdown style)
      if (this.hasProgressBarTarget) {
        const progress = (remaining / this.maxDurationSecValue) * 100
        this.progressBarTarget.style.width = `${Math.max(progress, 0)}%`
      }
      
      // Auto-stop when time runs out
      if (remaining <= 0) {
        this.stopRecording()
      }
    }, 1000)
  }

  stopRecordingTimer() {
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer)
      this.countdownTimer = null
    }
  }

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  toggleRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
      this.stopRecording()
    } else {
      this.startRecording()
    }
  }

  showPreview() {
    if (this.hasPreviewTarget) {
      this.previewTarget.style.display = "block"
      // Add smooth slide-in animation
      this.previewTarget.style.opacity = "0"
      this.previewTarget.style.transform = "translateY(20px)"

      // Trigger animation after a brief delay
      setTimeout(() => {
        this.previewTarget.style.transition = "all 0.3s ease-out"
        this.previewTarget.style.opacity = "1"
        this.previewTarget.style.transform = "translateY(0)"
      }, 50)
    }

    // Scroll to preview section smoothly
    setTimeout(() => {
      if (this.hasPreviewTarget) {
        this.previewTarget.scrollIntoView({
          behavior: 'smooth',
          block: 'nearest'
        })
      }
    }, 100)
  }

  retake() {
    if (this.hasPreviewTarget) {
      this.previewTarget.style.display = "none"
    }
    
    if (this.hasVideoPreviewTarget) {
      this.videoPreviewTarget.style.display = "none"
      this.videoPreviewTarget.src = ""
    }
    
    if (this.hasAudioPreviewTarget) {
      this.audioPreviewTarget.style.display = "none"
      this.audioPreviewTarget.src = ""
    }
    
    this.recordedChunks = []
    this.releaseStream()
    this.updateUI("ready")
  }

  acceptRecording() {
    if (this.hasPreviewTarget) {
      this.previewTarget.style.display = "none"
    }
    this.updateUI("ready_to_submit")

    // Automatically submit the recording after accepting it
    this.submitRecording()
  }

  submitRecording() {
    // Validate title before submitting
    if (!this.validateTitle()) {
      return
    }

    // Validate that we have a recording
    if (!this.validateRecording()) {
      return
    }

    // Update submit button to show uploading state
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
      const btnText = this.submitBtnTarget.querySelector('.btn-text')
      if (btnText) btnText.textContent = "📤 Uploading & Analyzing..."
      this.submitBtnTarget.classList.add('uploading')
    }

    // Update hidden form fields with values from the post-recording interface
    this.updateFormFields()

    // Find submit button - could be submitBtnTarget or practice-timer submit button
    let submitBtn = null
    if (this.hasSubmitBtnTarget) {
      submitBtn = this.submitBtnTarget
    } else {
      submitBtn = document.querySelector('[data-practice-timer-target="submitBtn"]')
    }

    if (submitBtn) {
      console.log('Submitting recording with form:', submitBtn.closest('form'))

      // Show uploading notification with better messaging
      this.showNotification('📤 Uploading your recording for AI analysis...', 'info', 8000)

      // Ensure the file is attached before submitting
      setTimeout(() => {
        const form = submitBtn.closest('form')
        if (form) {
          console.log('Form data before submit:', new FormData(form))

          // Add form submit listener to handle response
          this.addFormSubmitHandler(form)

          submitBtn.click()
        } else {
          console.error('Form not found for submit button')
          this.showNotification('❌ Upload failed: Form not found', 'error')
          this.resetSubmitButton()
        }
      }, 100)
    } else {
      console.error('No submit button found')
      this.showNotification('❌ Upload failed: Submit button not found', 'error')
      this.resetSubmitButton()
    }
  }

  validateTitle() {
    const title = this.hasTitleInputTarget ? this.titleInputTarget.value.trim() : ''

    if (!title) {
      this.showTitleError("You need to insert a title to be able to create a new session.")
      return false
    }

    this.clearTitleError()
    return true
  }

  validateRecording() {
    // Check if file input has files
    if (!this.hasFileInputTarget) {
      console.error('File input not found')
      this.showNotification('Recording error: File input not found', 'error')
      return false
    }

    if (!this.fileInputTarget.files || this.fileInputTarget.files.length === 0) {
      console.error('No recording file attached')
      this.showNotification('Please record audio before submitting', 'error')
      return false
    }

    const file = this.fileInputTarget.files[0]
    if (!file || file.size === 0) {
      console.error('Recording file is empty')
      this.showNotification('Recording file is empty. Please record again.', 'error')
      return false
    }

    console.log('Recording validation passed:', file.name, file.size, 'bytes')
    return true
  }

  showTitleError(message) {
    if (this.hasTitleErrorTarget) {
      this.titleErrorTarget.textContent = message
      this.titleErrorTarget.style.display = "block"
    }
    
    if (this.hasTitleInputTarget) {
      this.titleInputTarget.classList.add('error')
    }
  }

  clearTitleError() {
    if (this.hasTitleErrorTarget) {
      this.titleErrorTarget.style.display = "none"
      this.titleErrorTarget.textContent = ""
    }

    if (this.hasTitleInputTarget) {
      this.titleInputTarget.classList.remove('error')
    }
  }

  populatePreviewForm() {
    // Copy values from setup form to preview form
    const titleInput = this.hasTitleInputTarget ? this.titleInputTarget.value : ''
    const languageValue = this.hasLanguageSelectTarget ? this.languageSelectTarget.value : 'en'
    const mediaKindValue = this.hasMediaKindSelectTarget ? this.mediaKindSelectTarget.value : 'audio'

    // Update preview form fields
    if (this.hasTitleInputPreviewTarget) {
      this.titleInputPreviewTarget.value = titleInput
    }

    if (this.hasLanguageSelectPreviewTarget) {
      this.languageSelectPreviewTarget.value = languageValue
    }

    if (this.hasMediaKindSelectPreviewTarget) {
      this.mediaKindSelectPreviewTarget.value = mediaKindValue
    }
  }

  updateFormFields() {
    // Find the form - could be formTarget (new session) or practice-timer form (practice interface)
    let form = null
    if (this.hasFormTarget) {
      form = this.formTarget
    } else {
      // Look for practice-timer form
      form = document.querySelector('[data-practice-timer-target="form"]')
    }

    if (!form) {
      console.error('No form found to update')
      return
    }

    // Get values from the current active form (either setup or preview)
    let titleValue = ''
    let languageValue = 'en'
    let mediaKindValue = 'audio'

    // Try to get from preview form first (post-recording)
    const titleInputPreview = this.hasTitleInputPreviewTarget ? this.titleInputPreviewTarget.value.trim() : ''
    if (titleInputPreview) {
      titleValue = titleInputPreview
    } else {
      // Fall back to main input
      titleValue = this.hasTitleInputTarget ? this.titleInputTarget.value.trim() : ''
    }

    // Get language from appropriate select
    if (this.hasLanguageSelectPreviewTarget && this.languageSelectPreviewTarget.value) {
      languageValue = this.languageSelectPreviewTarget.value
    } else if (this.hasLanguageSelectTarget) {
      languageValue = this.languageSelectTarget.value
    }

    // Get media kind from appropriate select
    if (this.hasMediaKindSelectPreviewTarget && this.mediaKindSelectPreviewTarget.value) {
      mediaKindValue = this.mediaKindSelectPreviewTarget.value
    } else if (this.hasMediaKindSelectTarget) {
      mediaKindValue = this.mediaKindSelectTarget.value
    }

    // Update hidden form fields
    const titleField = form.querySelector('input[name="session[title]"]')
    if (titleField) {
      titleField.value = titleValue
    }

    const languageField = form.querySelector('select[name="session[language]"]') ||
                          form.querySelector('input[name="session[language]"]')
    if (languageField) {
      languageField.value = languageValue
    }

    const mediaKindField = form.querySelector('select[name="session[media_kind]"]') ||
                           form.querySelector('input[name="session[media_kind]"]')
    if (mediaKindField) {
      mediaKindField.value = mediaKindValue
    }
  }

  replayAudio() {
    if (this.hasAudioPreviewTarget) {
      this.audioPreviewTarget.currentTime = 0
      this.audioPreviewTarget.play()
    }
  }

  updateMediaKind(event) {
    const mediaKind = event.target.value
    this.audioOnlyValue = mediaKind === 'audio'
    
    if (this.hasVideoPreviewTarget && this.hasAudioPreviewTarget) {
      if (this.audioOnlyValue) {
        this.videoPreviewTarget.style.display = "none"
        this.audioPreviewTarget.style.display = "block"
      } else {
        this.videoPreviewTarget.style.display = "block"
        this.audioPreviewTarget.style.display = "none"
      }
    }
  }

  handleRecordingError(error) {
    let userMessage = "Recording failed"
    
    if (error.name === 'NotAllowedError') {
      userMessage = "Camera/microphone access denied. Please allow access and try again."
    } else if (error.name === 'NotFoundError') {
      userMessage = "No camera/microphone found. Please check your device connections."
    } else if (error.name === 'NotReadableError') {
      userMessage = "Camera/microphone is being used by another application."
    } else if (error.name === 'OverconstrainedError') {
      userMessage = "Camera/microphone doesn't support the requested settings."
    } else if (error.name === 'AbortError') {
      userMessage = "Recording was aborted. Please try again."
    } else if (error.name === 'NotSupportedError') {
      userMessage = "Recording is not supported in this browser."
    } else if (error.message) {
      userMessage = error.message
    }
    
    this.updateUI("error", userMessage)
    this.showNotification(userMessage, 'error')
  }

  addFormSubmitHandler(form) {
    // Add listener for successful form submission
    form.addEventListener('turbo:submit-end', this.handleFormSubmitEnd.bind(this), { once: true })
  }

  handleFormSubmitEnd(event) {
    console.log('Form submit end event:', event)

    if (event.detail.success) {
      console.log('Form submission successful')

      // Show success message
      this.showNotification('Recording uploaded successfully! Redirecting to analysis...', 'success')

      // Extract session data from response if available
      const sessionData = this.extractSessionDataFromResponse(event)

      // Notify the practice timer that recording was uploaded successfully
      this.notifyPracticeTimer(sessionData)

      // If we got a redirect URL, follow it immediately
      const response = event.detail.formSubmission?.result?.response
      if (response?.redirected && response.url) {
        console.log('Following redirect to:', response.url)
        window.location.href = response.url
      } else {
        // Fallback: look for session ID in URL after a brief delay
        setTimeout(() => {
          if (window.location.pathname.match(/\/sessions\/\d+/)) {
            // We're already on the session page, good!
            console.log('Successfully redirected to session page')
          } else {
            console.warn('No redirect detected, something may be wrong')
          }
        }, 500)
      }
    } else {
      console.error('Form submission failed:', event.detail)
      this.showNotification('Upload failed. Please try again.', 'error')
    }
  }

  extractSessionDataFromResponse(event) {
    // Try to extract session ID from redirect URL or response
    const response = event.detail.formSubmission?.result?.response
    if (response?.redirected && response.url) {
      const urlMatch = response.url.match(/\/sessions\/(\d+)/)
      if (urlMatch) {
        return { id: parseInt(urlMatch[1]) }
      }
    }

    // Fallback: try to get from current page URL after redirect
    setTimeout(() => {
      const currentUrlMatch = window.location.pathname.match(/\/sessions\/(\d+)/)
      if (currentUrlMatch) {
        const sessionData = { id: parseInt(currentUrlMatch[1]) }
        this.notifyPracticeTimer(sessionData)
      }
    }, 100)

    return null
  }

  notifyPracticeTimer(sessionData) {
    // Try multiple approaches to find and notify the practice timer controller
    console.log('Attempting to notify practice timer of successful upload:', sessionData)

    // Method 1: Direct controller property access
    const practiceTimerElement = document.querySelector('[data-controller*="practice-timer"]')
    if (practiceTimerElement) {
      // Try direct property access
      if (practiceTimerElement.practiceTimerController) {
        console.log('Method 1: Found practice timer via direct property')
        practiceTimerElement.practiceTimerController.onRecordingUploaded(sessionData)
        return
      }

      // Method 2: Use Stimulus application API
      const application = this.application
      if (application) {
        try {
          const controller = application.getControllerForElementAndIdentifier(practiceTimerElement, 'practice-timer')
          if (controller) {
            console.log('Method 2: Found practice timer via Stimulus API')
            controller.onRecordingUploaded(sessionData)
            return
          }
        } catch (e) {
          console.log('Method 2 failed:', e.message)
        }
      }

      // Method 3: Custom event dispatch
      console.log('Method 3: Dispatching custom event')
      const customEvent = new CustomEvent('recording:uploaded', {
        detail: sessionData,
        bubbles: true
      })
      practiceTimerElement.dispatchEvent(customEvent)
    }

    // Method 4: Global fallback using window
    if (window.practiceTimerController) {
      console.log('Method 4: Found practice timer via global reference')
      window.practiceTimerController.onRecordingUploaded(sessionData)
    } else {
      console.warn('Could not find practice timer controller to notify')
    }
  }

  resetSubmitButton() {
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = false
      const btnText = this.submitBtnTarget.querySelector('.btn-text')
      if (btnText) btnText.textContent = "📊 Analyze Recording"
      this.submitBtnTarget.classList.remove('uploading')
    }
  }

  showNotification(message, type = 'info', duration = 5000) {
    // Remove any existing notifications
    const existingNotifications = document.querySelectorAll('.recorder-notification')
    existingNotifications.forEach(n => n.remove())

    const notification = document.createElement('div')
    notification.className = `recorder-notification notification-${type}`
    notification.innerHTML = message // Use innerHTML to support emojis

    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 16px 24px;
      border-radius: 8px;
      color: white;
      font-weight: 500;
      z-index: 1001;
      max-width: 450px;
      box-shadow: 0 8px 25px rgba(0,0,0,0.2);
      animation: slideInRight 0.4s cubic-bezier(0.68, -0.55, 0.265, 1.55);
      font-size: 14px;
      line-height: 1.4;
    `

    // Set background color based on type
    switch (type) {
      case 'success':
        notification.style.backgroundColor = '#10b981'
        notification.style.borderLeft = '4px solid #059669'
        break
      case 'error':
        notification.style.backgroundColor = '#ef4444'
        notification.style.borderLeft = '4px solid #dc2626'
        break
      case 'warning':
        notification.style.backgroundColor = '#f59e0b'
        notification.style.borderLeft = '4px solid #d97706'
        break
      default:
        notification.style.backgroundColor = '#3b82f6'
        notification.style.borderLeft = '4px solid #2563eb'
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
}