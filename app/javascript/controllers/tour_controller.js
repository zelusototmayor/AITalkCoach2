import { Controller } from "@hotwired/stimulus"

// Global flag to prevent multiple tour instances
let activeTourController = null

export default class extends Controller {
  static values = {
    name: String,
    steps: Array,
    autoStart: { type: Boolean, default: true }
  }

  connect() {
    this.currentStep = 0
    this.isActive = false

    // Bind keyboard handler
    this.handleKeydown = this.handleKeydown.bind(this)

    // Auto-start tour after a brief delay to let page render
    if (this.autoStartValue && this.stepsValue.length > 0) {
      setTimeout(() => this.start(), 500)
    }
  }

  disconnect() {
    this.cleanup()
  }

  start() {
    if (this.isActive || this.stepsValue.length === 0) return

    // If another tour is active, clean it up first
    if (activeTourController && activeTourController !== this) {
      activeTourController.cleanup()
    }

    // Clean up any existing tour overlays (prevents duplicates from Turbo navigation)
    document.querySelectorAll('.tour-overlay').forEach(el => el.remove())

    activeTourController = this
    this.isActive = true
    this.currentStep = 0

    // Track tour started
    this.trackEvent('tour_started', { tour_name: this.nameValue })

    // Create overlay
    this.createOverlay()

    // Add keyboard listener
    document.addEventListener('keydown', this.handleKeydown)

    // Show first step
    this.showStep(0)
  }

  createOverlay() {
    // Create the overlay container
    this.overlay = document.createElement('div')
    this.overlay.className = 'tour-overlay'
    this.overlay.innerHTML = `
      <div class="tour-backdrop"></div>
      <div class="tour-spotlight"></div>
      <div class="tour-popover">
        <div class="tour-popover-header">
          <span class="tour-step-title"></span>
          <button class="tour-close-btn" aria-label="Close tour">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
        </div>
        <div class="tour-popover-content"></div>
        <div class="tour-popover-footer">
          <div class="tour-progress"></div>
          <div class="tour-navigation">
            <button class="tour-btn tour-btn-secondary tour-prev-btn">Previous</button>
            <button class="tour-btn tour-btn-primary tour-next-btn">Next</button>
          </div>
        </div>
      </div>
    `

    document.body.appendChild(this.overlay)

    // Store references to key elements
    this.backdrop = this.overlay.querySelector('.tour-backdrop')
    this.spotlight = this.overlay.querySelector('.tour-spotlight')
    this.popover = this.overlay.querySelector('.tour-popover')
    this.titleEl = this.overlay.querySelector('.tour-step-title')
    this.contentEl = this.overlay.querySelector('.tour-popover-content')
    this.progressEl = this.overlay.querySelector('.tour-progress')
    this.prevBtn = this.overlay.querySelector('.tour-prev-btn')
    this.nextBtn = this.overlay.querySelector('.tour-next-btn')
    this.closeBtn = this.overlay.querySelector('.tour-close-btn')

    // Attach event listeners directly (since overlay is outside controller scope)
    this.backdrop.addEventListener('click', () => this.skip())
    this.closeBtn.addEventListener('click', () => this.skip())
    this.prevBtn.addEventListener('click', () => this.previous())
    this.nextBtn.addEventListener('click', () => this.next())
  }

  showStep(index) {
    const step = this.stepsValue[index]
    if (!step) return

    // Track step viewed
    this.trackEvent('tour_step_viewed', {
      tour_name: this.nameValue,
      step_number: index + 1,
      step_title: step.title
    })

    // Update content
    this.titleEl.textContent = step.title
    this.contentEl.innerHTML = step.content

    // Update progress dots
    this.updateProgress(index)

    // Update navigation buttons
    this.prevBtn.style.display = index === 0 ? 'none' : 'inline-flex'

    if (index === this.stepsValue.length - 1) {
      this.nextBtn.textContent = 'Got it!'
      this.nextBtn.classList.add('tour-btn-success')
    } else {
      this.nextBtn.textContent = 'Next'
      this.nextBtn.classList.remove('tour-btn-success')
    }

    // Position spotlight and popover
    const targetEl = document.querySelector(step.target)
    if (targetEl) {
      // Check if element is in viewport
      const rect = targetEl.getBoundingClientRect()
      const isInViewport = rect.top >= 0 && rect.bottom <= window.innerHeight

      if (!isInViewport) {
        // Scroll element into view first, then position after scroll completes
        targetEl.scrollIntoView({ behavior: 'smooth', block: 'center' })
        // Wait for scroll to complete before positioning
        setTimeout(() => {
          this.positionSpotlightAndPopover(targetEl, step.position || 'bottom')
        }, 400)
      } else {
        // Element already visible, position immediately
        this.positionSpotlightAndPopover(targetEl, step.position || 'bottom')
      }
    } else {
      // If target not found, center the popover
      this.hideSpotlight()
      this.centerPopover()
    }
  }

  positionSpotlightAndPopover(targetEl, position) {
    this.positionSpotlight(targetEl)
    this.positionPopover(targetEl, position)
  }

  updateProgress(currentIndex) {
    const totalSteps = this.stepsValue.length
    let dotsHtml = ''

    for (let i = 0; i < totalSteps; i++) {
      const activeClass = i === currentIndex ? 'active' : ''
      const completedClass = i < currentIndex ? 'completed' : ''
      dotsHtml += `<span class="tour-progress-dot ${activeClass} ${completedClass}"></span>`
    }

    this.progressEl.innerHTML = dotsHtml
  }

  positionSpotlight(targetEl) {
    const rect = targetEl.getBoundingClientRect()
    const padding = 8

    // Use fixed positioning with current viewport-relative coordinates
    this.spotlight.style.display = 'block'
    this.spotlight.style.position = 'fixed'
    this.spotlight.style.top = `${rect.top - padding}px`
    this.spotlight.style.left = `${rect.left - padding}px`
    this.spotlight.style.width = `${rect.width + padding * 2}px`
    this.spotlight.style.height = `${rect.height + padding * 2}px`
  }

  hideSpotlight() {
    this.spotlight.style.display = 'none'
  }

  positionPopover(targetEl, position) {
    const targetRect = targetEl.getBoundingClientRect()
    const popoverRect = this.popover.getBoundingClientRect()
    const spacing = 16

    let top, left

    // Use viewport-relative coordinates for fixed positioning
    switch (position) {
      case 'top':
        top = targetRect.top - popoverRect.height - spacing
        left = targetRect.left + (targetRect.width / 2) - (popoverRect.width / 2)
        break
      case 'bottom':
        top = targetRect.bottom + spacing
        left = targetRect.left + (targetRect.width / 2) - (popoverRect.width / 2)
        break
      case 'left':
        top = targetRect.top + (targetRect.height / 2) - (popoverRect.height / 2)
        left = targetRect.left - popoverRect.width - spacing
        break
      case 'right':
        top = targetRect.top + (targetRect.height / 2) - (popoverRect.height / 2)
        left = targetRect.right + spacing
        break
      default:
        top = targetRect.bottom + spacing
        left = targetRect.left + (targetRect.width / 2) - (popoverRect.width / 2)
    }

    // Keep popover within viewport
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight

    // Horizontal bounds
    if (left < spacing) left = spacing
    if (left + popoverRect.width > viewportWidth - spacing) {
      left = viewportWidth - popoverRect.width - spacing
    }

    // Vertical bounds - if too low, position above
    if (top + popoverRect.height > viewportHeight - spacing) {
      top = targetRect.top - popoverRect.height - spacing
    }
    if (top < spacing) {
      top = spacing
    }

    this.popover.style.position = 'fixed'
    this.popover.style.top = `${top}px`
    this.popover.style.left = `${left}px`
    this.popover.style.transform = 'none'

    // Add position class for arrow
    this.popover.className = `tour-popover tour-popover-${position}`
  }

  centerPopover() {
    this.popover.style.position = 'fixed'
    this.popover.style.top = '50%'
    this.popover.style.left = '50%'
    this.popover.style.transform = 'translate(-50%, -50%)'
    this.popover.className = 'tour-popover tour-popover-centered'
  }

  next() {
    if (this.currentStep < this.stepsValue.length - 1) {
      this.currentStep++
      this.showStep(this.currentStep)
    } else {
      this.complete()
    }
  }

  previous() {
    if (this.currentStep > 0) {
      this.currentStep--
      this.showStep(this.currentStep)
    }
  }

  skip() {
    this.trackEvent('tour_skipped', {
      tour_name: this.nameValue,
      skipped_at_step: this.currentStep + 1
    })
    this.finish()
  }

  complete() {
    this.trackEvent('tour_completed', { tour_name: this.nameValue })
    this.finish()
  }

  async finish() {
    // Mark tour as complete on server
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      await fetch(`/tours/${this.nameValue}/complete`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken,
          'Content-Type': 'application/json'
        }
      })
    } catch (error) {
      console.error('Failed to save tour completion:', error)
    }

    this.cleanup()
  }

  handleBackdropClick(event) {
    // Clicking backdrop skips the tour
    this.skip()
  }

  handleKeydown(event) {
    if (!this.isActive) return

    switch (event.key) {
      case 'Escape':
        this.skip()
        break
      case 'ArrowRight':
      case 'Enter':
        this.next()
        break
      case 'ArrowLeft':
        this.previous()
        break
    }
  }

  cleanup() {
    this.isActive = false

    // Clear global reference if this is the active controller
    if (activeTourController === this) {
      activeTourController = null
    }

    // Remove keyboard listener
    document.removeEventListener('keydown', this.handleKeydown)

    // Remove overlay from DOM
    if (this.overlay && this.overlay.parentNode) {
      this.overlay.parentNode.removeChild(this.overlay)
    }
    this.overlay = null
    this.backdrop = null
    this.spotlight = null
    this.popover = null

    // Reset scroll position to top
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  trackEvent(eventName, properties = {}) {
    // Use existing analytics controller if available
    if (typeof mixpanel !== 'undefined') {
      mixpanel.track(eventName, properties)
    }
  }
}
