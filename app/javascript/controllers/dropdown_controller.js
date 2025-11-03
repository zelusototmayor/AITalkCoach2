import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button", "arrow"]

  connect() {
    // Close dropdown when clicking outside
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.handleOutsideClick)

    // Check if any submenu item is active and expand the dropdown
    const activeItem = this.menuTarget.querySelector('.sidebar-dropdown-link.active')
    if (activeItem) {
      this.open()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
  }

  toggle(event) {
    event.stopPropagation()

    if (this.menuTarget.style.display === "none") {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.style.display = "block"
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.arrowTarget.style.transform = "rotate(180deg)"
  }

  close() {
    this.menuTarget.style.display = "none"
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.arrowTarget.style.transform = "rotate(0)"
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}