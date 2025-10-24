import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    sessionId: Number,
    pollInterval: Number
  }

  static targets = [
    "timelineStep",
    "progressBar",
    "progressText",
    "statusTitle",
    "statusDescription",
    "metricsArea",
    "metricTemplate",
    "tipsCarousel",
    "tipText",
    "timeEstimate",
    "estimatedTime"
  ]

  initialize() {
    this.pollIntervalValue = this.pollIntervalValue || 3000
    this.pollTimer = null
    this.isPolling = false
    this.displayedMetrics = new Set()
    this.currentTipIndex = 0
    this.tipRotationTimer = null

    // Coaching tips to rotate through
    this.coachingTips = [
      "💡 Professional speakers use less than 3% filler words",
      "🎯 Natural speaking pace is 140-180 words per minute",
      "⏸️ Strategic pauses improve clarity by up to 25%",
      "🗣️ Vocal variety keeps audiences engaged longer",
      "📊 Top communicators practice 3-5 times per week",
      "✨ Clear articulation is more important than speed",
      "🎤 Confidence grows with consistent practice",
      "💬 Concise messages are remembered 40% better"
    ]
  }

  connect() {
    console.log('[Enhanced Progress] Controller connected')
    this.startPolling()
    this.startTipRotation()
  }

  disconnect() {
    this.stopPolling()
    this.stopTipRotation()
  }

  startPolling() {
    if (this.isPolling || !this.sessionIdValue) return

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
      const response = await fetch(`/api/sessions/${this.sessionIdValue}/status`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`Status check failed: ${response.status}`)
      }

      const data = await response.json()
      console.log('[Enhanced Progress] Status data:', data)

      this.updateProgress(data)

      // Stop polling if completed or failed
      if (data.processing_state === 'completed' || data.processing_state === 'failed') {
        console.log('[Enhanced Progress] Stopping polling - session completed')
        this.stopPolling()

        if (data.processing_state === 'completed') {
          this.schedulePageRefresh()
        }
      }

    } catch (error) {
      console.error('[Enhanced Progress] Polling error:', error)
      this.stopPolling()
    }
  }

  updateProgress(data) {
    const { progress_info, interim_metrics, processing_stage } = data

    // Update timeline steps
    if (processing_stage) {
      this.updateTimelineSteps(processing_stage)
    }

    // Update progress bar
    if (progress_info?.progress !== undefined) {
      this.updateProgressBar(progress_info.progress)
    }

    // Update status text
    if (progress_info?.step) {
      this.updateStatusText(progress_info.step)
    }

    // Update estimated time
    if (progress_info?.estimated_time && this.hasEstimatedTimeTarget) {
      this.estimatedTimeTarget.textContent = progress_info.estimated_time
    }

    // Display interim metrics as they become available
    if (interim_metrics && Object.keys(interim_metrics).length > 0) {
      this.displayInterimMetrics(interim_metrics)
    }
  }

  updateTimelineSteps(currentStage) {
    const stages = ['extraction', 'transcription', 'analysis', 'refinement']
    const currentIndex = stages.indexOf(currentStage)

    this.timelineStepTargets.forEach((step, index) => {
      const stepStage = step.dataset.step
      const stepIndex = stages.indexOf(stepStage)

      // Remove all state classes
      step.classList.remove('active', 'completed')

      if (stepIndex < currentIndex) {
        // Previous steps are completed
        step.classList.add('completed')
        step.querySelector('.step-status').textContent = 'Done'
      } else if (stepIndex === currentIndex) {
        // Current step is active
        step.classList.add('active')
        step.querySelector('.step-status').textContent = 'Active'
      } else {
        // Future steps remain pending
        step.querySelector('.step-status').textContent = 'Pending'
      }
    })

    // Update timeline connectors
    const connectors = this.element.querySelectorAll('.timeline-connector')
    connectors.forEach((connector, index) => {
      if (index < currentIndex) {
        connector.classList.add('completed')
      } else {
        connector.classList.remove('completed')
      }
    })
  }

  updateProgressBar(progress) {
    if (!this.hasProgressBarTarget) return

    this.progressBarTarget.style.width = `${progress}%`
    this.progressBarTarget.setAttribute('aria-valuenow', progress)

    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${Math.round(progress)}%`
    }
  }

  updateStatusText(statusMessage) {
    if (this.hasStatusTitleTarget) {
      this.statusTitleTarget.textContent = statusMessage
    }
  }

  displayInterimMetrics(metrics) {
    if (!this.hasMetricsAreaTarget || !this.hasMetricTemplateTarget) return

    // Define metric configurations
    const metricConfigs = {
      duration_seconds: {
        icon: '⏱️',
        label: 'Duration',
        format: (val) => `${Math.round(val)}s`,
        note: 'Recording length'
      },
      word_count: {
        icon: '📝',
        label: 'Words',
        format: (val) => val.toString(),
        note: 'Total words detected'
      },
      estimated_wpm: {
        icon: '🎤',
        label: 'Speaking Pace',
        format: (val) => `${val} WPM`,
        note: 'Words per minute'
      },
      filler_word_count: {
        icon: '🔍',
        label: 'Filler Words',
        format: (val) => val.toString(),
        note: 'Detected instances'
      },
      pause_count: {
        icon: '⏸️',
        label: 'Long Pauses',
        format: (val) => val.toString(),
        note: 'Pauses detected'
      }
    }

    // Display new metrics
    Object.entries(metrics).forEach(([key, value]) => {
      if (this.displayedMetrics.has(key) || !metricConfigs[key]) return
      if (value === null || value === undefined || value === 0) return

      const config = metricConfigs[key]
      this.addMetricCard(key, value, config)
      this.displayedMetrics.add(key)
    })
  }

  addMetricCard(key, value, config) {
    const template = this.metricTemplateTarget.content.cloneNode(true)
    const card = template.querySelector('.metric-card-progressive')

    card.dataset.metricKey = key
    card.querySelector('.metric-icon').textContent = config.icon
    card.querySelector('.metric-label').textContent = config.label
    card.querySelector('.metric-value').textContent = config.format(value)
    card.querySelector('.metric-value').classList.add('counting')
    card.querySelector('.metric-note').textContent = config.note

    // Add with animation
    this.metricsAreaTarget.appendChild(card)

    // Trigger animation
    setTimeout(() => {
      card.style.animationPlayState = 'running'
    }, 100)
  }

  startTipRotation() {
    // Show first tip immediately
    this.showNextTip()

    // Rotate tips every 6 seconds
    this.tipRotationTimer = setInterval(() => {
      this.showNextTip()
    }, 6000)
  }

  stopTipRotation() {
    if (this.tipRotationTimer) {
      clearInterval(this.tipRotationTimer)
      this.tipRotationTimer = null
    }
  }

  showNextTip() {
    if (!this.hasTipTextTarget) return

    const tipElement = this.tipTextTarget

    // Fade out current tip
    tipElement.classList.add('fading')

    setTimeout(() => {
      // Update to next tip
      this.currentTipIndex = (this.currentTipIndex + 1) % this.coachingTips.length
      tipElement.textContent = this.coachingTips[this.currentTipIndex]

      // Fade in new tip
      tipElement.classList.remove('fading')
    }, 300)
  }

  schedulePageRefresh() {
    setTimeout(() => {
      window.location.reload()
    }, 1000)
  }
}
