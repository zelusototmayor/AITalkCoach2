import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stickyBtn"]

  connect() {
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll)
    this.onScroll() // Check initial state
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    const scrollY = window.scrollY
    const shouldShow = scrollY > 360

    if (shouldShow) {
      this.stickyBtnTarget.classList.add("visible")
    } else {
      this.stickyBtnTarget.classList.remove("visible")
    }
  }
}