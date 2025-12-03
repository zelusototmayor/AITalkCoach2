import { Controller } from "@hotwired/stimulus"

// Google Sign-In controller using Google Identity Services
export default class extends Controller {
  static values = {
    clientId: String
  }

  static targets = ["button"]

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

    // Mark as ready
    this.googleReady = true
  }

  // Called when user clicks our custom button
  signIn(event) {
    event.preventDefault()

    if (!this.googleReady) {
      this.showError("Google Sign-In is still loading. Please try again.")
      return
    }

    // Use the One Tap prompt to trigger sign-in
    window.google.accounts.id.prompt((notification) => {
      if (notification.isNotDisplayed()) {
        // Fall back to OAuth2 popup if One Tap is not available
        this.fallbackSignIn()
      } else if (notification.isSkippedMoment()) {
        // User dismissed, do nothing
      }
    })
  }

  fallbackSignIn() {
    // Use OAuth2 authorization code flow as fallback
    const client = window.google.accounts.oauth2.initTokenClient({
      client_id: this.clientIdValue,
      scope: "email profile",
      callback: (tokenResponse) => {
        if (tokenResponse.access_token) {
          this.handleAccessToken(tokenResponse.access_token)
        }
      }
    })
    client.requestAccessToken()
  }

  async handleAccessToken(accessToken) {
    try {
      this.setLoading(true)

      // Get user info from Google
      const userInfoResponse = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
        headers: { Authorization: `Bearer ${accessToken}` }
      })
      const userInfo = await userInfoResponse.json()

      // Send to our backend
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const result = await fetch("/auth/oauth/google", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          access_token: accessToken,
          user_info: userInfo
        })
      })

      if (result.ok) {
        const data = await result.json().catch(() => ({}))
        window.location.href = data.redirect_url || "/practice"
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
        const data = await result.json().catch(() => ({}))
        window.location.href = data.redirect_url || "/practice"
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
