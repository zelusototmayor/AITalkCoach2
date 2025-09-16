import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recordBtn", "status", "statusText", "indicator", "preview", "form", "timer", "progressBar", "videoPreview", "audioPreview", "fileInput", "submitBtn", "countdownDisplay", "durationInput"]
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
      this.updateUI("ready_to_submit")
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
    if (!this.hasFileInputTarget) return
    
    const file = new File([blob], this.generateFileName(), { 
      type: blob.type 
    })
    
    const dataTransfer = new DataTransfer()
    dataTransfer.items.add(file)
    
    this.fileInputTarget.files = dataTransfer.files
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
    
    switch (state) {
      case "ready":
        if (hasRecordBtn) {
          this.recordBtnTarget.disabled = false
          this.recordBtnTarget.querySelector('.btn-text').textContent = "Start Recording"
          this.recordBtnTarget.classList.remove('recording')
        }
        if (hasStatusText) this.statusTextTarget.textContent = "Ready to record"
        if (hasIndicator) this.indicatorTarget.className = "status-indicator ready"
        if (hasTimer) this.timerTarget.style.display = "none"
        if (hasSubmitBtn) this.submitBtnTarget.disabled = true
        break
        
      case "requesting":
        if (hasRecordBtn) this.recordBtnTarget.disabled = true
        if (hasStatusText) this.statusTextTarget.textContent = "Requesting camera/microphone access..."
        if (hasIndicator) this.indicatorTarget.className = "status-indicator requesting"
        break
        
      case "recording":
        if (hasRecordBtn) {
          this.recordBtnTarget.disabled = false
          this.recordBtnTarget.querySelector('.btn-text').textContent = "Stop Recording"
          this.recordBtnTarget.classList.add('recording')
        }
        if (hasStatusText) {
          this.statusTextTarget.textContent = `Recording... ${this.formatTime(this.maxDurationSecValue)} remaining`
          this.startRecordingTimer()
        }
        if (hasIndicator) this.indicatorTarget.className = "status-indicator recording"
        if (hasTimer) {
          this.timerTarget.style.display = "block"
          // Initialize countdown display
          if (this.hasCountdownDisplayTarget) {
            this.countdownDisplayTarget.textContent = this.formatTime(this.maxDurationSecValue)
          }
        }
        break
        
      case "processing":
        if (hasRecordBtn) this.recordBtnTarget.disabled = true
        if (hasStatusText) this.statusTextTarget.textContent = "Processing recording..."
        if (hasIndicator) this.indicatorTarget.className = "status-indicator processing"
        this.stopRecordingTimer()
        break
        
      case "ready_to_submit":
        if (hasRecordBtn) {
          this.recordBtnTarget.disabled = false
          this.recordBtnTarget.querySelector('.btn-text').textContent = "Record Again"
          this.recordBtnTarget.classList.remove('recording')
        }
        if (hasStatusText) this.statusTextTarget.textContent = "Recording ready! You can submit or record again."
        if (hasIndicator) this.indicatorTarget.className = "status-indicator ready"
        if (hasSubmitBtn) this.submitBtnTarget.disabled = false
        this.showPreview()
        break
        
      case "error":
        if (hasRecordBtn) {
          this.recordBtnTarget.disabled = false
          this.recordBtnTarget.querySelector('.btn-text').textContent = "Try Again"
          this.recordBtnTarget.classList.remove('recording')
        }
        if (hasStatusText) {
          this.statusTextTarget.textContent = `Error: ${message}`
          this.statusTextTarget.className = this.statusTextTarget.className.replace(/text-\w+-\d+/, 'text-red-600')
        }
        if (hasIndicator) this.indicatorTarget.className = "status-indicator error"
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
        
        if (remaining <= 10) {
          this.statusTextTarget.className = this.statusTextTarget.className.replace(/text-\w+-\d+/, 'text-orange-600')
        }
      }
      
      // Update countdown display
      if (this.hasCountdownDisplayTarget) {
        this.countdownDisplayTarget.textContent = this.formatTime(remaining)
        
        // Add visual warnings
        this.countdownDisplayTarget.classList.remove('warning', 'critical')
        if (remaining <= 10) {
          this.countdownDisplayTarget.classList.add('critical')
        } else if (remaining <= 30) {
          this.countdownDisplayTarget.classList.add('warning')
        }
      }
      
      // Update progress bar (countdown style)
      if (this.hasProgressBarTarget) {
        const progress = (remaining / this.maxDurationSecValue) * 100
        this.progressBarTarget.style.width = `${Math.max(progress, 0)}%`
        
        // Change color based on remaining time
        if (remaining <= 10) {
          this.progressBarTarget.style.background = '#dc2626'
        } else if (remaining <= 30) {
          this.progressBarTarget.style.background = '#f59e0b'
        } else {
          this.progressBarTarget.style.background = '#2563eb'
        }
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
    }
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
  }

  submitRecording() {
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.click()
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

  showNotification(message, type = 'info', duration = 5000) {
    // Remove any existing notifications
    const existingNotifications = document.querySelectorAll('.recorder-notification')
    existingNotifications.forEach(n => n.remove())

    const notification = document.createElement('div')
    notification.className = `recorder-notification notification-${type}`
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
}