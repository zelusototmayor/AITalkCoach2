import { Controller } from "@hotwired/stimulus"

// Google Sign-In controller using Google Identity Services
export default class extends Controller {
  static values = {
    clientId: String
  }

  connect() {
    this.loadGoogleScript()
  }

  loadGoogleScript() {
    // Check if script is already loaded
    if (window.google && window.google.accounts) {
      this.initializeGoogle()
      return
    }

    // Load Google Identity Services script
    const script = document.createElement("script")
    script.src = "https://accounts.google.com/gsi/client"
    script.async = true
    script.defer = true
    script.onload = () => this.initializeGoogle()
    document.head.appendChild(script)
  }

  initializeGoogle() {
    if (!this.clientIdValue) {
      console.warn("Google Sign-In: No client ID configured")
      return
    }

    // Initialize Google Identity Services
    window.google.accounts.id.initialize({
      client_id: this.clientIdValue,
      callback: (response) => this.handleCredentialResponse(response),
      auto_select: false,
      cancel_on_tap_outside: true
    })

    // Render the Google Sign-In button
    const buttonContainer = this.element.querySelector("#google-signin-button")
    if (buttonContainer) {
      window.google.accounts.id.renderButton(buttonContainer, {
        type: "standard",
        shape: "rectangular",
        theme: "outline",
        size: "large",
        text: "continue_with",
        width: "100%"
      })
    }
  }

  async handleCredentialResponse(response) {
    if (!response.credential) {
      console.error("No credential received from Google")
      this.showError("Google sign-in failed. Please try again.")
      return
    }

    try {
      // Show loading state
      this.setLoading(true)

      // Send the credential to our backend
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const result = await fetch("/auth/oauth/google", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ credential: response.credential })
      })

      if (result.ok) {
        // Redirect will be handled by the controller
        window.location.href = result.url || "/practice"
      } else {
        const data = await result.json().catch(() => ({}))
        this.showError(data.error || "Google sign-in failed. Please try again.")
      }
    } catch (error) {
      console.error("Google sign-in error:", error)
      this.showError("Google sign-in failed. Please try again.")
    } finally {
      this.setLoading(false)
    }
  }

  setLoading(isLoading) {
    const button = this.element.querySelector("#google-signin-button")
    if (button) {
      button.style.opacity = isLoading ? "0.6" : "1"
      button.style.pointerEvents = isLoading ? "none" : "auto"
    }
  }

  showError(message) {
    // Try to find an existing error container or create one
    let errorContainer = document.querySelector(".oauth-error")
    if (!errorContainer) {
      errorContainer = document.createElement("div")
      errorContainer.className = "oauth-error bg-red-50 text-red-600 p-3 rounded-lg mb-4 text-sm text-center"
      this.element.parentNode.insertBefore(errorContainer, this.element)
    }
    errorContainer.textContent = message
    errorContainer.style.display = "block"

    // Hide after 5 seconds
    setTimeout(() => {
      errorContainer.style.display = "none"
    }, 5000)
  }
}
