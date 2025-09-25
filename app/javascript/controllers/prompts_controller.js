import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "category", "prompt", "selected", "shuffle", "filter", "search",
    "favorite", "difficulty", "tags", "timer", "practiceMode", "selectedId",
    "display", "content", "library", "targetTime"
  ]
  static values = { 
    selectedPrompt: Object,
    autoShuffle: Boolean,
    shuffleInterval: Number,
    practiceMode: Boolean,
    timerEnabled: Boolean,
    timerDuration: Number
  }

  initialize() {
    this.filteredPrompts = []
    this.currentCategory = 'all'
    this.currentDifficulty = 'all'
    this.searchTerm = ''
    this.favorites = this.loadFavorites()
    this.shuffleTimer = null
    this.practiceTimer = null
    this.usedPrompts = new Set()
  }

  connect() {
    try {
      // Load data from script tags instead of Stimulus values
      this.loadDataFromScriptTags()
      
      this.autoShuffleValue = this.autoShuffleValue ?? false
      this.shuffleIntervalValue = this.shuffleIntervalValue || 30
      this.practiceModeValue = this.practiceModeValue ?? false
      this.timerEnabledValue = this.timerEnabledValue ?? false
      this.timerDurationValue = this.timerDurationValue || 120

      // Transform prompts data if it's in Rails hash format
      this.transformPromptsData()
      
      this.initializePrompts()
      this.renderCategories()
      this.filterPrompts()
      this.setupKeyboardShortcuts()
      this.restoreState()

      // Select a default prompt if none is selected
      if (!this.selectedPromptValue && this.promptsValue.length > 0) {
        this.selectedPromptValue = this.promptsValue[0]
        this.updateSelectedDisplay()
      }

      if (this.autoShuffleValue) {
        this.startAutoShuffle()
      }
    } catch (error) {
      console.error('Error connecting prompts controller:', error)
      this.handleError(error)
    }
  }

  disconnect() {
    this.stopAutoShuffle()
    this.stopPracticeTimer()
    this.removeKeyboardShortcuts()
    this.saveState()
  }

  transformPromptsData() {
    // If promptsValue is a hash (from Rails), convert it to array format
    if (this.promptsValue && typeof this.promptsValue === 'object' && !Array.isArray(this.promptsValue)) {
      const promptsArray = []
      let id = 0
      
      for (const [category, categoryPrompts] of Object.entries(this.promptsValue)) {
        categoryPrompts.forEach((prompt, index) => {
          promptsArray.push({
            id: id++,
            category: category,
            text: prompt.prompt,
            title: prompt.title,
            description: prompt.description,
            difficulty: prompt.difficulty || 'medium',
            estimatedTime: prompt.target_seconds || 60,
            tags: prompt.focus_areas || [],
            originalIndex: index
          })
        })
      }
      
      this.promptsValue = promptsArray
    }
  }

  initializePrompts() {
    if (!this.promptsValue || !Array.isArray(this.promptsValue)) {
      console.warn('No valid prompts data available')
      this.promptsValue = []
      return
    }
    
    this.promptsValue.forEach((prompt, index) => {
      prompt.id = prompt.id || index
      prompt.used = false
      prompt.lastUsed = null
      prompt.difficulty = prompt.difficulty || 'medium'
      prompt.tags = prompt.tags || []
      prompt.estimatedTime = prompt.estimatedTime || 60
    })
  }

  renderCategories() {
    if (!this.hasCategoryTarget) return

    const categories = ['all', ...this.categoriesValue]
    const categoryHTML = categories.map(category => {
      const isActive = category === this.currentCategory
      return `
        <button 
          class="category-btn px-4 py-2 rounded-lg transition-colors ${isActive ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
          data-action="click->prompts#selectCategory"
          data-category="${category}"
        >
          ${this.formatCategoryName(category)}
        </button>
      `
    }).join('')

    this.categoryTarget.innerHTML = categoryHTML
  }

  formatCategoryName(category) {
    if (category === 'all') return 'All Categories'
    return category.split('_').map(word => 
      word.charAt(0).toUpperCase() + word.slice(1)
    ).join(' ')
  }

  selectCategory(event) {
    this.currentCategory = event.target.dataset.category
    this.renderCategories()
    this.filterPrompts()
  }

  filterCategory(event) {
    this.currentCategory = event.target.dataset.category || event.target.value
    this.renderCategories()
    this.filterPrompts()
  }

  filterPrompts() {
    this.filteredPrompts = this.promptsValue.filter(prompt => {
      const matchesCategory = this.currentCategory === 'all' || prompt.category === this.currentCategory
      const matchesDifficulty = this.currentDifficulty === 'all' || prompt.difficulty === this.currentDifficulty
      const matchesSearch = !this.searchTerm || this.matchesSearchTerm(prompt)
      const matchesFavorites = !this.showFavoritesOnly || this.favorites.includes(prompt.id)
      
      return matchesCategory && matchesDifficulty && matchesSearch && matchesFavorites
    })

    this.renderPrompts()
    this.updateStats()
  }

  matchesSearchTerm(prompt) {
    const searchLower = this.searchTerm.toLowerCase()
    return (
      prompt.text.toLowerCase().includes(searchLower) ||
      prompt.category.toLowerCase().includes(searchLower) ||
      prompt.tags.some(tag => tag.toLowerCase().includes(searchLower))
    )
  }

  renderPrompts() {
    if (!this.hasPromptTarget) return

    if (this.filteredPrompts.length === 0) {
      this.promptTarget.innerHTML = `
        <div class="text-center text-gray-500 py-8">
          <p>No prompts found matching your criteria.</p>
        </div>
      `
      return
    }

    const promptsHTML = this.filteredPrompts.map(prompt => {
      const isFavorite = this.favorites.includes(prompt.id)
      const isSelected = this.selectedPromptValue && this.selectedPromptValue.id === prompt.id
      const isUsed = this.usedPrompts.has(prompt.id)

      return `
        <div class="prompt-card p-4 rounded-lg border transition-all cursor-pointer ${
          isSelected ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:border-gray-300'
        } ${isUsed ? 'opacity-60' : ''}"
             data-action="click->prompts#selectPrompt"
             data-prompt-id="${prompt.id}">
          
          <div class="flex justify-between items-start mb-2">
            <div class="flex items-center space-x-2">
              <span class="difficulty-badge px-2 py-1 text-xs rounded ${this.getDifficultyClass(prompt.difficulty)}">
                ${prompt.difficulty}
              </span>
              <span class="text-xs text-gray-500">${prompt.estimatedTime}s</span>
              ${isUsed ? '<span class="text-xs text-gray-400">✓ Used</span>' : ''}
            </div>
            
            <button class="favorite-btn text-gray-400 hover:text-yellow-500 transition-colors ${isFavorite ? 'text-yellow-500' : ''}"
                    data-action="click->prompts#toggleFavorite"
                    data-prompt-id="${prompt.id}">
              ${isFavorite ? '★' : '☆'}
            </button>
          </div>
          
          <p class="text-gray-800 mb-3 leading-relaxed">${prompt.text}</p>
          
          <div class="flex justify-between items-center text-xs text-gray-500">
            <span class="category">${this.formatCategoryName(prompt.category)}</span>
            ${prompt.tags.length > 0 ? `
              <div class="tags space-x-1">
                ${prompt.tags.map(tag => `<span class="tag bg-gray-100 px-2 py-1 rounded">${tag}</span>`).join('')}
              </div>
            ` : ''}
          </div>
        </div>
      `
    }).join('')

    this.promptTarget.innerHTML = promptsHTML
  }

  getDifficultyClass(difficulty) {
    switch (difficulty) {
      case 'easy': return 'bg-green-100 text-green-800'
      case 'medium': return 'bg-yellow-100 text-yellow-800'
      case 'hard': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  selectPrompt(event) {
    event.stopPropagation()
    const promptId = parseInt(event.currentTarget.dataset.promptId)
    const prompt = this.promptsValue.find(p => p.id === promptId)
    
    if (prompt) {
      this.selectedPromptValue = prompt
      this.markPromptAsUsed(prompt)
      this.renderPrompts()
      this.updateSelectedDisplay()
      
      this.dispatch('prompt-selected', {
        detail: { prompt },
        bubbles: true
      })

      if (this.timerEnabledValue) {
        this.startPracticeTimer(prompt.estimatedTime || this.timerDurationValue)
      }
    }
  }

  markPromptAsUsed(prompt) {
    this.usedPrompts.add(prompt.id)
    prompt.used = true
    prompt.lastUsed = new Date()
  }

  updateSelectedDisplay() {
    if (!this.hasSelectedTarget || !this.selectedPromptValue) return

    // Update the hidden field for form submission
    if (this.hasSelectedIdTarget) {
      this.selectedIdTarget.value = this.selectedPromptValue.id
    }

    this.selectedTarget.innerHTML = `
      <div class="prompt-card">
        <div class="prompt-category">${this.formatCategoryName(this.selectedPromptValue.category)}</div>
        <h4 class="prompt-title">${this.selectedPromptValue.title || 'Selected Prompt'}</h4>
        <p class="prompt-text">${this.selectedPromptValue.text}</p>
        <div class="prompt-meta">
          <span class="difficulty">${this.selectedPromptValue.difficulty}</span>
          <span class="duration">${this.selectedPromptValue.estimatedTime}s</span>
        </div>
      </div>
    `

    // Update practice interface display if present
    this.updatePracticeDisplay()
  }

  updatePracticeDisplay() {
    if (!this.hasContentTarget || !this.selectedPromptValue) return

    this.contentTarget.innerHTML = `<p>${this.selectedPromptValue.text}</p>`

    // Update target time display if present
    if (this.hasTargetTimeTarget) {
      const targetSeconds = this.selectedPromptValue.estimatedTime || this.selectedPromptValue.target_seconds || 60
      this.targetTimeTarget.innerHTML = `⏱️ ~${targetSeconds}s`
    }
  }

  usePrompt(event) {
    const promptText = event.target.dataset.prompt
    if (!promptText) return

    // Try to find the full prompt data to get the target time
    let estimatedTime = 60
    const promptElement = event.target.closest('.prompt-item')

    // Look for the prompt in our data
    if (this.promptsValue && typeof this.promptsValue === 'object') {
      for (const [category, categoryPrompts] of Object.entries(this.promptsValue)) {
        if (Array.isArray(categoryPrompts)) {
          const foundPrompt = categoryPrompts.find(p =>
            (typeof p === 'string' && p === promptText) ||
            (typeof p === 'object' && p.prompt === promptText)
          )
          if (foundPrompt && typeof foundPrompt === 'object') {
            estimatedTime = foundPrompt.target_seconds || 60
            break
          }
        }
      }
    }

    // Create a simple prompt object
    const prompt = {
      id: Date.now(),
      text: promptText,
      category: promptElement?.dataset.category || 'general',
      difficulty: 'medium',
      estimatedTime: estimatedTime
    }

    this.selectedPromptValue = prompt
    this.updatePracticeDisplay()

    this.dispatch('prompt-selected', {
      detail: { prompt },
      bubbles: true
    })
  }

  selectCategory(event) {
    const category = event.target.dataset.category

    // Update active tab
    document.querySelectorAll('.tab-btn').forEach(btn => {
      btn.classList.remove('active')
    })
    event.target.classList.add('active')

    // Filter prompt items
    if (this.hasLibraryTarget) {
      const promptItems = this.libraryTarget.querySelectorAll('.prompt-item')
      promptItems.forEach(item => {
        const itemCategory = item.dataset.category
        if (category === 'any' || itemCategory === category) {
          item.style.display = 'block'
        } else {
          item.style.display = 'none'
        }
      })
    }
  }

  clearSelection() {
    this.selectedPromptValue = null
    this.stopPracticeTimer()
    this.renderPrompts()
    
    if (this.hasSelectedTarget) {
      this.selectedTarget.innerHTML = ''
    }
  }

  shufflePrompt() {
    // For the new practice interface, shuffle from all available prompts
    const allPrompts = this.getAllAvailablePrompts()

    if (allPrompts.length === 0) {
      console.warn('No prompts available to shuffle')
      return
    }

    const randomIndex = Math.floor(Math.random() * allPrompts.length)
    const selectedPrompt = allPrompts[randomIndex]

    // Create a normalized prompt object
    const prompt = {
      id: Date.now(),
      text: selectedPrompt.text || selectedPrompt,
      category: selectedPrompt.category || 'general',
      difficulty: selectedPrompt.difficulty || 'medium',
      estimatedTime: selectedPrompt.estimatedTime || 60
    }

    this.selectedPromptValue = prompt
    this.updatePracticeDisplay()

    this.dispatch('prompt-shuffled', {
      detail: { prompt },
      bubbles: true
    })
  }

  getAllAvailablePrompts() {
    const prompts = []

    // Add prompts from the main prompts data
    if (this.promptsValue && typeof this.promptsValue === 'object') {
      for (const [category, categoryPrompts] of Object.entries(this.promptsValue)) {
        if (Array.isArray(categoryPrompts)) {
          categoryPrompts.forEach(prompt => {
            prompts.push({
              text: typeof prompt === 'string' ? prompt : prompt.prompt || prompt.text,
              category: category,
              difficulty: prompt.difficulty || 'medium',
              estimatedTime: prompt.target_seconds || 60
            })
          })
        }
      }
    }

    // Add some default prompts if none are loaded
    if (prompts.length === 0) {
      const defaultPrompts = [
        "What trade-off did you make recently and why?",
        "Tell me about a time you influenced a decision without authority.",
        "Explain your startup to a 10-year-old in 30s.",
        "Describe a failure that changed your perspective.",
        "What's the most important lesson you learned this year?",
        "How do you handle difficult conversations?",
        "What motivates you to do your best work?",
        "Describe a time you had to adapt quickly to change."
      ]

      defaultPrompts.forEach(text => {
        prompts.push({
          text: text,
          category: 'general',
          difficulty: 'medium',
          estimatedTime: 60
        })
      })
    }

    return prompts
  }

  resetUsedPrompts() {
    this.usedPrompts.clear()
    this.promptsValue.forEach(prompt => {
      prompt.used = false
      prompt.lastUsed = null
    })
    this.renderPrompts()
  }

  toggleFavorite(event) {
    event.stopPropagation()
    const promptId = parseInt(event.target.dataset.promptId)
    
    if (this.favorites.includes(promptId)) {
      this.favorites = this.favorites.filter(id => id !== promptId)
    } else {
      this.favorites.push(promptId)
    }
    
    this.saveFavorites()
    this.renderPrompts()
  }

  filterByDifficulty(event) {
    this.currentDifficulty = event.target.value
    this.filterPrompts()
  }

  toggleFavoritesOnly() {
    this.showFavoritesOnly = !this.showFavoritesOnly
    this.filterPrompts()
  }

  searchPrompts(event) {
    this.searchTerm = event.target.value.trim()
    this.filterPrompts()
  }

  startAutoShuffle() {
    if (this.shuffleTimer) return
    
    this.shuffleTimer = setInterval(() => {
      this.shufflePrompt()
    }, this.shuffleIntervalValue * 1000)
  }

  stopAutoShuffle() {
    if (this.shuffleTimer) {
      clearInterval(this.shuffleTimer)
      this.shuffleTimer = null
    }
  }

  toggleAutoShuffle() {
    this.autoShuffleValue = !this.autoShuffleValue
    
    if (this.autoShuffleValue) {
      this.startAutoShuffle()
    } else {
      this.stopAutoShuffle()
    }
  }

  startPracticeTimer(duration = null) {
    this.stopPracticeTimer()
    
    const timerDuration = duration || this.timerDurationValue
    let timeRemaining = timerDuration
    
    this.updateTimerDisplay(timeRemaining)
    
    this.practiceTimer = setInterval(() => {
      timeRemaining--
      this.updateTimerDisplay(timeRemaining)
      
      if (timeRemaining <= 0) {
        this.stopPracticeTimer()
        this.onTimerComplete()
      } else if (timeRemaining <= 10) {
        this.playTimerWarning()
      }
    }, 1000)
  }

  stopPracticeTimer() {
    if (this.practiceTimer) {
      clearInterval(this.practiceTimer)
      this.practiceTimer = null
    }
    
    if (this.hasTimerTarget) {
      this.timerTarget.innerHTML = ''
    }
  }

  updateTimerDisplay(seconds) {
    if (!this.hasTimerTarget) return
    
    const minutes = Math.floor(seconds / 60)
    const secs = seconds % 60
    const timeString = `${minutes}:${secs.toString().padStart(2, '0')}`
    
    const color = seconds <= 10 ? 'text-red-600' : seconds <= 30 ? 'text-orange-600' : 'text-green-600'
    
    this.timerTarget.innerHTML = `
      <div class="timer ${color} font-mono text-xl font-bold">
        ⏱️ ${timeString}
      </div>
    `
  }

  onTimerComplete() {
    this.dispatch('timer-complete', {
      detail: { prompt: this.selectedPromptValue },
      bubbles: true
    })
    
    if (this.autoShuffleValue) {
      this.shufflePrompt()
    }
  }

  playTimerWarning() {
  }

  setupKeyboardShortcuts() {
    this.keydownHandler = (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return

      switch (e.key) {
        case 's':
          if (e.ctrlKey || e.metaKey) {
            e.preventDefault()
            this.shufflePrompt()
          }
          break
        case 'r':
          if (e.ctrlKey || e.metaKey) {
            e.preventDefault()
            this.resetUsedPrompts()
          }
          break
        case '/':
          e.preventDefault()
          this.focusSearch()
          break
        case 'Escape':
          this.clearSelection()
          break
      }
    }

    document.addEventListener('keydown', this.keydownHandler)
  }

  removeKeyboardShortcuts() {
    if (this.keydownHandler) {
      document.removeEventListener('keydown', this.keydownHandler)
    }
  }

  focusSearch() {
    if (this.hasSearchTarget) {
      this.searchTarget.focus()
    }
  }

  updateStats() {
    const totalPrompts = this.filteredPrompts.length
    const usedPrompts = this.filteredPrompts.filter(p => this.usedPrompts.has(p.id)).length
    const favoritePrompts = this.filteredPrompts.filter(p => this.favorites.includes(p.id)).length

    this.dispatch('stats-update', {
      detail: { 
        total: totalPrompts,
        used: usedPrompts,
        favorites: favoritePrompts,
        remaining: totalPrompts - usedPrompts
      },
      bubbles: true
    })
  }

  loadFavorites() {
    try {
      const saved = localStorage.getItem('prompt-favorites')
      return saved ? JSON.parse(saved) : []
    } catch (error) {
      console.warn('Failed to parse favorites from localStorage:', error)
      // Clear corrupted data
      localStorage.removeItem('prompt-favorites')
      return []
    }
  }

  saveFavorites() {
    try {
      localStorage.setItem('prompt-favorites', JSON.stringify(this.favorites))
    } catch (error) {
      console.warn('Could not save favorites:', error)
    }
  }

  saveState() {
    try {
      const state = {
        currentCategory: this.currentCategory,
        currentDifficulty: this.currentDifficulty,
        usedPrompts: Array.from(this.usedPrompts),
        autoShuffle: this.autoShuffleValue,
        selectedPrompt: this.selectedPromptValue
      }
      localStorage.setItem('prompts-state', JSON.stringify(state))
    } catch (error) {
      console.warn('Could not save state:', error)
    }
  }

  restoreState() {
    try {
      const saved = localStorage.getItem('prompts-state')
      if (saved) {
        const state = JSON.parse(saved)
        this.currentCategory = state.currentCategory || 'all'
        this.currentDifficulty = state.currentDifficulty || 'all'
        this.usedPrompts = new Set(state.usedPrompts || [])
        this.autoShuffleValue = state.autoShuffle ?? false
        if (state.selectedPrompt) {
          this.selectedPromptValue = state.selectedPrompt
        }
      }
    } catch (error) {
      console.warn('Could not restore state:', error)
      // Clear corrupted data
      localStorage.removeItem('prompts-state')
    }
  }

  exportPrompts() {
    const data = {
      prompts: this.promptsValue,
      favorites: this.favorites,
      usedPrompts: Array.from(this.usedPrompts),
      exportDate: new Date().toISOString()
    }
    
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    
    const a = document.createElement('a')
    a.href = url
    a.download = 'prompts-export.json'
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    
    URL.revokeObjectURL(url)
  }

  loadDataFromScriptTags() {
    try {
      const promptsScript = document.getElementById('prompts-data')
      const categoriesScript = document.getElementById('categories-data')
      
      if (promptsScript && promptsScript.textContent) {
        const parsedPrompts = JSON.parse(promptsScript.textContent)
        this.promptsValue = parsedPrompts || []
      } else {
        this.promptsValue = []
      }
      
      if (categoriesScript && categoriesScript.textContent) {
        const parsedCategories = JSON.parse(categoriesScript.textContent)
        this.categoriesValue = parsedCategories || []
      } else {
        this.categoriesValue = []
      }
    } catch (error) {
      console.error('Error loading data from script tags:', error)
      this.promptsValue = []
      this.categoriesValue = []
    }
  }

  handleError(error) {
    console.error('Prompts controller error:', error)
    if (this.hasSelectedTarget) {
      this.selectedTarget.innerHTML = `
        <div class="error-message">
          <p>Error loading prompts. Please refresh the page and try again.</p>
          <details>
            <summary>Error details</summary>
            <pre>${error.message}</pre>
          </details>
        </div>
      `
    }
  }
}