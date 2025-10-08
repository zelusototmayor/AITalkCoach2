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

  disconnect() {
    if (this.showTimeout) clearTimeout(this.showTimeout)
    if (this.hideTimeout) clearTimeout(this.hideTimeout)
  }
}
