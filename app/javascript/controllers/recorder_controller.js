import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recordBtn", "status", "statusText", "indicator", "preview", "form", "timer", "progressBar", "videoPreview", "audioPreview", "fileInput", "submitBtn", "countdownDisplay", "durationInput", "titleInput", "titleError", "languageSelect", "mediaKindSelect", "titleInputPreview", "languageSelectPreview", "mediaKindSelectPreview", "sessionConfig", "postRecordingActions", "recordingDuration", "recordingTarget"]
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

    // Listen for title generation events from prompts controller
    this.element.addEventListener('title-generated', this.handleTitleGenerated.bind(this))

    // Initialize duration input with default value
    if (this.hasDurationInputTarget && !this.durationInputTarget.value) {
      this.durationInputTarget.value = this.selectedDuration
    }

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
      const attachmentSuccess = this.attachToForm(blob)

      if (!attachmentSuccess) {
        this.updateUI("error", "Failed to attach recording file. Please try recording again.")
        this.releaseStream()
        return
      }

      // In practice timer mode, let practice timer handle the UI
      if (this.isPracticeTimerMode) {
        console.log('Recorder: Recording complete in practice timer mode')
        // Practice timer will show the new post-recording actions
      } else {
        // For standalone recorder, show the new post-recording actions
        this.showPostRecordingActions()
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
      return false
    }

    const file = new File([blob], this.generateFileName(), {
      type: blob.type
    })

    console.log('Attaching file to form:', file.name, file.size, 'bytes', 'blob type:', blob.type)

    // Try multiple attachment methods for better compatibility
    try {
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(file)
      this.fileInputTarget.files = dataTransfer.files
    } catch (e) {
      console.warn('DataTransfer method failed, trying direct assignment:', e)
      // Fallback: try setting files directly (may not work in all browsers)
      try {
        Object.defineProperty(this.fileInputTarget, 'files', {
          value: [file],
          writable: false
        })
      } catch (e2) {
        console.error('Direct file assignment also failed:', e2)
        return false
      }
    }

    // Verify the file was attached successfully with multiple checks
    const hasFiles = this.fileInputTarget.files && this.fileInputTarget.files.length > 0
    const hasValidFile = hasFiles && this.fileInputTarget.files[0].size > 0
    const typeMatches = hasValidFile && this.fileInputTarget.files[0].type === blob.type

    console.log('File attachment verification:', {
      hasFiles,
      hasValidFile,
      typeMatches,
      fileCount: this.fileInputTarget.files?.length || 0,
      fileSize: this.fileInputTarget.files?.[0]?.size || 0,
      fileType: this.fileInputTarget.files?.[0]?.type || 'none'
    })

    const attachedSuccessfully = hasFiles && hasValidFile

    if (attachedSuccessfully) {
      // Store reference to the blob for later verification
      this.attachedBlob = blob
      this.attachedFile = file
      console.log('✓ File successfully attached to form')
    } else {
      console.error('✗ File attachment failed')
    }

    return attachedSuccessfully
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

  showPostRecordingActions() {
    if (this.hasPostRecordingActionsTarget) {
      // Calculate recording duration
      const duration = this.startTime ? Math.floor((Date.now() - this.startTime) / 1000) : 0

      // Update duration display
      if (this.hasRecordingDurationTarget) {
        this.recordingDurationTarget.textContent = `Duration: ${duration}s`
      }

      // Show the post-recording actions with animation
      this.postRecordingActionsTarget.style.display = "block"
      this.postRecordingActionsTarget.style.opacity = "0"
      this.postRecordingActionsTarget.style.transform = "translateY(10px)"

      setTimeout(() => {
        this.postRecordingActionsTarget.style.transition = "all 0.3s ease-out"
        this.postRecordingActionsTarget.style.opacity = "1"
        this.postRecordingActionsTarget.style.transform = "translateY(0)"
      }, 50)

      // Scroll to the new actions smoothly
      setTimeout(() => {
        this.postRecordingActionsTarget.scrollIntoView({
          behavior: 'smooth',
          block: 'nearest'
        })
      }, 100)
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
    // Hide old preview
    if (this.hasPreviewTarget) {
      this.previewTarget.style.display = "none"
    }

    // Hide new post-recording actions
    if (this.hasPostRecordingActionsTarget) {
      this.postRecordingActionsTarget.style.display = "none"
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

      // Use AJAX submission to preserve the blob instead of traditional form submission
      setTimeout(() => {
        // Re-validate just before submission
        if (!this.validateRecording()) {
          this.resetSubmitButton()
          return
        }

        const form = submitBtn.closest('form')
        if (form) {
          this.submitFormWithAjax(form)
        } else {
          console.error('Form not found for submit button')
          this.showNotification('❌ Upload failed: Form not found', 'error')
          this.resetSubmitButton()
        }
      }, 250)
    } else {
      console.error('No submit button found')
      this.showNotification('❌ Upload failed: Submit button not found', 'error')
      this.resetSubmitButton()
    }
  }

  submitFormWithAjax(form) {
    try {
      // Create FormData from form
      const formData = new FormData(form)

      // Ensure the audio file is included in FormData
      if (this.attachedFile) {
        // Remove any existing media_files and add our blob
        formData.delete('session[media_files][]')
        formData.append('session[media_files][]', this.attachedFile, this.attachedFile.name)
        console.log('Added audio file to FormData:', this.attachedFile.name, this.attachedFile.size, 'bytes')
      } else if (this.attachedBlob) {
        // Fallback to blob if file not available
        formData.delete('session[media_files][]')
        const fileName = this.generateFileName()
        formData.append('session[media_files][]', this.attachedBlob, fileName)
        console.log('Added audio blob to FormData:', fileName, this.attachedBlob.size, 'bytes')
      } else {
        console.error('No audio file or blob available for submission')
        this.showNotification('❌ No recording found. Please record again.', 'error')
        this.resetSubmitButton()
        return
      }

      // Get CSRF token with better error handling
      const csrfMetaTag = document.querySelector('meta[name="csrf-token"]')
      const csrfToken = csrfMetaTag?.getAttribute('content')

      console.log('CSRF Meta Tag found:', !!csrfMetaTag)
      console.log('CSRF Token extracted:', csrfToken ? 'present' : 'missing')

      if (!csrfToken) {
        console.error('CSRF token not found - meta tag:', csrfMetaTag)
        this.showNotification('❌ Security token missing. Please refresh the page and try again.', 'error')
        this.resetSubmitButton()
        return
      }

      // Submit via fetch to preserve blob
      fetch(form.action, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': csrfToken,
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      .then(response => {
        console.log('Form submission response:', response)

        if (response.ok) {
          // Parse JSON response
          return response.json().then(data => {
            console.log('Response data:', data)

            if (data.success) {
              // Handle successful submission
              this.showNotification('✅ Recording uploaded successfully! Redirecting...', 'success')

              // Track analytics for trial or regular session completion
              this.trackSessionCompletion(data)

              // Notify practice timer if available
              if (data.session_id || data.trial_token) {
                const sessionData = {
                  id: data.session_id,
                  trial_token: data.trial_token
                }
                this.notifyPracticeTimer(sessionData)
              }

              // Redirect to the appropriate page
              if (data.redirect_url) {
                console.log('Following redirect to:', data.redirect_url)
                window.location.href = data.redirect_url
              } else {
                // Fallback redirect logic
                const isTrialMode = document.querySelector('.practice-interface.trial-mode') !== null
                if (isTrialMode) {
                  window.location.href = `/practice?trial=true&trial_results=true`
                } else {
                  window.location.href = '/practice'
                }
              }
            } else {
              // Handle unsuccessful response
              this.showNotification(`❌ ${data.message || 'Upload failed. Please try again.'}`, 'error')
              this.resetSubmitButton()
            }
          })
        } else {
          // Handle HTTP error responses
          return response.json().then(data => {
            console.error('Form submission failed:', response.status, data)

            let errorMessage = 'Upload failed. Please try again.'

            // Handle different types of errors
            if (response.status === 422) {
              if (data.errors && data.errors.length > 0) {
                errorMessage = data.errors.join(', ')
              } else if (data.message) {
                errorMessage = data.message
              } else {
                errorMessage = 'Validation failed. Please check your recording and try again.'
              }
            } else if (response.status === 403) {
              errorMessage = 'Session expired. Please refresh the page and try again.'
            } else if (data.message) {
              errorMessage = data.message
            }

            this.showNotification(`❌ ${errorMessage}`, 'error')
            this.resetSubmitButton()
          }).catch(() => {
            // Fallback if JSON parsing fails
            let errorMessage = 'Upload failed. Please try again.'
            if (response.status === 422) {
              errorMessage = 'Validation failed. Please refresh the page and try again.'
            } else if (response.status === 403) {
              errorMessage = 'Session expired. Please refresh the page and try again.'
            }
            this.showNotification(`❌ ${errorMessage}`, 'error')
            this.resetSubmitButton()
          })
        }
      })
      .catch(error => {
        console.error('Network error during form submission:', error)
        this.showNotification('❌ Network error. Please check your connection and try again.', 'error')
        this.resetSubmitButton()
      })

    } catch (error) {
      console.error('Error creating FormData or submitting:', error)
      this.showNotification('❌ Upload error. Please try recording again.', 'error')
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

      // Try to re-attach if we have the blob stored
      if (this.attachedBlob) {
        console.log('Attempting to re-attach blob to form')
        const reattachSuccess = this.attachToForm(this.attachedBlob)
        if (!reattachSuccess) {
          this.showNotification('Failed to re-attach recording. Please record again.', 'error')
          return false
        }

        // Give re-attachment a moment to complete, then verify immediately
        // Check if re-attachment worked immediately after the attempt
        if (!this.fileInputTarget.files || this.fileInputTarget.files.length === 0) {
          console.error('Re-attachment failed - still no files immediately after re-attach')
          this.showNotification('Recording attachment failed. Please record again.', 'error')
          return false
        }
      } else {
        this.showNotification('Please record audio before submitting', 'error')
        return false
      }
    }

    const file = this.fileInputTarget.files[0]
    if (!file || file.size === 0) {
      console.error('Recording file is empty')
      this.showNotification('Recording file is empty. Please record again.', 'error')
      return false
    }

    // Additional validation for trial mode
    const isTrialMode = document.querySelector('.practice-interface.trial-mode') !== null
    if (isTrialMode) {
      console.log('Trial mode recording validation:', {
        fileName: file.name,
        fileSize: file.size,
        fileType: file.type,
        lastModified: new Date(file.lastModified).toISOString()
      })

      // Ensure minimum file size for trial recordings
      if (file.size < 1000) { // Less than 1KB probably indicates an issue
        console.error('Trial recording file too small, likely corrupted')
        this.showNotification('Recording seems corrupted. Please record again.', 'error')
        return false
      }
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

  toggleSessionConfig() {
    if (!this.hasSessionConfigTarget) return

    const content = this.sessionConfigTarget
    const header = content.previousElementSibling
    const icon = header.querySelector('.config-toggle-icon')

    if (content.style.display === 'none' || content.style.display === '') {
      content.style.display = 'block'
      content.style.opacity = '0'
      content.style.maxHeight = '0'
      content.style.overflow = 'hidden'
      content.style.transition = 'all 0.3s ease-out'

      // Trigger animation
      setTimeout(() => {
        content.style.opacity = '1'
        content.style.maxHeight = '500px'
      }, 10)

      if (icon) icon.textContent = '▲'
    } else {
      content.style.opacity = '0'
      content.style.maxHeight = '0'

      setTimeout(() => {
        content.style.display = 'none'
      }, 300)

      if (icon) icon.textContent = '▼'
    }
  }

  handleTitleGenerated(event) {
    const { title } = event.detail

    // Update the title input if we have one
    if (this.hasTitleInputTarget) {
      this.titleInputTarget.value = title
    }

    // Clear any title errors since we now have a valid title
    this.clearTitleError()
  }

  trackSessionCompletion(data) {
    // Get analytics controller from global reference
    const analytics = window.analyticsController
    if (!analytics) {
      console.warn('Analytics controller not available for session completion tracking')
      return
    }

    // Calculate session duration if available
    const duration_seconds = this.startTime ? Math.floor((Date.now() - this.startTime) / 1000) : null
    const target_seconds = this.selectedDuration || this.maxDurationSecValue

    // Check if this is a trial or regular session
    const isTrialMode = data.trial_token || document.querySelector('.practice-interface.trial-mode')

    if (isTrialMode) {
      // Track trial completion
      analytics.trackTrialCompleted(duration_seconds, target_seconds)
    } else {
      // Track regular session completion
      const sessionData = {
        duration_seconds: duration_seconds,
        target_seconds: target_seconds,
        session_id: data.session_id
      }
      analytics.trackRealSessionCompleted(sessionData)
    }
  }

  cancelRecording() {
    console.log('Recorder: Cancelling recording session')

    // Stop any active recording
    if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
      this.mediaRecorder.stop()
    }

    // Clear timers
    if (this.maxDurationTimer) {
      clearTimeout(this.maxDurationTimer)
      this.maxDurationTimer = null
    }

    this.stopRecordingTimer()

    // Release media stream
    this.releaseStream()

    // Clear recorded data
    this.recordedChunks = []
    this.attachedBlob = null
    this.attachedFile = null

    // Clear file input
    if (this.hasFileInputTarget) {
      this.fileInputTarget.value = ''
    }

    // Hide previews
    if (this.hasVideoPreviewTarget) {
      this.videoPreviewTarget.style.display = "none"
      this.videoPreviewTarget.src = ""
    }

    if (this.hasAudioPreviewTarget) {
      this.audioPreviewTarget.style.display = "none"
      this.audioPreviewTarget.src = ""
    }

    // Hide preview and post-recording sections
    if (this.hasPreviewTarget) {
      this.previewTarget.style.display = "none"
    }

    if (this.hasPostRecordingActionsTarget) {
      this.postRecordingActionsTarget.style.display = "none"
    }

    // Reset UI to ready state
    this.updateUI("ready")

    console.log('Recorder: Recording cancelled and state reset')
  }
}