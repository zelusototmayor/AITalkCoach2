import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "difficultyFilter", "categoryFilter", "card"]

  connect() {
    console.log("Prompts practice controller connected")
  }

  filterPrompts() {
    const searchTerm = this.hasSearchInputTarget ? this.searchInputTarget.value.toLowerCase() : ""
    const selectedDifficulty = this.hasDifficultyFilterTarget ? this.difficultyFilterTarget.value.toLowerCase() : ""
    const selectedCategory = this.hasCategoryFilterTarget ? this.categoryFilterTarget.value.toLowerCase() : ""

    this.cardTargets.forEach(card => {
      const cardTitle = (card.dataset.title || "").toLowerCase()
      const cardPromptText = (card.dataset.promptText || "").toLowerCase()
      const cardDifficulty = (card.dataset.difficulty || "").toLowerCase()
      const cardCategory = (card.dataset.category || "").toLowerCase()

      // Check search match
      const searchMatch = !searchTerm ||
                         cardTitle.includes(searchTerm) ||
                         cardPromptText.includes(searchTerm)

      // Check difficulty match
      const difficultyMatch = !selectedDifficulty || cardDifficulty === selectedDifficulty

      // Check category match
      const categoryMatch = !selectedCategory || cardCategory === selectedCategory

      // Show card if all filters match
      if (searchMatch && difficultyMatch && categoryMatch) {
        card.style.display = ""
      } else {
        card.style.display = "none"
      }
    })
  }

  usePrompt(event) {
    const button = event.currentTarget
    const promptText = button.dataset.promptText
    const targetSeconds = button.dataset.targetSeconds

    // Find the prompt input field and set it
    const promptInput = document.querySelector('[data-practice-timer-target="promptInput"]')
    if (promptInput) {
      promptInput.value = promptText
      // Trigger change event
      promptInput.dispatchEvent(new Event('change', { bubbles: true }))
    }

    // Set target duration
    const durationInput = document.querySelector('[data-practice-timer-target="durationInput"]')
    if (durationInput) {
      durationInput.value = targetSeconds
    }

    // Scroll to top to show the updated prompt
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }
}
