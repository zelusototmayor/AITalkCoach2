import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "content"]

  connect() {
    console.log("Tabs controller connected")
    this.showActiveTab()
  }

  switchTab(event) {
    const clickedTab = event.currentTarget
    const targetTab = clickedTab.dataset.tab

    // Remove active class from all tabs and content
    this.tabTargets.forEach(tab => tab.classList.remove("active"))
    this.contentTargets.forEach(content => {
      content.classList.remove("active")
    })

    // Add active class to clicked tab
    clickedTab.classList.add("active")

    // Show corresponding content
    const targetContent = this.contentTargets.find(content =>
      content.dataset.tab === targetTab
    )
    if (targetContent) {
      targetContent.classList.add("active")
    }

    console.log(`Switched to tab: ${targetTab}`)
  }

  filterIssues(event) {
    const filter = event.currentTarget.dataset.filter
    const issueItems = document.querySelectorAll(".issue-item-clean")

    // Update active filter button
    document.querySelectorAll(".filter-tag").forEach(tag => {
      tag.classList.remove("active")
    })
    event.currentTarget.classList.add("active")

    // Show/hide issues based on filter
    issueItems.forEach(item => {
      const category = item.dataset.category
      if (filter === "all" || category === filter) {
        item.style.display = "flex"
      } else {
        item.style.display = "none"
      }
    })

    console.log(`Filtered issues by: ${filter}`)
  }

  showActiveTab() {
    // Ensure the first tab is active on load
    const firstTab = this.tabTargets[0]
    const firstContent = this.contentTargets[0]

    if (firstTab && firstContent) {
      firstTab.classList.add("active")
      firstContent.classList.add("active")
    }
  }
}