import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { percentage: Number }

  connect() {
    this.animateProgress()
  }

  animateProgress() {
    const activeCircle = this.element.querySelector('.progress-ring__circle--active')
    const radius = activeCircle.r.baseVal.value
    const circumference = radius * 2 * Math.PI
    const percentage = this.percentageValue

    activeCircle.style.strokeDasharray = `${circumference} ${circumference}`
    activeCircle.style.strokeDashoffset = circumference

    // Animate after a short delay
    setTimeout(() => {
      const offset = circumference - (percentage / 100) * circumference
      activeCircle.style.strokeDashoffset = offset
    }, 100)
  }
}