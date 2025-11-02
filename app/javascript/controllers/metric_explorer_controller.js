import { Controller } from "@hotwired/stimulus"
import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Tooltip,
  Legend,
  Filler
} from 'chart.js'

// Register Chart.js components
Chart.register(
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Tooltip,
  Legend,
  Filler
)

export default class extends Controller {
  static targets = [
    "metricCard",
    "metricSelect",
    "timeRangeBtn",
    "mainChart",
    "chartTitle",
    "currentValue",
    "bestValue",
    "trendValue"
  ]

  static values = {
    currentMetric: { type: String, default: "overall_score" },
    currentTimeRange: { type: String, default: "7" }
  }

  connect() {
    console.log("✅ Metric Explorer controller connected")
    console.log("Canvas element:", this.mainChartTarget)
    console.log("Number of metric cards:", this.metricCardTargets.length)

    // Initialize chart data from canvas element
    this.chartData = {
      labels: JSON.parse(this.mainChartTarget.dataset.labels || '[]'),
      overall_score: JSON.parse(this.mainChartTarget.dataset.overallScoreValues || '[]'),
      filler: JSON.parse(this.mainChartTarget.dataset.fillerValues || '[]'),
      pace: JSON.parse(this.mainChartTarget.dataset.paceValues || '[]'),
      clarity: JSON.parse(this.mainChartTarget.dataset.clarityValues || '[]'),
      pace_consistency: JSON.parse(this.mainChartTarget.dataset.paceConsistencyValues || '[]'),
      fluency: JSON.parse(this.mainChartTarget.dataset.fluencyValues || '[]'),
      engagement: JSON.parse(this.mainChartTarget.dataset.engagementValues || '[]')
    }

    console.log("Chart data loaded:", {
      labels: this.chartData.labels.length,
      overall_score: this.chartData.overall_score.length,
      filler: this.chartData.filler.length
    })

    // Initialize Chart.js
    this.initializeChart()

    // Update chart with default metric
    this.updateChart()

    console.log("✅ Initial chart rendered with metric:", this.currentMetricValue)
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  initializeChart() {
    const ctx = this.mainChartTarget.getContext('2d')

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: this.chartData.labels,
        datasets: [{
          label: 'Your Progress',
          data: [],
          borderColor: '#FF8C42',
          backgroundColor: 'rgba(255, 140, 66, 0.1)',
          borderWidth: 3,
          tension: 0.4,
          pointRadius: 5,
          pointHoverRadius: 8,
          pointBackgroundColor: '#FF8C42',
          pointBorderColor: '#fff',
          pointBorderWidth: 2,
          fill: true
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 2.5,
        interaction: {
          mode: 'index',
          intersect: false,
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            enabled: true,
            backgroundColor: '#1e293b',
            titleColor: '#fff',
            bodyColor: '#fff',
            padding: 12,
            cornerRadius: 8,
            displayColors: false,
            callbacks: {
              label: (context) => {
                let value = context.parsed.y
                const metric = this.currentMetricValue

                // Format based on metric type
                if (metric === 'pace') {
                  return `${value} WPM`
                } else if (metric === 'filler_rate') {
                  return `${value}%`
                } else {
                  return `${value}%`
                }
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: false,
            grid: {
              color: '#e2e8f0',
              drawBorder: false
            },
            ticks: {
              color: '#64748b',
              callback: (value) => {
                const metric = this.currentMetricValue
                if (metric === 'pace') {
                  return `${value}`
                } else {
                  return `${value}%`
                }
              }
            }
          },
          x: {
            grid: {
              display: false,
              drawBorder: false
            },
            ticks: {
              color: '#64748b',
              maxRotation: 45,
              minRotation: 0
            }
          }
        }
      }
    })
  }

  selectMetric(event) {
    const metric = event.currentTarget.dataset.metric
    console.log("🎯 Card clicked! Metric:", metric)
    console.log("Event target:", event.currentTarget)

    this.currentMetricValue = metric

    // Update active state on metric cards
    this.metricCardTargets.forEach(card => {
      card.classList.remove('active')
      if (card.dataset.metric === metric) {
        card.classList.add('active')
        console.log("✅ Activated card:", metric)
      }
    })

    // Update chart
    console.log("📊 Updating chart to show:", metric)
    this.updateChart()
  }

  selectMetricFromDropdown(event) {
    const metric = event.target.value
    this.currentMetricValue = metric

    // Update active state on metric cards
    this.metricCardTargets.forEach(card => {
      card.classList.remove('active')
      if (card.dataset.metric === metric) {
        card.classList.add('active')
      }
    })

    // Update chart
    this.updateChart()
  }

  changeTimeRange(event) {
    const range = event.currentTarget.dataset.range
    this.currentTimeRangeValue = range

    // Update active state on time range buttons
    this.timeRangeBtnTargets.forEach(btn => {
      btn.classList.remove('active')
    })
    event.currentTarget.classList.add('active')

    // In a real implementation, you'd fetch new data here
    // For now, we'll just re-render with existing data
    // TODO: Fetch filtered data from server
    console.log(`Time range changed to: ${range}`)

    // Update chart (for now with same data, but could filter client-side)
    this.updateChart()
  }

  updateChart() {
    if (!this.chart) {
      console.error("❌ Chart not initialized!")
      return
    }

    const metric = this.currentMetricValue
    const data = this.getDataForMetric(metric)

    console.log("📈 Updating chart:", {
      metric: metric,
      dataPoints: data.length,
      data: data
    })

    // Update chart data
    this.chart.data.datasets[0].data = data

    // Update chart config based on metric
    const config = this.getMetricConfig(metric)
    this.chart.data.datasets[0].borderColor = config.color
    this.chart.data.datasets[0].backgroundColor = config.backgroundColor
    this.chart.data.datasets[0].pointBackgroundColor = config.color

    // Update title
    if (this.hasChartTitleTarget) {
      this.chartTitleTarget.textContent = config.title
      console.log("📝 Updated title to:", config.title)
    }

    // Update stats
    this.updateStats(data, metric)

    // Re-render chart
    this.chart.update()
    console.log("✅ Chart updated successfully")
  }

  getDataForMetric(metric) {
    switch (metric) {
      case 'overall_score':
        return this.chartData.overall_score
      case 'filler_rate':
        return this.chartData.filler
      case 'pace':
        return this.chartData.pace
      case 'clarity':
        return this.chartData.clarity
      case 'pace_consistency':
        return this.chartData.pace_consistency
      case 'fluency':
        return this.chartData.fluency
      case 'engagement':
        return this.chartData.engagement
      default:
        return []
    }
  }

  getMetricConfig(metric) {
    const configs = {
      overall_score: {
        title: 'Overall Score',
        color: '#FF8C42',
        backgroundColor: 'rgba(255, 140, 66, 0.1)',
        goal: 80,
        inverse: false
      },
      filler_rate: {
        title: 'Filler Word Progress',
        color: '#ef4444',
        backgroundColor: 'rgba(239, 68, 68, 0.1)',
        goal: 3.0,
        inverse: true // Lower is better
      },
      pace: {
        title: 'Speaking Pace (WPM)',
        color: '#3b82f6',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        goal: 150,
        inverse: false
      },
      clarity: {
        title: 'Speech Clarity',
        color: '#10b981',
        backgroundColor: 'rgba(16, 185, 129, 0.1)',
        goal: 90,
        inverse: false
      },
      pace_consistency: {
        title: 'Pace Consistency',
        color: '#FF8C42',
        backgroundColor: 'rgba(255, 140, 66, 0.1)',
        goal: 80,
        inverse: false
      },
      fluency: {
        title: 'Fluency Score',
        color: '#FF8C42',
        backgroundColor: 'rgba(255, 140, 66, 0.1)',
        goal: 85,
        inverse: false
      },
      engagement: {
        title: 'Engagement Level',
        color: '#FF8C42',
        backgroundColor: 'rgba(255, 140, 66, 0.1)',
        goal: 75,
        inverse: false
      }
    }

    return configs[metric] || configs.overall_score
  }

  updateStats(data, metric) {
    if (data.length === 0) {
      if (this.hasCurrentValueTarget) this.currentValueTarget.textContent = '--'
      if (this.hasBestValueTarget) this.bestValueTarget.textContent = '--'
      if (this.hasTrendValueTarget) this.trendValueTarget.textContent = '--'
      return
    }

    const config = this.getMetricConfig(metric)
    const isWPM = metric === 'pace'
    const unit = isWPM ? ' WPM' : '%'

    // Current value (last data point)
    const current = data[data.length - 1]
    if (this.hasCurrentValueTarget) {
      this.currentValueTarget.textContent = `${current}${unit}`
    }

    // Best value
    const best = config.inverse ? Math.min(...data) : Math.max(...data)
    if (this.hasBestValueTarget) {
      this.bestValueTarget.textContent = `${best}${unit}`
    }

    // Trend (compare last 3 to previous 3)
    if (this.hasTrendValueTarget && data.length >= 6) {
      const recentAvg = this.average(data.slice(-3))
      const previousAvg = this.average(data.slice(-6, -3))
      const diff = recentAvg - previousAvg

      const isImproving = config.inverse ? diff < 0 : diff > 0
      const arrow = isImproving ? '↗' : '↘'
      const color = isImproving ? '#10b981' : '#ef4444'

      this.trendValueTarget.innerHTML = `<span style="color: ${color}">${arrow} ${isImproving ? 'Improving' : 'Declining'}</span>`
    } else if (this.hasTrendValueTarget) {
      this.trendValueTarget.textContent = 'Need more data'
    }
  }

  average(arr) {
    return arr.reduce((a, b) => a + b, 0) / arr.length
  }
}
