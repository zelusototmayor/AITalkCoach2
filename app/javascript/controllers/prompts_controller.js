import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "category", "prompt", "selected", "shuffle", "filter", "search",
    "favorite", "difficulty", "tags", "timer", "practiceMode", "selectedId",
    "display", "content", "library", "targetTime", "card", "grid",
    "searchInput", "filterBtn", "noResults", "noFavorites", "modalOverlay",
    "modalBody", "modalTitle", "modalPracticeBtn", "showMoreBtn", "durationTab",
    "durationPromptsContainer", "difficultyFilter", "durationFilter", "categoryFilter",
    "focusFilter"
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
    this.visibleCountByCategory = {}
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
        this.autoGenerateSessionTitle(this.selectedPromptValue)
      } else if (!this.selectedPromptValue) {
        // Create a fallback prompt if no prompts are available
        const fallbackPrompt = {
          id: 'fallback',
          text: 'What trade-off did you make recently and why?',
          title: 'Quick Question',
          category: 'general',
          difficulty: 'intermediate',
          estimatedTime: 60
        }
        this.selectedPromptValue = fallbackPrompt
        this.updateSelectedDisplay()
        this.autoGenerateSessionTitle(fallbackPrompt)
      }

      // Also auto-generate title on page load if we have a prompt from URL params
      setTimeout(() => {
        this.ensureSessionTitleIsPopulated()
      }, 100)

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
            difficulty: prompt.difficulty || 'intermediate',
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
      prompt.difficulty = prompt.difficulty || 'intermediate'
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
    const normalizedDifficulty = difficulty?.toLowerCase()
    switch (normalizedDifficulty) {
      case 'beginner': return 'bg-green-100 text-green-800'
      case 'intermediate': return 'bg-yellow-100 text-yellow-800'
      case 'advanced': return 'bg-red-100 text-red-800'
      // Legacy support
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
      this.autoGenerateSessionTitle(prompt)

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
    let title = 'Practice Prompt'
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
            title = foundPrompt.title || 'Practice Prompt'
            break
          }
        }
      }
    }

    // Create a simple prompt object
    const prompt = {
      id: Date.now(),
      text: promptText,
      title: title,
      category: promptElement?.dataset.category || 'general',
      difficulty: 'medium',
      estimatedTime: estimatedTime
    }

    this.selectedPromptValue = prompt
    this.updatePracticeDisplay()
    this.autoGenerateSessionTitle(prompt)

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
      title: selectedPrompt.title || 'Random Prompt',
      category: selectedPrompt.category || 'general',
      difficulty: selectedPrompt.difficulty || 'intermediate',
      estimatedTime: selectedPrompt.estimatedTime || 60
    }

    this.selectedPromptValue = prompt
    this.updatePracticeDisplay()
    this.autoGenerateSessionTitle(prompt)

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
              difficulty: prompt.difficulty || 'intermediate',
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
          difficulty: 'intermediate',
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

  autoGenerateSessionTitle(prompt) {
    const baseTitle = this.getBaseTitle(prompt)
    const uniqueIdentifier = this.getUniqueIdentifier()
    const generatedTitle = `${baseTitle} ${uniqueIdentifier}`

    // Update title inputs in both form sections
    this.updateTitleInputs(generatedTitle)

    // Dispatch event to notify other controllers
    this.dispatch('title-generated', {
      detail: { title: generatedTitle, prompt },
      bubbles: true
    })
  }

  getBaseTitle(prompt) {
    // Prioritize prompt title, fall back to shortened text, then default
    if (prompt.title) {
      return prompt.title
    }

    if (prompt.text) {
      // Use first part of prompt text, shortened to reasonable length
      const text = prompt.text.trim()
      if (text.length > 40) {
        return text.substring(0, 37) + '...'
      }
      return text
    }

    // Fallback based on category
    const category = prompt.category || 'general'
    const categoryTitles = {
      'interviews': 'Interview Practice',
      'pitching': 'Pitch Practice',
      'story': 'Storytelling Practice',
      'general': 'Practice Session'
    }

    return categoryTitles[category] || 'Practice Session'
  }

  getUniqueIdentifier() {
    const now = new Date()

    // Check if we already have a session today
    const today = now.toDateString()
    const sessionKey = `session_count_${today}`
    let sessionCount = parseInt(localStorage.getItem(sessionKey) || '0') + 1
    localStorage.setItem(sessionKey, sessionCount.toString())

    // Format: #1, #2, etc. for multiple sessions same day, or just date for first
    if (sessionCount === 1) {
      return `- ${now.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric'
      })}`
    } else {
      return `#${sessionCount} - ${now.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric'
      })}`
    }
  }

  updateTitleInputs(title) {
    // Update main session form title input
    const mainTitleInput = document.querySelector('input[name="session[title]"]')
    if (mainTitleInput) {
      mainTitleInput.value = title
    }

    // Update post-recording form title input (used by recorder controller)
    const recorderTitleInput = document.querySelector('[data-recorder-target="titleInput"]')
    if (recorderTitleInput) {
      recorderTitleInput.value = title
    }

    // Update any other title inputs that might exist
    const allTitleInputs = document.querySelectorAll('input[type="text"][placeholder*="title"], input[type="text"][placeholder*="Title"]')
    allTitleInputs.forEach(input => {
      if (input.name && input.name.includes('title')) {
        input.value = title
      }
    })
  }

  ensureSessionTitleIsPopulated() {
    // Check if any title input is empty and populate it
    const titleInputs = [
      document.querySelector('input[name="session[title]"]'),
      document.querySelector('[data-recorder-target="titleInput"]')
    ].filter(Boolean)

    const hasEmptyTitle = titleInputs.some(input => !input.value.trim())

    if (hasEmptyTitle && this.selectedPromptValue) {
      this.autoGenerateSessionTitle(this.selectedPromptValue)
    } else if (hasEmptyTitle) {
      // Generate a basic title if no prompt is available
      const fallbackTitle = `Practice Session - ${new Date().toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric'
      })}`
      this.updateTitleInputs(fallbackTitle)
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

  showMore(event) {
    const category = event.target.dataset.category
    const categoryCards = this.cardTargets.filter(card =>
      card.dataset.category === category
    )

    // Initialize visible count for this category if not set
    if (!this.visibleCountByCategory[category]) {
      this.visibleCountByCategory[category] = 6
    }

    // Show next 6 prompts (reduced from 10 for less cognitive overload)
    const currentCount = this.visibleCountByCategory[category]
    const newCount = currentCount + 6

    categoryCards.forEach((card, index) => {
      if (index >= currentCount && index < newCount) {
        card.style.display = ''
      }
    })

    this.visibleCountByCategory[category] = newCount

    // Update button or hide if all are shown
    const totalCount = categoryCards.length
    const remainingCount = totalCount - newCount

    if (remainingCount <= 0) {
      // Hide the "Show More" button
      event.target.closest('.show-more-container').style.display = 'none'
    } else {
      // Update the button text
      event.target.textContent = `Show More (${remainingCount} more)`
    }
  }

  clearFilters() {
    this.currentCategory = 'all'
    this.searchTerm = ''
    this.showFavoritesOnly = false

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
    }

    // Clear all filter dropdowns
    if (this.hasDifficultyFilterTarget) {
      this.difficultyFilterTarget.selectedIndex = -1
    }
    if (this.hasDurationFilterTarget) {
      this.durationFilterTarget.selectedIndex = -1
    }
    if (this.hasCategoryFilterTarget) {
      this.categoryFilterTarget.selectedIndex = -1
    }
    if (this.hasFocusFilterTarget) {
      this.focusFilterTarget.selectedIndex = -1
    }

    this.applyFilters()
  }

  applyFilters() {
    // Get selected values from each filter
    const selectedDifficulties = this.hasDifficultyFilterTarget
      ? Array.from(this.difficultyFilterTarget.selectedOptions).map(opt => opt.value)
      : []

    const selectedDurations = this.hasDurationFilterTarget
      ? Array.from(this.durationFilterTarget.selectedOptions).map(opt => opt.value)
      : []

    const selectedCategories = this.hasCategoryFilterTarget
      ? Array.from(this.categoryFilterTarget.selectedOptions).map(opt => opt.value)
      : []

    const selectedFocusAreas = this.hasFocusFilterTarget
      ? Array.from(this.focusFilterTarget.selectedOptions).map(opt => opt.value)
      : []

    // Get search term
    const searchTerm = this.hasSearchInputTarget
      ? this.searchInputTarget.value.toLowerCase().trim()
      : ''

    // Filter cards
    const allCards = this.cardTargets
    let visibleCount = 0

    allCards.forEach(card => {
      let shouldShow = true

      // Check difficulty filter
      if (selectedDifficulties.length > 0) {
        const cardDifficulty = card.dataset.difficulty
        if (!selectedDifficulties.includes(cardDifficulty)) {
          shouldShow = false
        }
      }

      // Check duration filter
      if (selectedDurations.length > 0) {
        const cardDuration = card.dataset.duration
        if (!selectedDurations.includes(cardDuration)) {
          shouldShow = false
        }
      }

      // Check category filter
      if (selectedCategories.length > 0) {
        const cardCategory = card.dataset.category
        if (!selectedCategories.includes(cardCategory)) {
          shouldShow = false
        }
      }

      // Check focus areas filter
      if (selectedFocusAreas.length > 0) {
        const cardFocusAreas = (card.dataset.focusAreas || '').split(',').map(f => f.trim().toLowerCase())
        const hasMatchingFocus = selectedFocusAreas.some(focus =>
          cardFocusAreas.some(cardFocus => cardFocus.includes(focus.toLowerCase()))
        )
        if (!hasMatchingFocus) {
          shouldShow = false
        }
      }

      // Check search term
      if (searchTerm) {
        const cardText = card.textContent.toLowerCase()
        if (!cardText.includes(searchTerm)) {
          shouldShow = false
        }
      }

      // Check favorites filter
      if (this.showFavoritesOnly) {
        const promptId = card.dataset.promptId
        if (!this.favorites.includes(promptId)) {
          shouldShow = false
        }
      }

      // Show/hide card
      if (shouldShow) {
        card.style.display = ''
        visibleCount++
      } else {
        card.style.display = 'none'
      }
    })

    // Show/hide "no results" message
    if (this.hasNoResultsTarget) {
      this.noResultsTarget.style.display = visibleCount === 0 ? 'block' : 'none'
    }

    // Hide category sections that have no visible cards
    document.querySelectorAll('.category-section').forEach(section => {
      const visibleCards = section.querySelectorAll('.prompt-card[style=""], .prompt-card:not([style*="display: none"])')
      section.style.display = visibleCards.length > 0 ? '' : 'none'
    })
  }

  toggleFavorites() {
    this.showFavoritesOnly = !this.showFavoritesOnly
    this.applyFilters()
  }

  closeModal() {
    if (this.hasModalOverlayTarget) {
      this.modalOverlayTarget.style.display = 'none'
    }
  }

  previewPrompt(event) {
    // Placeholder for preview functionality
    console.log('Preview prompt:', event.target.dataset.promptId)
  }

  sharePrompt(event) {
    // Placeholder for share functionality
    console.log('Share prompt:', event.target.dataset.promptId)
  }

  addToPlaylist(event) {
    // Placeholder for add to playlist functionality
    console.log('Add to playlist:', event.target.dataset.promptId)
  }

  startRandomPractice() {
    this.shufflePrompt()
  }

  startDailyPractice() {
    // Placeholder for daily practice
    console.log('Starting daily practice')
  }

  startFocusedPractice() {
    // Placeholder for focused practice
    console.log('Starting focused practice')
  }

  shuffleRandom() {
    this.shufflePrompt()
  }

  // New methods for enhanced UI
  filterByDuration(event) {
    const duration = event.target.dataset.duration

    // Update active tab
    if (this.hasDurationTabTarget) {
      this.durationTabTargets.forEach(tab => tab.classList.remove('active'))
      event.target.classList.add('active')
    }

    // Show/hide duration groups
    const groups = document.querySelectorAll('[data-duration-group]')
    groups.forEach(group => {
      if (group.dataset.durationGroup === duration) {
        group.style.display = ''
      } else {
        group.style.display = 'none'
      }
    })

    // Save preference to localStorage
    try {
      localStorage.setItem('preferred-duration', duration)
    } catch (error) {
      console.warn('Could not save duration preference:', error)
    }
  }

  toggleCategoryExpansion(event) {
    const category = event.target.dataset.category
    const categorySection = event.target.closest('.category-section')
    const hiddenCards = categorySection.querySelectorAll('[data-prompt-index]:not([style*="display: none"])')
    const allCards = categorySection.querySelectorAll('[data-category-item]')
    const toggleText = event.target.querySelector('.toggle-text')
    const toggleIcon = event.target.querySelector('.toggle-icon')

    // Check if currently expanded
    const isExpanded = allCards.length === hiddenCards.length

    if (isExpanded) {
      // Collapse - hide cards after index 5
      allCards.forEach((card, index) => {
        if (parseInt(card.dataset.promptIndex) >= 6) {
          card.style.display = 'none'
        }
      })
      toggleText.textContent = 'Show all'
      toggleIcon.textContent = '▼'
    } else {
      // Expand - show all cards
      allCards.forEach(card => {
        card.style.display = ''
      })
      toggleText.textContent = 'Show less'
      toggleIcon.textContent = '▲'
    }

    // Track expansion state
    try {
      const expandedCategories = JSON.parse(localStorage.getItem('expanded-categories') || '[]')
      if (isExpanded) {
        const index = expandedCategories.indexOf(category)
        if (index > -1) expandedCategories.splice(index, 1)
      } else {
        if (!expandedCategories.includes(category)) expandedCategories.push(category)
      }
      localStorage.setItem('expanded-categories', JSON.stringify(expandedCategories))
    } catch (error) {
      console.warn('Could not save category expansion state:', error)
    }
  }

  showAllDuration(event) {
    const duration = event.target.dataset.duration
    const durationGroup = document.querySelector(`[data-duration-group="${duration}"]`)

    if (durationGroup) {
      const allCards = durationGroup.querySelectorAll('.prompt-card')
      allCards.forEach(card => {
        card.style.display = ''
      })

      // Hide the "Show all" button
      event.target.closest('.show-all-duration').style.display = 'none'
    }
  }

  markPromptCompleted(promptId) {
    try {
      const completed = this.getCompletedPrompts()
      if (!completed.includes(promptId)) {
        completed.push(promptId)
        localStorage.setItem('completed-prompts', JSON.stringify(completed))

        // Update UI to show completion
        this.updateCompletionIndicators()
      }
    } catch (error) {
      console.warn('Could not mark prompt as completed:', error)
    }
  }

  getCompletedPrompts() {
    try {
      const saved = localStorage.getItem('completed-prompts')
      return saved ? JSON.parse(saved) : []
    } catch (error) {
      console.warn('Could not load completed prompts:', error)
      return []
    }
  }

  updateCompletionIndicators() {
    const completed = this.getCompletedPrompts()

    // Add checkmarks or styles to completed prompts
    this.cardTargets.forEach(card => {
      const promptId = card.dataset.promptId
      if (completed.includes(promptId)) {
        card.classList.add('completed')

        // Add visual indicator if not present
        if (!card.querySelector('.completion-badge')) {
          const badge = document.createElement('span')
          badge.className = 'completion-badge'
          badge.textContent = '✓'
          badge.title = 'Completed'
          card.querySelector('.prompt-header')?.appendChild(badge)
        }
      }
    })
  }

  restoreExpandedCategories() {
    try {
      const expanded = JSON.parse(localStorage.getItem('expanded-categories') || '[]')
      expanded.forEach(category => {
        const categorySection = document.querySelector(`[data-category="${category}"]`)
        if (categorySection) {
          const toggleBtn = categorySection.querySelector('.btn-category-toggle')
          if (toggleBtn) {
            // Simulate click to expand
            toggleBtn.click()
          }
        }
      })
    } catch (error) {
      console.warn('Could not restore expanded categories:', error)
    }
  }

  restorePreferredDuration() {
    try {
      const preferredDuration = localStorage.getItem('preferred-duration')
      if (preferredDuration) {
        const durationTab = document.querySelector(`[data-duration="${preferredDuration}"]`)
        if (durationTab) {
          durationTab.click()
        }
      }
    } catch (error) {
      console.warn('Could not restore preferred duration:', error)
    }
  }

  initialize() {
    super.initialize && super.initialize()

    // Restore UI state
    setTimeout(() => {
      this.updateCompletionIndicators()
      this.restoreExpandedCategories()
      this.restorePreferredDuration()
    }, 100)
  }
}