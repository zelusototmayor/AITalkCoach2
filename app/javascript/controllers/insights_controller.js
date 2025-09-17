import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "sparkline", "metric", "trend", "chart", "summary", "filter", 
    "dateRange", "comparison", "export", "insights"
  ]
  static values = { 
    sessions: Array,
    metrics: Array,
    timeframe: String,
    showTrends: Boolean,
    autoRefresh: Boolean,
    refreshInterval: Number
  }

  initialize() {
    this.chartData = {}
    this.currentMetric = 'clarity_score'
    this.refreshTimer = null
    this.sparklineHeight = 40
    this.sparklineWidth = 100
    this.colors = {
      clarity_score: '#10b981',
      wpm: '#3b82f6',
      filler_rate: '#ef4444',
      pace_consistency: '#8b5cf6',
      volume_consistency: '#f59e0b',
      engagement_score: '#ec4899',
      fluency_score: '#06b6d4',
      overall_score: '#6366f1'
    }
  }

  connect() {
    this.sessionsValue = this.sessionsValue || []
    this.metricsValue = this.metricsValue || []
    this.timeframeValue = this.timeframeValue || '7d'
    this.showTrendsValue = this.showTrendsValue ?? true
    this.autoRefreshValue = this.autoRefreshValue ?? false
    this.refreshIntervalValue = this.refreshIntervalValue || 30

    this.processData()
    this.renderSparklines()
    this.renderMetrics()
    this.renderTrends()
    this.generateInsights()
    
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    }
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  processData() {
    this.chartData = this.groupSessionsByTimeframe()
    this.calculateTrends()
    this.identifyPatterns()
  }

  groupSessionsByTimeframe() {
    const now = new Date()
    const timeframeDays = this.getTimeframeDays()
    const cutoffDate = new Date(now - timeframeDays * 24 * 60 * 60 * 1000)
    
    const filteredSessions = this.sessionsValue.filter(session => 
      new Date(session.created_at) >= cutoffDate
    )

    const groupedData = {}
    const metricKeys = ['clarity_score', 'wpm', 'filler_rate', 'pace_consistency', 'volume_consistency', 'engagement_score', 'fluency_score', 'overall_score']
    
    metricKeys.forEach(metric => {
      groupedData[metric] = this.createTimeSeriesData(filteredSessions, metric, timeframeDays)
    })

    return groupedData
  }

  getTimeframeDays() {
    switch (this.timeframeValue) {
      case '1d': return 1
      case '7d': return 7
      case '30d': return 30
      case '90d': return 90
      default: return 7
    }
  }

  createTimeSeriesData(sessions, metric, days) {
    const data = []
    const now = new Date()
    
    for (let i = days - 1; i >= 0; i--) {
      const date = new Date(now - i * 24 * 60 * 60 * 1000)
      const dayStart = new Date(date.setHours(0, 0, 0, 0))
      const dayEnd = new Date(date.setHours(23, 59, 59, 999))
      
      const daySessions = sessions.filter(session => {
        const sessionDate = new Date(session.created_at)
        return sessionDate >= dayStart && sessionDate <= dayEnd
      })
      
      const values = daySessions
        .map(session => this.getMetricValue(session, metric))
        .filter(value => value !== null)
      
      const avgValue = values.length > 0 ? 
        values.reduce((sum, val) => sum + val, 0) / values.length : null
      
      data.push({
        date: dayStart,
        value: avgValue,
        sessionCount: daySessions.length,
        sessions: daySessions
      })
    }
    
    return data
  }

  getMetricValue(session, metric) {
    // First try the flat structure that we now store in analysis_data
    if (session.analysis_data) {
      switch (metric) {
        case 'clarity_score':
          return session.analysis_data.clarity_score
        case 'wpm':
          return session.analysis_data.wpm
        case 'filler_rate':
          return session.analysis_data.filler_rate
        case 'pace_consistency':
          return session.analysis_data.pace_consistency
        case 'volume_consistency':
          return session.analysis_data.volume_consistency || session.analysis_data.speech_to_silence_ratio
        case 'engagement_score':
          return session.analysis_data.engagement_score
        case 'fluency_score':
          return session.analysis_data.fluency_score
        case 'overall_score':
          return session.analysis_data.overall_score
      }
    }

    // Fallback to nested metrics structure
    if (!session.metrics) return null

    switch (metric) {
      case 'clarity_score':
        return session.metrics.clarity_score
      case 'wpm':
        return session.metrics.words_per_minute
      case 'filler_rate':
        return session.metrics.filler_rate
      case 'pace_consistency':
        return session.metrics.pace_consistency
      case 'volume_consistency':
        return session.metrics.volume_consistency
      case 'engagement_score':
        return session.metrics.engagement_score
      default:
        return null
    }
  }

  calculateTrends() {
    this.trends = {}
    
    Object.keys(this.chartData).forEach(metric => {
      const data = this.chartData[metric].filter(d => d.value !== null)
      if (data.length < 2) {
        this.trends[metric] = { direction: 'stable', change: 0, confidence: 'low' }
        return
      }
      
      const trend = this.calculateLinearTrend(data.map(d => d.value))
      this.trends[metric] = trend
    })
  }

  calculateLinearTrend(values) {
    const n = values.length
    if (n < 2) return { direction: 'stable', change: 0, confidence: 'low' }
    
    const x = Array.from({ length: n }, (_, i) => i)
    const sumX = x.reduce((a, b) => a + b, 0)
    const sumY = values.reduce((a, b) => a + b, 0)
    const sumXY = x.reduce((sum, xi, i) => sum + xi * values[i], 0)
    const sumXX = x.reduce((sum, xi) => sum + xi * xi, 0)
    
    const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
    const intercept = (sumY - slope * sumX) / n
    
    const predicted = x.map(xi => slope * xi + intercept)
    const residuals = values.map((yi, i) => yi - predicted[i])
    const mse = residuals.reduce((sum, r) => sum + r * r, 0) / n
    const variance = values.reduce((sum, yi) => sum + Math.pow(yi - sumY / n, 2), 0) / n
    const rSquared = 1 - (mse / variance)
    
    const change = ((values[n - 1] - values[0]) / values[0]) * 100
    const direction = Math.abs(change) < 2 ? 'stable' : change > 0 ? 'improving' : 'declining'
    const confidence = rSquared > 0.7 ? 'high' : rSquared > 0.4 ? 'medium' : 'low'
    
    return { direction, change, confidence, slope, rSquared }
  }

  identifyPatterns() {
    this.patterns = {
      streaks: this.findStreaks(),
      dayOfWeekPatterns: this.analyzeDayOfWeekPatterns(),
      timeOfDayPatterns: this.analyzeTimeOfDayPatterns(),
      sessionLengthImpact: this.analyzeSessionLengthImpact()
    }
  }

  findStreaks() {
    const streaks = {}
    Object.keys(this.chartData).forEach(metric => {
      const data = this.chartData[metric]
      streaks[metric] = this.findMetricStreaks(data, metric)
    })
    return streaks
  }

  findMetricStreaks(data, metric) {
    let currentStreak = 0
    let maxStreak = 0
    let streakType = null
    const threshold = this.getImprovementThreshold(metric)
    let previousValue = null
    
    data.forEach(point => {
      if (point.value === null) {
        currentStreak = 0
        return
      }
      
      if (previousValue !== null) {
        const isImproving = this.isImprovement(previousValue, point.value, metric)
        const change = Math.abs(point.value - previousValue)
        
        if (isImproving && change >= threshold) {
          if (streakType !== 'improving') {
            currentStreak = 1
            streakType = 'improving'
          } else {
            currentStreak++
          }
        } else if (!isImproving && change >= threshold) {
          if (streakType !== 'declining') {
            currentStreak = 1
            streakType = 'declining'
          } else {
            currentStreak++
          }
        } else {
          currentStreak = 0
          streakType = null
        }
        
        maxStreak = Math.max(maxStreak, currentStreak)
      }
      
      previousValue = point.value
    })
    
    return { current: currentStreak, max: maxStreak, type: streakType }
  }

  isImprovement(oldValue, newValue, metric) {
    const badMetrics = ['filler_rate']
    return badMetrics.includes(metric) ? newValue < oldValue : newValue > oldValue
  }

  getImprovementThreshold(metric) {
    switch (metric) {
      case 'clarity_score':
      case 'engagement_score':
        return 0.05
      case 'wpm':
        return 5
      case 'filler_rate':
        return 0.01
      case 'pace_consistency':
      case 'volume_consistency':
        return 0.03
      default:
        return 0.05
    }
  }

  analyzeDayOfWeekPatterns() {
    const dayData = {}
    for (let i = 0; i < 7; i++) dayData[i] = []
    
    this.sessionsValue.forEach(session => {
      const dayOfWeek = new Date(session.created_at).getDay()
      dayData[dayOfWeek].push(session)
    })
    
    const dayAverages = {}
    Object.keys(dayData).forEach(day => {
      const sessions = dayData[day]
      if (sessions.length === 0) return
      
      dayAverages[day] = {
        sessionCount: sessions.length,
        avgClarity: this.calculateAverage(sessions, 'clarity_score'),
        avgWpm: this.calculateAverage(sessions, 'wpm'),
        avgFillerRate: this.calculateAverage(sessions, 'filler_rate')
      }
    })
    
    return dayAverages
  }

  analyzeTimeOfDayPatterns() {
    const hourData = {}
    for (let i = 0; i < 24; i++) hourData[i] = []
    
    this.sessionsValue.forEach(session => {
      const hour = new Date(session.created_at).getHours()
      hourData[hour].push(session)
    })
    
    const hourAverages = {}
    Object.keys(hourData).forEach(hour => {
      const sessions = hourData[hour]
      if (sessions.length === 0) return
      
      hourAverages[hour] = {
        sessionCount: sessions.length,
        avgClarity: this.calculateAverage(sessions, 'clarity_score'),
        performance: this.calculateOverallPerformance(sessions)
      }
    })
    
    return hourAverages
  }

  analyzeSessionLengthImpact() {
    const buckets = { short: [], medium: [], long: [] }
    
    this.sessionsValue.forEach(session => {
      const duration = session.duration || 0
      if (duration < 60) buckets.short.push(session)
      else if (duration < 180) buckets.medium.push(session)
      else buckets.long.push(session)
    })
    
    const analysis = {}
    Object.keys(buckets).forEach(bucket => {
      const sessions = buckets[bucket]
      if (sessions.length === 0) return
      
      analysis[bucket] = {
        count: sessions.length,
        avgClarity: this.calculateAverage(sessions, 'clarity_score'),
        avgWpm: this.calculateAverage(sessions, 'wpm'),
        avgFillerRate: this.calculateAverage(sessions, 'filler_rate')
      }
    })
    
    return analysis
  }

  calculateAverage(sessions, metric) {
    const values = sessions
      .map(session => this.getMetricValue(session, metric))
      .filter(value => value !== null)
    
    return values.length > 0 ? values.reduce((sum, val) => sum + val, 0) / values.length : null
  }

  calculateOverallPerformance(sessions) {
    const clarity = this.calculateAverage(sessions, 'clarity_score') || 0
    const wpmScore = Math.min((this.calculateAverage(sessions, 'wpm') || 0) / 150, 1)
    const fillerPenalty = (this.calculateAverage(sessions, 'filler_rate') || 0) * 2
    
    return Math.max(0, (clarity + wpmScore - fillerPenalty) / 2)
  }

  renderSparklines() {
    if (!this.hasSparklineTarget) return
    
    const sparklineHTML = Object.keys(this.chartData).map(metric => {
      const data = this.chartData[metric]
      const trend = this.trends[metric] || { direction: 'stable', change: 0 }
      const color = this.colors[metric] || '#6b7280'
      
      return `
        <div class="sparkline-container p-4 bg-white rounded-lg border border-gray-200">
          <div class="flex justify-between items-start mb-2">
            <h3 class="text-sm font-medium text-gray-700">${this.formatMetricName(metric)}</h3>
            <span class="trend-indicator text-xs ${this.getTrendColorClass(trend.direction)}">
              ${this.getTrendIcon(trend.direction)} ${Math.abs(trend.change).toFixed(1)}%
            </span>
          </div>
          <div class="sparkline-chart mb-2" data-metric="${metric}">
            ${this.createSparklineSVG(data, color)}
          </div>
          <div class="text-xs text-gray-500">
            ${data.filter(d => d.value !== null).length} sessions in ${this.timeframeValue}
          </div>
        </div>
      `
    }).join('')
    
    this.sparklineTarget.innerHTML = sparklineHTML
  }

  createSparklineSVG(data, color) {
    const validData = data.filter(d => d.value !== null)
    if (validData.length < 2) {
      return `<div class="text-xs text-gray-400 text-center py-4">Insufficient data</div>`
    }
    
    const values = validData.map(d => d.value)
    const minValue = Math.min(...values)
    const maxValue = Math.max(...values)
    const range = maxValue - minValue || 1
    
    const points = validData.map((d, i) => {
      const x = (i / (validData.length - 1)) * this.sparklineWidth
      const y = this.sparklineHeight - ((d.value - minValue) / range) * this.sparklineHeight
      return `${x},${y}`
    }).join(' ')
    
    const lastValue = values[values.length - 1]
    const lastX = this.sparklineWidth
    const lastY = this.sparklineHeight - ((lastValue - minValue) / range) * this.sparklineHeight
    
    return `
      <svg width="${this.sparklineWidth}" height="${this.sparklineHeight}" class="w-full">
        <polyline 
          fill="none" 
          stroke="${color}" 
          stroke-width="2" 
          points="${points}"
        />
        <circle 
          cx="${lastX}" 
          cy="${lastY}" 
          r="3" 
          fill="${color}"
        />
      </svg>
    `
  }

  formatMetricName(metric) {
    const names = {
      clarity_score: 'Clarity',
      wpm: 'Words/Min',
      filler_rate: 'Filler Rate',
      pace_consistency: 'Pace',
      volume_consistency: 'Volume',
      engagement_score: 'Engagement',
      fluency_score: 'Fluency',
      overall_score: 'Overall Score'
    }
    return names[metric] || metric
  }

  getTrendColorClass(direction) {
    switch (direction) {
      case 'improving': return 'text-green-600'
      case 'declining': return 'text-red-600'
      default: return 'text-gray-500'
    }
  }

  getTrendIcon(direction) {
    switch (direction) {
      case 'improving': return '↗'
      case 'declining': return '↘'
      default: return '→'
    }
  }

  renderMetrics() {
    if (!this.hasMetricTarget) return
    
    const latestSession = this.getLatestSession()
    if (!latestSession) return
    
    const metricsHTML = Object.keys(this.colors).map(metric => {
      const value = this.getMetricValue(latestSession, metric)
      const trend = this.trends[metric] || { direction: 'stable', change: 0 }
      
      return `
        <div class="metric-card p-4 bg-white rounded-lg border border-gray-200">
          <div class="text-2xl font-bold text-gray-900 mb-1">
            ${value !== null ? this.formatMetricValue(value, metric) : 'N/A'}
          </div>
          <div class="text-sm text-gray-600 mb-2">${this.formatMetricName(metric)}</div>
          <div class="flex items-center text-xs">
            <span class="${this.getTrendColorClass(trend.direction)}">
              ${this.getTrendIcon(trend.direction)} ${Math.abs(trend.change).toFixed(1)}%
            </span>
            <span class="text-gray-400 ml-2">vs ${this.timeframeValue}</span>
          </div>
        </div>
      `
    }).join('')
    
    this.metricTarget.innerHTML = metricsHTML
  }

  formatMetricValue(value, metric) {
    switch (metric) {
      case 'clarity_score':
      case 'pace_consistency':
      case 'volume_consistency':
      case 'engagement_score':
      case 'fluency_score':
      case 'overall_score':
        return (value * 100).toFixed(0) + '%'
      case 'wpm':
        return Math.round(value)
      case 'filler_rate':
        return (value * 100).toFixed(1) + '%'
      default:
        return value.toFixed(2)
    }
  }

  getLatestSession() {
    return this.sessionsValue
      .filter(session => session.metrics)
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))[0]
  }

  renderTrends() {
    if (!this.showTrendsValue || !this.hasTrendTarget) return
    
    const trendsHTML = Object.keys(this.trends).map(metric => {
      const trend = this.trends[metric]
      const data = this.chartData[metric]
      
      return `
        <div class="trend-item flex justify-between items-center p-3 border-b border-gray-100">
          <div>
            <span class="font-medium">${this.formatMetricName(metric)}</span>
            <span class="text-sm text-gray-500 ml-2">${trend.confidence} confidence</span>
          </div>
          <div class="text-right">
            <div class="${this.getTrendColorClass(trend.direction)} font-medium">
              ${this.getTrendIcon(trend.direction)} ${Math.abs(trend.change).toFixed(1)}%
            </div>
            <div class="text-xs text-gray-500">${data.filter(d => d.value !== null).length} sessions</div>
          </div>
        </div>
      `
    }).join('')
    
    this.trendTarget.innerHTML = `
      <div class="trends-container bg-white rounded-lg border border-gray-200">
        <div class="p-4 border-b border-gray-200">
          <h3 class="font-semibold text-gray-900">Trends (${this.timeframeValue})</h3>
        </div>
        <div class="trends-list">${trendsHTML}</div>
      </div>
    `
  }

  generateInsights() {
    if (!this.hasInsightsTarget) return
    
    const insights = this.extractInsights()
    const insightsHTML = insights.map(insight => `
      <div class="insight p-4 bg-${insight.type === 'positive' ? 'green' : insight.type === 'negative' ? 'red' : 'blue'}-50 rounded-lg border border-${insight.type === 'positive' ? 'green' : insight.type === 'negative' ? 'red' : 'blue'}-200 mb-3">
        <div class="flex items-start">
          <div class="text-${insight.type === 'positive' ? 'green' : insight.type === 'negative' ? 'red' : 'blue'}-600 mr-3 text-lg">
            ${insight.type === 'positive' ? '💪' : insight.type === 'negative' ? '⚠️' : '💡'}
          </div>
          <div>
            <h4 class="font-medium text-gray-900 mb-1">${insight.title}</h4>
            <p class="text-sm text-gray-700">${insight.description}</p>
          </div>
        </div>
      </div>
    `).join('')
    
    this.insightsTarget.innerHTML = `
      <div class="insights-container">
        <h3 class="font-semibold text-gray-900 mb-4">AI Insights</h3>
        ${insightsHTML}
      </div>
    `
  }

  extractInsights() {
    const insights = []
    
    Object.keys(this.trends).forEach(metric => {
      const trend = this.trends[metric]
      if (trend.confidence === 'high' && Math.abs(trend.change) > 10) {
        insights.push({
          type: trend.direction === 'improving' ? 'positive' : 'negative',
          title: `${this.formatMetricName(metric)} ${trend.direction}`,
          description: `Your ${this.formatMetricName(metric).toLowerCase()} has ${trend.direction === 'improving' ? 'improved' : 'declined'} by ${Math.abs(trend.change).toFixed(1)}% over the past ${this.timeframeValue}.`
        })
      }
    })
    
    const streaks = this.patterns.streaks
    Object.keys(streaks).forEach(metric => {
      const streak = streaks[metric]
      if (streak.current >= 3) {
        insights.push({
          type: streak.type === 'improving' ? 'positive' : 'negative',
          title: `${streak.current}-day ${streak.type} streak`,
          description: `You're on a ${streak.current}-day ${streak.type} streak for ${this.formatMetricName(metric).toLowerCase()}!`
        })
      }
    })
    
    const bestDay = this.findBestPerformanceDay()
    if (bestDay) {
      insights.push({
        type: 'neutral',
        title: 'Peak Performance Day',
        description: `Your best performance typically occurs on ${bestDay.day}s. Consider scheduling important sessions then.`
      })
    }
    
    return insights.slice(0, 5)
  }

  findBestPerformanceDay() {
    const dayPatterns = this.patterns.dayOfWeekPatterns
    if (!dayPatterns || Object.keys(dayPatterns).length === 0) return null
    
    let bestDay = null
    let bestScore = -1
    
    Object.keys(dayPatterns).forEach(dayIndex => {
      const data = dayPatterns[dayIndex]
      const score = this.calculateOverallPerformance([{ metrics: data }])
      if (score > bestScore) {
        bestScore = score
        bestDay = { day: this.getDayName(parseInt(dayIndex)), score }
      }
    })
    
    return bestDay
  }

  getDayName(dayIndex) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
    return days[dayIndex]
  }

  changeTimeframe(event) {
    this.timeframeValue = event.target.value
    this.processData()
    this.renderSparklines()
    this.renderMetrics()
    this.renderTrends()
    this.generateInsights()
  }

  changeMetric(event) {
    this.currentMetric = event.target.value
    this.renderSparklines()
  }

  toggleTrends() {
    this.showTrendsValue = !this.showTrendsValue
    this.renderTrends()
  }

  startAutoRefresh() {
    if (this.refreshTimer) return
    
    this.refreshTimer = setInterval(() => {
      this.refresh()
    }, this.refreshInterval * 1000)
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }

  refresh() {
    this.dispatch('refresh-data', { bubbles: true })
  }

  exportData() {
    const exportData = {
      sessions: this.sessionsValue,
      chartData: this.chartData,
      trends: this.trends,
      patterns: this.patterns,
      timeframe: this.timeframeValue,
      exportDate: new Date().toISOString()
    }
    
    const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    
    const a = document.createElement('a')
    a.href = url
    a.download = `insights-${this.timeframeValue}-${new Date().toISOString().split('T')[0]}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    
    URL.revokeObjectURL(url)
  }
}