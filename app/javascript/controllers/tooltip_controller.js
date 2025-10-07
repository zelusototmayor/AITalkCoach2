import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = {
    position: { type: String, default: "top" }, // top, bottom, left, right
    delay: { type: Number, default: 200 }
  }

  initialize() {
    this.showTimeout = null
    this.hideTimeout = null
  }

  connect() {
    console.log("Tooltip controller connected")
  }

  show(event) {
    // Clear any pending hide timeout
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }

    // Add delay before showing
    this.showTimeout = setTimeout(() => {
      if (this.hasContentTarget) {
        // Make visible first to get accurate dimensions
        this.contentTarget.classList.remove("hidden")
        this.contentTarget.classList.add("visible")

        // Position after next frame to ensure dimensions are calculated
        requestAnimationFrame(() => {
          this.positionTooltip(event.currentTarget)
        })
      }
    }, this.delayValue)
  }

  hide() {
    // Clear any pending show timeout
    if (this.showTimeout) {
      clearTimeout(this.showTimeout)
      this.showTimeout = null
    }

    // Add small delay before hiding to prevent flicker
    this.hideTimeout = setTimeout(() => {
      if (this.hasContentTarget) {
        this.contentTarget.classList.remove("visible")
        this.contentTarget.classList.add("hidden")
      }
    }, 100)
  }

  toggle(event) {
    if (this.hasContentTarget) {
      if (this.contentTarget.classList.contains("hidden")) {
        this.show(event || { currentTarget: this.element })
      } else {
        this.hide()
      }
    }
  }

  positionTooltip(trigger) {
    if (!this.hasContentTarget) return

    const tooltip = this.contentTarget
    const triggerRect = trigger.getBoundingClientRect()
    const tooltipRect = tooltip.getBoundingClientRect()

    let top, left

    switch (this.positionValue) {
      case "top":
        top = triggerRect.top - tooltipRect.height - 8
        left = triggerRect.left + (triggerRect.width - tooltipRect.width) / 2
        break
      case "bottom":
        top = triggerRect.bottom + 8
        left = triggerRect.left + (triggerRect.width - tooltipRect.width) / 2
        break
      case "left":
        top = triggerRect.top + (triggerRect.height - tooltipRect.height) / 2
        left = triggerRect.left - tooltipRect.width - 8
        break
      case "right":
        top = triggerRect.top + (triggerRect.height - tooltipRect.height) / 2
        left = triggerRect.right + 8
        break
      default:
        top = triggerRect.top - tooltipRect.height - 8
        left = triggerRect.left + (triggerRect.width - tooltipRect.width) / 2
    }

    // Keep tooltip within viewport
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight

    if (left < 8) left = 8
    if (left + tooltipRect.width > viewportWidth - 8) {
      left = viewportWidth - tooltipRect.width - 8
    }
    if (top < 8) top = 8
    if (top + tooltipRect.height > viewportHeight - 8) {
      top = viewportHeight - tooltipRect.height - 8
    }

    tooltip.style.top = `${top}px`
    tooltip.style.left = `${left}px`
  }

  disconnect() {
    if (this.showTimeout) clearTimeout(this.showTimeout)
    if (this.hideTimeout) clearTimeout(this.hideTimeout)
  }
}
