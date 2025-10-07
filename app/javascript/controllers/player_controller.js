import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "media", "playButton", "pauseButton", "timeline", "currentTime", 
    "duration", "volumeSlider", "speedSelect", "issueMarkers", "progressBar"
  ]
  static values = { 
    issues: Array,
    autoplay: Boolean,
    showMarkers: Boolean,
    allowSpeedControl: Boolean
  }

  initialize() {
    this.updateInterval = null
    this.wasPlayingBeforeSeek = false
    this.issueColors = {
      'filler_words': '#ef4444',
      'pace_too_fast': '#f97316', 
      'pace_too_slow': '#3b82f6',
      'long_pause': '#8b5cf6',
      'unclear_speech': '#ec4899',
      'repetition': '#10b981',
      'volume_low': '#6b7280',
      'volume_inconsistent': '#f59e0b'
    }
  }

  connect() {
    this.issuesValue = this.issuesValue || []
    this.showMarkersValue = this.showMarkersValue ?? true
    this.allowSpeedControlValue = this.allowSpeedControlValue ?? true

    this.setupEventListeners()
    this.setupKeyboardShortcuts()
    this.renderIssueMarkers()
    this.updateDurationDisplay()
    
    if (this.autoplayValue && this.hasMediaTarget) {
      this.mediaTarget.autoplay = true
    }
  }

  disconnect() {
    this.stopUpdateLoop()
    this.removeKeyboardShortcuts()
  }

  setupEventListeners() {
    if (!this.hasMediaTarget) return

    this.mediaTarget.addEventListener('loadedmetadata', () => {
      this.updateDurationDisplay()
      this.renderIssueMarkers()
    })

    this.mediaTarget.addEventListener('timeupdate', () => {
      this.updateProgress()
    })

    this.mediaTarget.addEventListener('play', () => {
      this.onPlay()
    })

    this.mediaTarget.addEventListener('pause', () => {
      this.onPause()
    })

    this.mediaTarget.addEventListener('ended', () => {
      this.onEnded()
    })

    this.mediaTarget.addEventListener('error', (e) => {
      console.error('Media playback error:', e)
    })

    if (this.hasTimelineTarget) {
      this.timelineTarget.addEventListener('input', (e) => {
        this.seekTo(parseFloat(e.target.value))
      })

      this.timelineTarget.addEventListener('mousedown', () => {
        this.wasPlayingBeforeSeek = !this.mediaTarget.paused
        this.pause()
      })

      this.timelineTarget.addEventListener('mouseup', () => {
        if (this.wasPlayingBeforeSeek) {
          this.play()
        }
      })
    }

    if (this.hasVolumeSliderTarget) {
      this.volumeSliderTarget.addEventListener('input', (e) => {
        this.setVolume(parseFloat(e.target.value))
      })
    }

    if (this.hasSpeedSelectTarget) {
      this.speedSelectTarget.addEventListener('change', (e) => {
        this.setPlaybackRate(parseFloat(e.target.value))
      })
    }
  }

  setupKeyboardShortcuts() {
    this.keydownHandler = (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return

      switch (e.code) {
        case 'Space':
          e.preventDefault()
          this.togglePlayPause()
          break
        case 'ArrowLeft':
          e.preventDefault()
          this.skipBackward(5)
          break
        case 'ArrowRight':
          e.preventDefault()
          this.skipForward(5)
          break
        case 'ArrowUp':
          e.preventDefault()
          this.adjustVolume(0.1)
          break
        case 'ArrowDown':
          e.preventDefault()
          this.adjustVolume(-0.1)
          break
        case 'KeyM':
          e.preventDefault()
          this.toggleMute()
          break
      }
    }

    document.addEventListener('keydown', this.keydownHandler)
  }

  removeKeyboardShortcuts() {
    if (this.keydownHandler) {
      document.removeEventListener('keydown', this.keydownHandler)
    }
  }

  play() {
    if (this.hasMediaTarget) {
      this.mediaTarget.play()
    }
  }

  pause() {
    if (this.hasMediaTarget) {
      this.mediaTarget.pause()
    }
  }

  togglePlayPause() {
    if (!this.hasMediaTarget) return

    if (this.mediaTarget.paused) {
      this.play()
    } else {
      this.pause()
    }
  }

  seekTo(eventOrTime) {
    // Handle both direct time parameter and event with data-timestamp
    let time;
    if (typeof eventOrTime === 'number') {
      time = eventOrTime;
    } else if (eventOrTime && eventOrTime.currentTarget) {
      // Extract timestamp from data attribute and convert ms to seconds
      const timestamp = eventOrTime.currentTarget.dataset.timestamp;
      time = timestamp ? parseFloat(timestamp) / 1000 : 0;
    } else if (eventOrTime && eventOrTime.params && eventOrTime.params.time) {
      // Handle Stimulus params format
      time = parseFloat(eventOrTime.params.time);
    } else {
      time = parseFloat(eventOrTime) || 0;
    }

    if (this.hasMediaTarget) {
      this.mediaTarget.currentTime = time;
    }
  }

  skipForward(seconds = 10) {
    if (this.hasMediaTarget) {
      this.mediaTarget.currentTime = Math.min(
        this.mediaTarget.currentTime + seconds,
        this.mediaTarget.duration
      )
    }
  }

  skipBackward(seconds = 10) {
    if (this.hasMediaTarget) {
      this.mediaTarget.currentTime = Math.max(
        this.mediaTarget.currentTime - seconds,
        0
      )
    }
  }

  setVolume(volume) {
    if (this.hasMediaTarget) {
      this.mediaTarget.volume = Math.max(0, Math.min(1, volume))
    }
  }

  adjustVolume(delta) {
    if (this.hasMediaTarget) {
      const newVolume = this.mediaTarget.volume + delta
      this.setVolume(newVolume)
      
      if (this.hasVolumeSliderTarget) {
        this.volumeSliderTarget.value = this.mediaTarget.volume
      }
    }
  }

  toggleMute() {
    if (this.hasMediaTarget) {
      this.mediaTarget.muted = !this.mediaTarget.muted
    }
  }

  setPlaybackRate(rate) {
    if (this.hasMediaTarget) {
      this.mediaTarget.playbackRate = rate
    }
  }

  onPlay() {
    this.startUpdateLoop()
    
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.style.display = 'none'
    }
    if (this.hasPauseButtonTarget) {
      this.pauseButtonTarget.style.display = 'inline-block'
    }
  }

  onPause() {
    this.stopUpdateLoop()
    
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.style.display = 'inline-block'
    }
    if (this.hasPauseButtonTarget) {
      this.pauseButtonTarget.style.display = 'none'
    }
  }

  onEnded() {
    this.stopUpdateLoop()
    this.onPause()
    
    if (this.hasTimelineTarget) {
      this.timelineTarget.value = 0
    }
  }

  startUpdateLoop() {
    if (this.updateInterval) return
    
    this.updateInterval = setInterval(() => {
      this.updateProgress()
    }, 100)
  }

  stopUpdateLoop() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
      this.updateInterval = null
    }
  }

  updateProgress() {
    if (!this.hasMediaTarget) return

    const currentTime = this.mediaTarget.currentTime
    const duration = this.mediaTarget.duration

    if (this.hasTimelineTarget && !isNaN(duration)) {
      this.timelineTarget.max = duration
      this.timelineTarget.value = currentTime
    }

    if (this.hasProgressBarTarget && !isNaN(duration)) {
      const percentage = (currentTime / duration) * 100
      this.progressBarTarget.style.width = `${percentage}%`
    }

    if (this.hasCurrentTimeTarget) {
      this.currentTimeTarget.textContent = this.formatTime(currentTime)
    }

    this.highlightActiveIssues(currentTime)
  }

  updateDurationDisplay() {
    if (!this.hasMediaTarget || !this.hasDurationTarget) return

    const duration = this.mediaTarget.duration
    if (!isNaN(duration)) {
      this.durationTarget.textContent = this.formatTime(duration)
    }
  }

  renderIssueMarkers() {
    if (!this.showMarkersValue || !this.hasIssueMarkersTarget || !this.hasMediaTarget) return

    const duration = this.mediaTarget.duration
    if (isNaN(duration) || duration === 0) return

    this.issueMarkersTarget.innerHTML = ''

    this.issuesValue.forEach((issue, index) => {
      const marker = this.createIssueMarker(issue, index, duration)
      this.issueMarkersTarget.appendChild(marker)
    })
  }

  createIssueMarker(issue, index, duration) {
    const marker = document.createElement('div')
    const startPercent = (issue.start_ms / duration) * 100
    const widthPercent = Math.max(0.5, ((issue.end_ms - issue.start_ms) / duration) * 100)

    marker.className = 'absolute h-full cursor-pointer hover:opacity-80 transition-opacity'
    marker.style.left = `${startPercent}%`
    marker.style.width = `${widthPercent}%`
    marker.style.backgroundColor = this.issueColors[issue.kind] || '#6b7280'
    marker.style.zIndex = '10'

    marker.title = `${issue.kind.replace('_', ' ').toUpperCase()}: ${issue.text}`
    
    marker.addEventListener('click', () => {
      this.seekToIssue(issue)
    })

    marker.dataset.issueIndex = index
    marker.dataset.issueType = issue.kind

    return marker
  }

  seekToIssue(issue) {
    this.seekTo(issue.start_ms / 1000) // Convert milliseconds to seconds
    this.play()
  }

  highlightActiveIssues(currentTime) {
    if (!this.hasIssueMarkersTarget) return

    const markers = this.issueMarkersTarget.querySelectorAll('[data-issue-index]')
    
    markers.forEach((marker) => {
      const index = parseInt(marker.dataset.issueIndex)
      const issue = this.issuesValue[index]
      
      if (issue && currentTime >= (issue.start_ms / 1000) && currentTime <= (issue.end_ms / 1000)) {
        marker.classList.add('ring-2', 'ring-white', 'ring-opacity-70')
      } else {
        marker.classList.remove('ring-2', 'ring-white', 'ring-opacity-70')
      }
    })
  }

  jumpToIssue(event) {
    const index = parseInt(event.params.index)
    const issue = this.issuesValue[index]
    
    if (issue) {
      this.seekToIssue(issue)
    }
  }

  jumpToTime(event) {
    const time = parseFloat(event.params.time)
    this.seekTo(time)
  }

  formatTime(seconds) {
    if (isNaN(seconds)) return '0:00'
    
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = Math.floor(seconds % 60)

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
    } else {
      return `${minutes}:${secs.toString().padStart(2, '0')}`
    }
  }

  getIssuesByType(type) {
    return this.issuesValue.filter(issue => issue.kind === type)
  }

  getCurrentIssues() {
    const currentTime = this.mediaTarget ? this.mediaTarget.currentTime : 0
    return this.issuesValue.filter(issue => 
      currentTime >= (issue.start_ms / 1000) && currentTime <= (issue.end_ms / 1000)
    )
  }

  export() {
    const data = {
      issues: this.issuesValue,
      duration: this.hasMediaTarget ? this.mediaTarget.duration : 0,
      currentTime: this.hasMediaTarget ? this.mediaTarget.currentTime : 0
    }
    
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    
    const a = document.createElement('a')
    a.href = url
    a.download = 'session-data.json'
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    
    URL.revokeObjectURL(url)
  }
}