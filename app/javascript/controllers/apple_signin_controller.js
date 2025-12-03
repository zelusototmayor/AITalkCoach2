import { Controller } from "@hotwired/stimulus"

// Apple Sign-In controller using Sign in with Apple JS
export default class extends Controller {
  static values = {
    clientId: String,
    redirectUri: String
  }

  connect() {
    this.loadAppleScript()
  }

  loadAppleScript() {
    // Check if script is already loaded
    if (window.AppleID) {
      this.initializeApple()
      return
    }

    // Load Apple Sign In JS SDK
    const script = document.createElement("script")
    script.src = "https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js"
    script.async = true
    script.defer = true
    script.onload = () => this.initializeApple()
    document.head.appendChild(script)
  }

  initializeApple() {
    if (!this.clientIdValue) {
      console.warn("Apple Sign-In: No client ID configured")
      return
    }

    // Initialize Apple Sign In
    window.AppleID.auth.init({
      clientId: this.clientIdValue,
      scope: "name email",
      redirectURI: this.redirectUriValue || window.location.origin + "/auth/callback/apple",
      usePopup: true
    })

    // Set up the button click handler
    const button = this.element.querySelector("#apple-signin-button")
    if (button) {
      button.addEventListener("click", () => this.handleSignIn())
    }
  }

  async handleSignIn() {
    try {
      this.setLoading(true)

      // Trigger Apple Sign In popup
      const response = await window.AppleID.auth.signIn()

      // Apple returns authorization object with id_token and user info
      await this.sendToBackend(response)
    } catch (error) {
      if (error.error === "popup_closed_by_user") {
        // User cancelled - don't show error
        console.log("Apple sign-in cancelled by user")
      } else {
        console.error("Apple sign-in error:", error)
        this.showError("Apple sign-in failed. Please try again.")
      }
    } finally {
      this.setLoading(false)
    }
  }

  async sendToBackend(response) {
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      // Prepare the data to send
      const data = {
        id_token: response.authorization.id_token
      }

      // Apple provides user info only on first authorization
      if (response.user) {
        data.user = JSON.stringify(response.user)
      }

      const result = await fetch("/auth/oauth/apple", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify(data)
      })

      if (result.ok) {
        // Redirect will be handled by the controller
        window.location.href = result.url || "/practice"
      } else {
        const errorData = await result.json().catch(() => ({}))
        this.showError(errorData.error || "Apple sign-in failed. Please try again.")
      }
    } catch (error) {
      console.error("Apple backend auth error:", error)
      this.showError("Apple sign-in failed. Please try again.")
    }
  }

  setLoading(isLoading) {
    const button = this.element.querySelector("#apple-signin-button")
    if (button) {
      button.style.opacity = isLoading ? "0.6" : "1"
      button.style.pointerEvents = isLoading ? "none" : "auto"

      const buttonText = button.querySelector("span")
      if (buttonText) {
        buttonText.textContent = isLoading ? "Signing in..." : "Continue with Apple"
      }
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
