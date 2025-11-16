import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay", "toggleButton"]

  connect() {
    // Close sidebar when clicking nav links on mobile
    this.sidebarTarget.addEventListener("click", (e) => {
      if (e.target.closest(".sidebar-nav-link") && window.innerWidth <= 768) {
        this.close()
      }
    })
  }

  toggle() {
    const isOpen = this.sidebarTarget.classList.contains("open")

    if (isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.sidebarTarget.classList.add("open")
    this.overlayTarget.classList.add("active")
    this.toggleButtonTarget.classList.add("active")
    this.toggleButtonTarget.setAttribute("aria-expanded", "true")

    // Prevent body scroll when sidebar is open on mobile
    if (window.innerWidth <= 768) {
      document.body.style.overflow = "hidden"
    }
  }

  close() {
    this.sidebarTarget.classList.remove("open")
    this.overlayTarget.classList.remove("active")
    this.toggleButtonTarget.classList.remove("active")
    this.toggleButtonTarget.setAttribute("aria-expanded", "false")

    // Re-enable body scroll
    document.body.style.overflow = ""
  }
}
