import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoDismiss: { type: Boolean, default: true },
    dismissAfter: { type: Number, default: 5000 } // 5 seconds
  }

  connect() {
    if (this.autoDismissValue) {
      this.dismissTimeout = setTimeout(() => {
        this.dismiss()
      }, this.dismissAfterValue)
    }
  }

  disconnect() {
    if (this.dismissTimeout) {
      clearTimeout(this.dismissTimeout)
    }
  }

  dismiss() {
    // Add fade-out class for smooth animation
    this.element.classList.add('fade-out')

    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 300) // Match the CSS transition duration
  }

  // Allow manual dismiss on click
  close(event) {
    event.preventDefault()
    if (this.dismissTimeout) {
      clearTimeout(this.dismissTimeout)
    }
    this.dismiss()
  }
}
