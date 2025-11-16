import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "content"]

  // Trigger loading state on form submission
  submit(event) {
    this.showLoading()
  }

  // Trigger loading state on button click
  click(event) {
    this.showLoading()
  }

  showLoading() {
    // Add loading class to button
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.add("btn-loading")
      this.buttonTarget.disabled = true
    }

    // Show loading overlay if content target exists
    if (this.hasContentTarget) {
      const overlay = document.createElement("div")
      overlay.className = "loading-overlay"
      overlay.innerHTML = `
        <div class="spinner"></div>
        <div class="processing-message">Loading...</div>
      `
      this.contentTarget.style.position = "relative"
      this.contentTarget.appendChild(overlay)
    }
  }

  hideLoading() {
    // Remove loading class from button
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.remove("btn-loading")
      this.buttonTarget.disabled = false
    }

    // Remove loading overlay
    if (this.hasContentTarget) {
      const overlay = this.contentTarget.querySelector(".loading-overlay")
      if (overlay) {
        overlay.remove()
      }
    }
  }
}
