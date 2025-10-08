import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "feedbackModal",
    "accessibilityPanel",
    "feedbackText",
    "charCount",
    "imageInput",
    "fileLabel",
    "imagePreviews",
    "form",
    "submitBtn",
    "submitText",
    "submitLoader"
  ]

  connect() {
    this.setupEventListeners()
    this.updateCharCount()
  }

  setupEventListeners() {
    // Listen for character count updates
    if (this.hasFeedbackTextTarget) {
      this.feedbackTextTarget.addEventListener('input', this.updateCharCount.bind(this))
    }
  }

  openFeedbackModal(event) {
    if (event) event.preventDefault()
    this.showFeedbackModal()
  }

  showFeedbackModal() {
    this.feedbackModalTarget.setAttribute('aria-hidden', 'false')
    this.feedbackModalTarget.style.display = 'flex'

    // Focus the textarea
    if (this.hasFeedbackTextTarget) {
      setTimeout(() => this.feedbackTextTarget.focus(), 100)
    }

    // Add escape key listener
    document.addEventListener('keydown', this.handleModalEscape.bind(this))
  }

  closeFeedbackModal(event) {
    if (event) event.preventDefault()
    this.feedbackModalTarget.setAttribute('aria-hidden', 'true')
    this.feedbackModalTarget.style.display = 'none'
    this.resetForm()

    // Remove escape key listener
    document.removeEventListener('keydown', this.handleModalEscape.bind(this))
  }

  handleModalEscape(event) {
    if (event.key === 'Escape') {
      this.closeFeedbackModal()
    }
  }

  openAccessibilityPanel(event) {
    if (event) event.preventDefault()

    // Trigger the accessibility controller's showPanel method
    const accessibilityController = this.application.getControllerForElementAndIdentifier(
      document.body,
      'accessibility'
    )
    if (accessibilityController) {
      accessibilityController.showPanel()
    }
  }

  updateCharCount() {
    if (this.hasFeedbackTextTarget && this.hasCharCountTarget) {
      const count = this.feedbackTextTarget.value.length
      this.charCountTarget.textContent = count
    }
  }

  handleImageChange(event) {
    const files = Array.from(event.target.files)

    if (files.length > 5) {
      alert('Maximum 5 images allowed')
      event.target.value = ''
      return
    }

    // Update file label
    if (files.length > 0) {
      this.fileLabelTarget.textContent = `${files.length} image${files.length > 1 ? 's' : ''} selected`
    } else {
      this.fileLabelTarget.textContent = 'Choose images (max 5)'
    }

    // Show image previews
    this.showImagePreviews(files)
  }

  showImagePreviews(files) {
    this.imagePreviewsTarget.innerHTML = ''

    files.forEach((file, index) => {
      const reader = new FileReader()

      reader.onload = (e) => {
        const preview = document.createElement('div')
        preview.className = 'image-preview'
        preview.innerHTML = `
          <img src="${e.target.result}" alt="Preview ${index + 1}" />
          <button type="button" class="remove-image" data-index="${index}" aria-label="Remove image">✕</button>
        `

        preview.querySelector('.remove-image').addEventListener('click', (event) => {
          this.removeImage(event.currentTarget.dataset.index)
        })

        this.imagePreviewsTarget.appendChild(preview)
      }

      reader.readAsDataURL(file)
    })
  }

  removeImage(index) {
    // Get current files
    const dt = new DataTransfer()
    const files = Array.from(this.imageInputTarget.files)

    // Add all files except the one to remove
    files.forEach((file, i) => {
      if (i !== parseInt(index)) {
        dt.items.add(file)
      }
    })

    // Update input
    this.imageInputTarget.files = dt.files

    // Trigger change event to update previews
    this.handleImageChange({ target: this.imageInputTarget })
  }

  async submitFeedback(event) {
    event.preventDefault()

    const feedbackText = this.feedbackTextTarget.value.trim()

    if (!feedbackText) {
      alert('Please enter your feedback')
      return
    }

    // Show loading state
    this.setSubmitting(true)

    try {
      const formData = new FormData()
      formData.append('feedback_text', feedbackText)

      // Add images
      const files = Array.from(this.imageInputTarget.files)
      files.forEach((file, index) => {
        formData.append('images[]', file)
      })

      const response = await fetch('/feedback', {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (response.ok) {
        this.showSuccess()
        setTimeout(() => {
          this.closeFeedbackModal()
        }, 2000)
      } else {
        throw new Error(data.error || 'Failed to submit feedback')
      }
    } catch (error) {
      console.error('Feedback submission error:', error)
      alert(error.message || 'Failed to submit feedback. Please try again.')
    } finally {
      this.setSubmitting(false)
    }
  }

  setSubmitting(isSubmitting) {
    this.submitBtnTarget.disabled = isSubmitting

    if (isSubmitting) {
      this.submitTextTarget.style.display = 'none'
      this.submitLoaderTarget.style.display = 'inline-block'
    } else {
      this.submitTextTarget.style.display = 'inline'
      this.submitLoaderTarget.style.display = 'none'
    }
  }

  showSuccess() {
    // Show success message
    const successMsg = document.createElement('div')
    successMsg.className = 'feedback-success'
    successMsg.textContent = '✓ Feedback sent successfully! Thank you.'

    this.formTarget.parentElement.insertBefore(successMsg, this.formTarget)
    this.formTarget.style.display = 'none'
  }

  resetForm() {
    if (this.hasFormTarget) {
      this.formTarget.reset()
      this.formTarget.style.display = 'block'
    }

    if (this.hasImagePreviewsTarget) {
      this.imagePreviewsTarget.innerHTML = ''
    }

    if (this.hasFileLabelTarget) {
      this.fileLabelTarget.textContent = 'Choose images (max 5)'
    }

    this.updateCharCount()

    // Remove success message if exists
    const successMsg = this.element.querySelector('.feedback-success')
    if (successMsg) {
      successMsg.remove()
    }
  }
}
