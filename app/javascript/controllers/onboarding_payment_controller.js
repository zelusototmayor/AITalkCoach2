import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitBtn", "submitText", "submitLoader", "planRadio"]
  static values = {
    setupIntent: String
  }

  connect() {
    // Wait for Stripe.js to be available before initializing
    this.waitForStripe()
  }

  async waitForStripe() {
    const maxWaitTime = 5000 // 5 seconds max
    const checkInterval = 100 // Check every 100ms
    const startTime = Date.now()

    const checkStripeLoaded = () => {
      return new Promise((resolve) => {
        const check = () => {
          if (typeof window.Stripe !== 'undefined') {
            resolve(true)
          } else if (Date.now() - startTime > maxWaitTime) {
            resolve(false)
          } else {
            setTimeout(check, checkInterval)
          }
        }
        check()
      })
    }

    const isLoaded = await checkStripeLoaded()

    if (!isLoaded) {
      this.showError('Failed to load payment system. Please refresh the page.')
      console.error('Stripe.js failed to load within timeout period')
      return
    }

    // Initialize Stripe now that it's loaded
    this.initializeStripe()
  }

  initializeStripe() {
    try {
      // Initialize Stripe
      this.stripe = Stripe(this.getPublishableKey())

      // Create card element
      const elements = this.stripe.elements()
      this.cardElement = elements.create('card', {
        style: {
          base: {
            fontSize: '16px',
            color: '#0F172A',
            fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
            '::placeholder': {
              color: '#94A3B8',
            },
          },
          invalid: {
            color: '#EF4444',
            iconColor: '#EF4444'
          }
        }
      })

      this.cardElement.mount('#stripe-card-element')

      // Handle real-time validation errors
      this.cardElement.on('change', (event) => {
        const displayError = document.getElementById('card-errors')
        if (event.error) {
          displayError.textContent = event.error.message
        } else {
          displayError.textContent = ''
        }
      })

      // Add keyboard navigation support for plan cards
      this.setupKeyboardNavigation()
    } catch (error) {
      console.error('Error initializing Stripe:', error)
      this.showError('Failed to initialize payment system. Please refresh the page.')
    }
  }

  setupKeyboardNavigation() {
    // Add keyboard support for pricing card labels
    const pricingCards = document.querySelectorAll('.pricing-card-compact[tabindex="0"]')
    pricingCards.forEach(card => {
      card.addEventListener('keydown', (e) => {
        // Enter or Space key selects the plan
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          const radio = card.querySelector('.plan-radio')
          if (radio) {
            radio.checked = true
            radio.dispatchEvent(new Event('change', { bubbles: true }))
          }
        }
      })
    })

    // Add keyboard support for goal cards (if on that page)
    const goalCards = document.querySelectorAll('.goal-card[tabindex="0"]')
    goalCards.forEach(card => {
      card.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          const radio = card.querySelector('.goal-radio')
          if (radio) {
            radio.checked = true
          }
        }
      })
    })

    // Add keyboard support for radio options
    const radioOptions = document.querySelectorAll('.radio-option[tabindex="0"]')
    radioOptions.forEach(option => {
      option.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          const radio = option.querySelector('.radio-input')
          if (radio) {
            radio.checked = true
          }
        }
      })
    })

    // Add keyboard support for pill buttons
    const pillButtons = document.querySelectorAll('.pill-button[tabindex="0"]')
    pillButtons.forEach(button => {
      button.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          const radio = button.querySelector('.pill-radio')
          if (radio) {
            radio.checked = true
          }
        }
      })
    })
  }

  disconnect() {
    if (this.cardElement) {
      this.cardElement.destroy()
    }
  }

  selectPlan(event) {
    // Update UI to show selected plan
    this.planRadioTargets.forEach(radio => {
      const card = radio.closest('.pricing-card-compact')
      if (radio.checked) {
        card.classList.add('selected')
      } else {
        card.classList.remove('selected')
      }
    })
  }

  async submitPayment(event) {
    event.preventDefault()

    // Check if Stripe is initialized
    if (!this.stripe || !this.cardElement) {
      this.showError('Payment system is still loading. Please wait a moment and try again.')
      return
    }

    // Disable submit button and show loader
    this.submitBtnTarget.disabled = true
    this.submitBtnTarget.setAttribute('aria-busy', 'true')
    this.submitTextTarget.style.display = 'none'
    this.submitLoaderTarget.style.display = 'inline-block'

    // Get selected plan
    const selectedPlan = this.planRadioTargets.find(radio => radio.checked)?.value
    if (!selectedPlan) {
      this.showError('Please select a plan')
      this.resetSubmitButton()
      return
    }

    try {
      // Confirm the SetupIntent with the card details
      const { setupIntent, error } = await this.stripe.confirmCardSetup(
        this.setupIntentValue,
        {
          payment_method: {
            card: this.cardElement,
          }
        }
      )

      if (error) {
        // Show error to customer
        this.showError(error.message)
        this.resetSubmitButton()
      } else {
        // SetupIntent was successful, submit to server
        await this.submitToServer(setupIntent.id, selectedPlan)
      }
    } catch (error) {
      console.error('Payment error:', error)
      this.showError('An unexpected error occurred. Please try again.')
      this.resetSubmitButton()
    }
  }

  async submitToServer(setupIntentId, selectedPlan) {
    const formData = new FormData()
    formData.append('setup_intent_id', setupIntentId)
    formData.append('selected_plan', selectedPlan)

    // Get CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch('/onboarding/pricing', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken,
        },
        body: formData
      })

      if (response.ok || response.redirected) {
        // In development mode, server redirects to /onboarding/complete
        // Follow the redirect by navigating to the complete path
        window.location.href = '/onboarding/complete'
      } else {
        const data = await response.text()
        this.showError('Payment setup failed. Please try again.')
        this.resetSubmitButton()
      }
    } catch (error) {
      console.error('Server error:', error)
      this.showError('An error occurred. Please try again.')
      this.resetSubmitButton()
    }
  }

  showError(message) {
    const displayError = document.getElementById('card-errors')
    displayError.textContent = message
  }

  resetSubmitButton() {
    this.submitBtnTarget.disabled = false
    this.submitBtnTarget.removeAttribute('aria-busy')
    this.submitTextTarget.style.display = 'inline'
    this.submitLoaderTarget.style.display = 'none'
  }

  getPublishableKey() {
    // Get Stripe publishable key from Rails meta tag
    const metaTag = document.querySelector('meta[name="stripe-publishable-key"]')
    if (metaTag && metaTag.content) {
      return metaTag.content
    }

    // If meta tag is missing, show error
    console.error('Stripe publishable key not found. Please ensure the meta tag is present in the page.')
    throw new Error('Stripe configuration missing. Please refresh the page.')
  }
}
