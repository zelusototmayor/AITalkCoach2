import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]
  
  connect() {
    this.setupKeyboardNavigation()
    this.loadAccessibilityPreferences()
  }
  
  disconnect() {
    this.cleanupKeyboardNavigation()
  }
  
  togglePanel(event) {
    event.preventDefault()
    const panel = this.panelTarget
    const isHidden = panel.getAttribute('aria-hidden') === 'true'
    
    if (isHidden) {
      this.showPanel()
    } else {
      this.hidePanel()
    }
  }
  
  showPanel() {
    const panel = this.panelTarget
    panel.setAttribute('aria-hidden', 'false')
    panel.style.display = 'block'
    
    // Focus the first button in the panel
    const firstButton = panel.querySelector('button')
    if (firstButton) {
      firstButton.focus()
    }
    
    // Add escape key listener
    document.addEventListener('keydown', this.handlePanelEscape.bind(this))
    
    // Add click outside listener
    setTimeout(() => {
      document.addEventListener('click', this.handleOutsideClick.bind(this))
    }, 100)
  }
  
  hidePanel() {
    const panel = this.panelTarget
    panel.setAttribute('aria-hidden', 'true')
    panel.style.display = 'none'
    
    // Remove event listeners
    document.removeEventListener('keydown', this.handlePanelEscape.bind(this))
    document.removeEventListener('click', this.handleOutsideClick.bind(this))
  }
  
  closePanel(event) {
    event.preventDefault()
    this.hidePanel()
  }
  
  handlePanelEscape(event) {
    if (event.key === 'Escape') {
      this.hidePanel()
    }
  }
  
  handleOutsideClick(event) {
    const panel = this.panelTarget
    const toggleButton = document.querySelector('.accessibility-toggle')
    
    if (!panel.contains(event.target) && event.target !== toggleButton) {
      this.hidePanel()
    }
  }
  
  toggleHighContrast(event) {
    const button = event.target
    const isPressed = button.getAttribute('aria-pressed') === 'true'
    const newState = !isPressed
    
    button.setAttribute('aria-pressed', newState.toString())
    
    if (newState) {
      document.body.classList.add('high-contrast')
      this.announceChange('High contrast mode enabled')
    } else {
      document.body.classList.remove('high-contrast')
      this.announceChange('High contrast mode disabled')
    }
    
    this.saveAccessibilityPreference('highContrast', newState)
  }
  
  toggleLargeText(event) {
    const button = event.target
    const isPressed = button.getAttribute('aria-pressed') === 'true'
    const newState = !isPressed
    
    button.setAttribute('aria-pressed', newState.toString())
    
    if (newState) {
      document.body.classList.add('large-text')
      this.announceChange('Large text mode enabled')
    } else {
      document.body.classList.remove('large-text')
      this.announceChange('Large text mode disabled')
    }
    
    this.saveAccessibilityPreference('largeText', newState)
  }
  
  toggleReducedMotion(event) {
    const button = event.target
    const isPressed = button.getAttribute('aria-pressed') === 'true'
    const newState = !isPressed
    
    button.setAttribute('aria-pressed', newState.toString())
    
    if (newState) {
      document.body.classList.add('reduced-motion')
      this.announceChange('Reduced motion enabled')
    } else {
      document.body.classList.remove('reduced-motion')
      this.announceChange('Reduced motion disabled')
    }
    
    this.saveAccessibilityPreference('reducedMotion', newState)
  }
  
  toggleKeyboardNavigation(event) {
    const button = event.target
    const isPressed = button.getAttribute('aria-pressed') === 'true'
    const newState = !isPressed
    
    button.setAttribute('aria-pressed', newState.toString())
    
    if (newState) {
      document.body.classList.add('enhanced-keyboard-nav')
      this.enhanceKeyboardNavigation()
      this.announceChange('Enhanced keyboard navigation enabled')
    } else {
      document.body.classList.remove('enhanced-keyboard-nav')
      this.disableEnhancedKeyboardNavigation()
      this.announceChange('Enhanced keyboard navigation disabled')
    }
    
    this.saveAccessibilityPreference('enhancedKeyboard', newState)
  }
  
  setupKeyboardNavigation() {
    // Add keyboard event listener for global shortcuts
    document.addEventListener('keydown', this.handleGlobalKeydown.bind(this))
    
    // Enhance focus visibility
    document.addEventListener('keydown', this.handleTabKey.bind(this))
  }
  
  cleanupKeyboardNavigation() {
    document.removeEventListener('keydown', this.handleGlobalKeydown.bind(this))
    document.removeEventListener('keydown', this.handleTabKey.bind(this))
  }
  
  handleGlobalKeydown(event) {
    // Alt + A: Open accessibility panel
    if (event.altKey && event.key === 'a') {
      event.preventDefault()
      this.showPanel()
    }
    
    // Alt + S: Skip to main content
    if (event.altKey && event.key === 's') {
      event.preventDefault()
      const mainContent = document.getElementById('main-content')
      if (mainContent) {
        mainContent.focus()
        mainContent.scrollIntoView()
      }
    }
    
    // Alt + M: Open main navigation
    if (event.altKey && event.key === 'm') {
      event.preventDefault()
      const firstNavLink = document.querySelector('.nav-links .nav-link')
      if (firstNavLink) {
        firstNavLink.focus()
      }
    }
  }
  
  handleTabKey(event) {
    if (event.key === 'Tab') {
      document.body.classList.add('keyboard-navigation')
    }
  }
  
  enhanceKeyboardNavigation() {
    // Add more visible focus indicators
    const focusableElements = document.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    
    focusableElements.forEach(element => {
      element.classList.add('enhanced-focus')
    })
    
    // Add keyboard shortcuts announcements
    this.addKeyboardShortcutsAnnouncement()
  }
  
  disableEnhancedKeyboardNavigation() {
    const enhancedElements = document.querySelectorAll('.enhanced-focus')
    enhancedElements.forEach(element => {
      element.classList.remove('enhanced-focus')
    })
    
    this.removeKeyboardShortcutsAnnouncement()
  }
  
  addKeyboardShortcutsAnnouncement() {
    if (document.getElementById('keyboard-shortcuts-info')) return
    
    const shortcutsInfo = document.createElement('div')
    shortcutsInfo.id = 'keyboard-shortcuts-info'
    shortcutsInfo.className = 'keyboard-shortcuts-info'
    shortcutsInfo.innerHTML = `
      <h3>Keyboard Shortcuts</h3>
      <ul>
        <li><kbd>Alt + A</kbd> - Open accessibility settings</li>
        <li><kbd>Alt + S</kbd> - Skip to main content</li>
        <li><kbd>Alt + M</kbd> - Navigate to main menu</li>
        <li><kbd>Tab</kbd> - Navigate forward</li>
        <li><kbd>Shift + Tab</kbd> - Navigate backward</li>
        <li><kbd>Enter</kbd> or <kbd>Space</kbd> - Activate buttons</li>
        <li><kbd>Escape</kbd> - Close dialogs/panels</li>
      </ul>
      <button type="button" onclick="this.parentElement.remove()" aria-label="Close shortcuts info">
        ✕
      </button>
    `
    
    document.body.appendChild(shortcutsInfo)
    
    // Auto-hide after 10 seconds
    setTimeout(() => {
      if (shortcutsInfo.parentElement) {
        shortcutsInfo.remove()
      }
    }, 10000)
  }
  
  removeKeyboardShortcutsAnnouncement() {
    const shortcutsInfo = document.getElementById('keyboard-shortcuts-info')
    if (shortcutsInfo) {
      shortcutsInfo.remove()
    }
  }
  
  saveAccessibilityPreference(key, value) {
    try {
      const preferences = JSON.parse(localStorage.getItem('accessibilityPreferences') || '{}')
      preferences[key] = value
      localStorage.setItem('accessibilityPreferences', JSON.stringify(preferences))
    } catch (error) {
      console.warn('Could not save accessibility preference:', error)
    }
  }
  
  loadAccessibilityPreferences() {
    try {
      const preferences = JSON.parse(localStorage.getItem('accessibilityPreferences') || '{}')
      
      // Apply saved preferences
      Object.entries(preferences).forEach(([key, value]) => {
        if (value) {
          switch (key) {
            case 'highContrast':
              document.body.classList.add('high-contrast')
              this.updateButtonState('toggleHighContrast', true)
              break
            case 'largeText':
              document.body.classList.add('large-text')
              this.updateButtonState('toggleLargeText', true)
              break
            case 'reducedMotion':
              document.body.classList.add('reduced-motion')
              this.updateButtonState('toggleReducedMotion', true)
              break
            case 'enhancedKeyboard':
              document.body.classList.add('enhanced-keyboard-nav')
              this.enhanceKeyboardNavigation()
              this.updateButtonState('toggleKeyboardNavigation', true)
              break
          }
        }
      })
    } catch (error) {
      console.warn('Could not load accessibility preferences:', error)
    }
  }
  
  updateButtonState(action, pressed) {
    const button = document.querySelector(`[data-action*="${action}"]`)
    if (button) {
      button.setAttribute('aria-pressed', pressed.toString())
    }
  }
  
  announceChange(message) {
    // Create a temporary element for screen reader announcements
    const announcement = document.createElement('div')
    announcement.setAttribute('aria-live', 'polite')
    announcement.setAttribute('aria-atomic', 'true')
    announcement.className = 'sr-only'
    announcement.textContent = message
    
    document.body.appendChild(announcement)
    
    // Remove after announcement
    setTimeout(() => {
      document.body.removeChild(announcement)
    }, 1000)
  }
}