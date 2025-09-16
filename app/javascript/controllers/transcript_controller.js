import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "word", "search", "highlighter", "issues", "timeline"]
  static values = { 
    transcript: Array,
    issues: Array,
    highlightIssues: Boolean,
    autoScroll: Boolean,
    showTimestamps: Boolean,
    searchable: Boolean
  }

  initialize() {
    this.currentTime = 0
    this.searchTerm = ""
    this.activeWord = null
    this.issueColors = {
      'filler_words': 'bg-red-200 text-red-800',
      'pace_too_fast': 'bg-orange-200 text-orange-800',
      'pace_too_slow': 'bg-blue-200 text-blue-800',
      'long_pause': 'bg-purple-200 text-purple-800',
      'unclear_speech': 'bg-pink-200 text-pink-800',
      'repetition': 'bg-green-200 text-green-800',
      'volume_low': 'bg-gray-200 text-gray-800',
      'volume_inconsistent': 'bg-yellow-200 text-yellow-800'
    }
  }

  connect() {
    this.transcriptValue = this.transcriptValue || []
    this.issuesValue = this.issuesValue || []
    this.highlightIssuesValue = this.highlightIssuesValue ?? true
    this.autoScrollValue = this.autoScrollValue ?? true
    this.showTimestampsValue = this.showTimestampsValue ?? false
    this.searchableValue = this.searchableValue ?? true

    this.renderTranscript()
    this.setupSearch()
    this.setupKeyboardShortcuts()
  }

  disconnect() {
    this.removeKeyboardShortcuts()
  }

  renderTranscript() {
    if (!this.hasContentTarget || !this.transcriptValue.length) return

    const transcriptHTML = this.buildTranscriptHTML()
    this.contentTarget.innerHTML = transcriptHTML

    if (this.highlightIssuesValue) {
      this.highlightIssues()
    }

    this.attachWordClickListeners()
  }

  buildTranscriptHTML() {
    return this.transcriptValue.map((segment, segmentIndex) => {
      const words = segment.words || []
      const timestamp = this.showTimestampsValue ? 
        `<span class="timestamp text-xs text-gray-500 mr-2">[${this.formatTime(segment.start)}]</span>` : ''

      const wordsHTML = words.map((word, wordIndex) => {
        const wordId = `word-${segmentIndex}-${wordIndex}`
        return `<span 
          class="word cursor-pointer hover:bg-gray-100 px-1 rounded"
          data-transcript-target="word"
          data-word-id="${wordId}"
          data-start-time="${word.start}"
          data-end-time="${word.end}"
          data-confidence="${word.confidence || 1}"
          data-action="click->transcript#jumpToWord"
        >${word.text}</span>`
      }).join(' ')

      return `
        <div class="transcript-segment mb-4 p-3 rounded-lg border border-gray-200" 
             data-segment-index="${segmentIndex}">
          ${timestamp}
          <div class="words leading-relaxed">${wordsHTML}</div>
        </div>
      `
    }).join('')
  }

  highlightIssues() {
    if (!this.highlightIssuesValue || !this.issuesValue.length) return

    this.issuesValue.forEach(issue => {
      this.highlightIssueInTranscript(issue)
    })
  }

  highlightIssueInTranscript(issue) {
    const words = this.contentTarget.querySelectorAll('[data-transcript-target="word"]')
    
    words.forEach(wordElement => {
      const startTime = parseFloat(wordElement.dataset.startTime)
      const endTime = parseFloat(wordElement.dataset.endTime)
      
      if (this.timeRangesOverlap(startTime, endTime, issue.start_time, issue.end_time)) {
        const colorClass = this.issueColors[issue.issue_type] || 'bg-gray-200 text-gray-800'
        wordElement.classList.add(...colorClass.split(' '))
        wordElement.title = `${issue.issue_type.replace('_', ' ').toUpperCase()}: ${issue.description}`
        wordElement.dataset.issueType = issue.issue_type
      }
    })
  }

  timeRangesOverlap(start1, end1, start2, end2) {
    return start1 < end2 && end1 > start2
  }

  attachWordClickListeners() {
    this.wordTargets.forEach(word => {
      word.addEventListener('dblclick', (e) => {
        this.selectWord(e.target)
      })
    })
  }

  setupSearch() {
    if (!this.searchableValue || !this.hasSearchTarget) return

    this.searchTarget.addEventListener('input', (e) => {
      this.searchTerm = e.target.value.toLowerCase()
      this.performSearch()
    })

    this.searchTarget.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault()
        this.jumpToNextSearchResult()
      } else if (e.key === 'Escape') {
        this.clearSearch()
      }
    })
  }

  setupKeyboardShortcuts() {
    this.keydownHandler = (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return

      switch (e.key) {
        case '/':
          e.preventDefault()
          this.focusSearch()
          break
        case 'n':
          if (e.ctrlKey || e.metaKey) {
            e.preventDefault()
            this.jumpToNextSearchResult()
          }
          break
        case 'p':
          if (e.ctrlKey || e.metaKey) {
            e.preventDefault()
            this.jumpToPreviousSearchResult()
          }
          break
        case 'Escape':
          this.clearSearch()
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

  updateCurrentTime(time) {
    this.currentTime = time
    this.highlightActiveWords()
    
    if (this.autoScrollValue) {
      this.scrollToCurrentTime()
    }
  }

  highlightActiveWords() {
    this.wordTargets.forEach(word => {
      const startTime = parseFloat(word.dataset.startTime)
      const endTime = parseFloat(word.dataset.endTime)
      
      if (this.currentTime >= startTime && this.currentTime <= endTime) {
        if (this.activeWord !== word) {
          this.clearActiveWord()
          this.activeWord = word
          word.classList.add('bg-blue-500', 'text-white', 'active-word')
        }
      }
    })
  }

  clearActiveWord() {
    if (this.activeWord) {
      this.activeWord.classList.remove('bg-blue-500', 'text-white', 'active-word')
      this.activeWord = null
    }
  }

  scrollToCurrentTime() {
    if (this.activeWord && this.hasContentTarget) {
      const rect = this.activeWord.getBoundingClientRect()
      const containerRect = this.contentTarget.getBoundingClientRect()
      
      if (rect.top < containerRect.top || rect.bottom > containerRect.bottom) {
        this.activeWord.scrollIntoView({ 
          behavior: 'smooth', 
          block: 'center' 
        })
      }
    }
  }

  jumpToWord(event) {
    const word = event.target
    const startTime = parseFloat(word.dataset.startTime)
    
    this.dispatch('seek', { 
      detail: { time: startTime },
      bubbles: true 
    })
  }

  selectWord(word) {
    this.clearSelection()
    word.classList.add('selected', 'bg-yellow-200')
    
    if (this.hasTimelineTarget) {
      const startTime = parseFloat(word.dataset.startTime)
      const endTime = parseFloat(word.dataset.endTime)
      this.highlightTimelineSegment(startTime, endTime)
    }
  }

  clearSelection() {
    const selected = this.contentTarget.querySelectorAll('.selected')
    selected.forEach(el => {
      el.classList.remove('selected', 'bg-yellow-200')
    })
  }

  highlightTimelineSegment(startTime, endTime) {
  }

  performSearch() {
    this.clearSearchHighlights()
    
    if (!this.searchTerm) return

    const words = this.wordTargets
    this.searchResults = []

    words.forEach((word, index) => {
      if (word.textContent.toLowerCase().includes(this.searchTerm)) {
        word.classList.add('search-highlight', 'bg-yellow-300')
        this.searchResults.push({ element: word, index })
      }
    })

    this.currentSearchIndex = -1
    this.updateSearchStatus()
  }

  clearSearchHighlights() {
    const highlighted = this.contentTarget.querySelectorAll('.search-highlight')
    highlighted.forEach(el => {
      el.classList.remove('search-highlight', 'bg-yellow-300', 'current-search-result', 'ring-2', 'ring-yellow-500')
    })
  }

  clearSearch() {
    if (this.hasSearchTarget) {
      this.searchTarget.value = ''
    }
    this.searchTerm = ''
    this.clearSearchHighlights()
    this.searchResults = []
    this.updateSearchStatus()
  }

  focusSearch() {
    if (this.hasSearchTarget) {
      this.searchTarget.focus()
    }
  }

  jumpToNextSearchResult() {
    if (!this.searchResults || !this.searchResults.length) return

    this.clearCurrentSearchHighlight()
    this.currentSearchIndex = (this.currentSearchIndex + 1) % this.searchResults.length
    this.highlightCurrentSearchResult()
  }

  jumpToPreviousSearchResult() {
    if (!this.searchResults || !this.searchResults.length) return

    this.clearCurrentSearchHighlight()
    this.currentSearchIndex = this.currentSearchIndex <= 0 ? 
      this.searchResults.length - 1 : this.currentSearchIndex - 1
    this.highlightCurrentSearchResult()
  }

  clearCurrentSearchHighlight() {
    const current = this.contentTarget.querySelector('.current-search-result')
    if (current) {
      current.classList.remove('current-search-result', 'ring-2', 'ring-yellow-500')
    }
  }

  highlightCurrentSearchResult() {
    if (!this.searchResults || this.currentSearchIndex < 0) return

    const result = this.searchResults[this.currentSearchIndex]
    result.element.classList.add('current-search-result', 'ring-2', 'ring-yellow-500')
    result.element.scrollIntoView({ behavior: 'smooth', block: 'center' })
    
    this.updateSearchStatus()
  }

  updateSearchStatus() {
    if (!this.searchResults) return

    const count = this.searchResults.length
    const current = this.currentSearchIndex + 1
    
    this.dispatch('search-update', {
      detail: { 
        count, 
        current: count > 0 ? current : 0,
        term: this.searchTerm 
      },
      bubbles: true
    })
  }

  exportTranscript() {
    const text = this.transcriptValue.map(segment => {
      const timestamp = this.showTimestampsValue ? 
        `[${this.formatTime(segment.start)}] ` : ''
      const words = segment.words ? segment.words.map(w => w.text).join(' ') : ''
      return timestamp + words
    }).join('\n\n')

    const blob = new Blob([text], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    
    const a = document.createElement('a')
    a.href = url
    a.download = 'transcript.txt'
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    
    URL.revokeObjectURL(url)
  }

  getWordCount() {
    return this.transcriptValue.reduce((count, segment) => {
      return count + (segment.words ? segment.words.length : 0)
    }, 0)
  }

  getTranscriptDuration() {
    if (!this.transcriptValue.length) return 0
    
    const lastSegment = this.transcriptValue[this.transcriptValue.length - 1]
    return lastSegment.end || 0
  }

  findWordsInTimeRange(startTime, endTime) {
    const words = []
    
    this.transcriptValue.forEach(segment => {
      if (segment.words) {
        segment.words.forEach(word => {
          if (this.timeRangesOverlap(word.start, word.end, startTime, endTime)) {
            words.push(word)
          }
        })
      }
    })
    
    return words
  }

  formatTime(seconds) {
    if (isNaN(seconds)) return '0:00'
    
    const minutes = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${minutes}:${secs.toString().padStart(2, '0')}`
  }

  toggleTimestamps() {
    this.showTimestampsValue = !this.showTimestampsValue
    this.renderTranscript()
  }

  toggleIssueHighlighting() {
    this.highlightIssuesValue = !this.highlightIssuesValue
    this.renderTranscript()
  }

  toggleAutoScroll() {
    this.autoScrollValue = !this.autoScrollValue
  }
}