import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "toggle"]

  connect() {
    // Close menu when clicking outside
    document.addEventListener("click", this.handleOutsideClick.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick.bind(this))
  }

  toggleMenu() {
    const menu = this.element.querySelector(".nav-menu")
    const toggle = this.element.querySelector(".mobile-menu-toggle")
    
    menu.classList.toggle("active")
    toggle.classList.toggle("active")
    
    // Update ARIA attributes
    const isExpanded = menu.classList.contains("active")
    toggle.setAttribute("aria-expanded", isExpanded)
  }

  handleOutsideClick(event) {
    const menu = this.element.querySelector(".nav-menu")
    const toggle = this.element.querySelector(".mobile-menu-toggle")
    
    if (!this.element.contains(event.target) && menu.classList.contains("active")) {
      menu.classList.remove("active")
      toggle.classList.remove("active")
      toggle.setAttribute("aria-expanded", "false")
    }
  }

  // Close menu when a nav link is clicked (mobile)
  closeMenu() {
    const menu = this.element.querySelector(".nav-menu")
    const toggle = this.element.querySelector(".mobile-menu-toggle")

    if (window.innerWidth <= 768) {
      menu.classList.remove("active")
      toggle.classList.remove("active")
      toggle.setAttribute("aria-expanded", "false")
    }
  }

}