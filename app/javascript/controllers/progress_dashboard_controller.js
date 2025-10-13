import { Controller } from "@hotwired/stimulus"
import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Title,
  Tooltip,
  Legend
} from 'chart.js'

// Register Chart.js components
Chart.register(
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Title,
  Tooltip,
  Legend
)

export default class extends Controller {
  static targets = ["fillerChart", "paceChart", "clarityChart", "paceConsistencyChart", "fluencyChart", "engagementChart"]
  static values = { timeRange: { type: String, default: "7" } }

  connect() {
    this.initializeCharts()
  }

  initializeCharts() {
    if (this.hasFillerChartTarget) {
      this.initializeFillerChart()
    }

    if (this.hasPaceChartTarget) {
      this.initializePaceChart()
    }

    if (this.hasClarityChartTarget) {
      this.initializeClarityChart()
    }

    if (this.hasPaceConsistencyChartTarget) {
      this.initializePaceConsistencyChart()
    }

    if (this.hasFluencyChartTarget) {
      this.initializeFluencyChart()
    }

    if (this.hasEngagementChartTarget) {
      this.initializeEngagementChart()
    }
  }

  changeTimeRange(event) {
    const range = event.currentTarget.dataset.range
    this.timeRangeValue = range

    // Update active button styling
    document.querySelectorAll('.time-range-btn').forEach(btn => {
      btn.classList.remove('active')
    })
    event.currentTarget.classList.add('active')

    // Reload the page with the new time range
    const url = new URL(window.location)
    url.searchParams.set('time_range', range)
    window.location.href = url.toString()
  }

  disconnect() {
    // Clean up charts when controller disconnects
    if (this.fillerChart) this.fillerChart.destroy()
    if (this.paceChart) this.paceChart.destroy()
    if (this.clarityChart) this.clarityChart.destroy()
    if (this.paceConsistencyChart) this.paceConsistencyChart.destroy()
    if (this.fluencyChart) this.fluencyChart.destroy()
    if (this.engagementChart) this.engagementChart.destroy()
  }

  initializeFillerChart() {
    const canvas = this.fillerChartTarget
    const labels = JSON.parse(canvas.dataset.labels)
    const values = JSON.parse(canvas.dataset.values)
    const goal = parseFloat(canvas.dataset.goal)

    this.fillerChart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Filler %',
            data: values,
            borderColor: '#FF8C42',
            backgroundColor: '#FF8C42',
            borderWidth: 2.5,
            pointRadius: 2,
            pointHoverRadius: 4,
            tension: 0.15,
            fill: false
          },
          {
            label: 'Goal',
            data: new Array(labels.length).fill(goal),
            borderColor: '#94a3b8',
            borderWidth: 2,
            borderDash: [5, 5],
            pointRadius: 0,
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: {
            top: 10,
            right: 10,
            bottom: 5,
            left: 5
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.dataset.label + ': ' + context.parsed.y.toFixed(1) + '%'
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            max: Math.ceil(Math.max(...values, goal) * 1.2),
            grid: {
              color: '#f1f5f9',
              drawBorder: false
            },
            ticks: {
              precision: 1,
              color: '#64748b',
              font: {
                size: 11
              },
              callback: function(value) {
                return value.toFixed(1) + '%'
              }
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: '#64748b',
              font: {
                size: 11
              }
            }
          }
        }
      }
    })
  }

  initializePaceChart() {
    const canvas = this.paceChartTarget
    const labels = JSON.parse(canvas.dataset.labels)
    const values = JSON.parse(canvas.dataset.values)
    const goal = parseFloat(canvas.dataset.goal)

    this.paceChart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Pace (WPM)',
            data: values,
            borderColor: '#FF8C42',
            backgroundColor: '#FF8C42',
            borderWidth: 2.5,
            pointRadius: 2,
            pointHoverRadius: 4,
            tension: 0.15,
            fill: false
          },
          {
            label: 'Goal',
            data: new Array(labels.length).fill(goal),
            borderColor: '#94a3b8',
            borderWidth: 2,
            borderDash: [5, 5],
            pointRadius: 0,
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: {
            top: 10,
            right: 10,
            bottom: 5,
            left: 5
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.dataset.label + ': ' + Math.round(context.parsed.y) + ' WPM'
              }
            }
          }
        },
        scales: {
          y: {
            min: 100,
            max: 200,
            grid: {
              color: '#f1f5f9',
              drawBorder: false
            },
            ticks: {
              stepSize: 20,
              color: '#64748b',
              font: {
                size: 11
              },
              callback: function(value) {
                return Math.round(value) + ' WPM'
              }
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: '#64748b',
              font: {
                size: 11
              }
            }
          }
        }
      }
    })
  }

  initializeClarityChart() {
    const canvas = this.clarityChartTarget
    const labels = JSON.parse(canvas.dataset.labels)
    const values = JSON.parse(canvas.dataset.values)
    const goal = parseFloat(canvas.dataset.goal)

    this.clarityChart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Clarity',
            data: values,
            borderColor: '#FF8C42',
            backgroundColor: '#FF8C42',
            borderWidth: 2.5,
            pointRadius: 2,
            pointHoverRadius: 4,
            tension: 0.15,
            fill: false
          },
          {
            label: 'Goal',
            data: new Array(labels.length).fill(goal),
            borderColor: '#94a3b8',
            borderWidth: 2,
            borderDash: [5, 5],
            pointRadius: 0,
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: {
            top: 10,
            right: 10,
            bottom: 5,
            left: 5
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.dataset.label + ': ' + Math.round(context.parsed.y)
              }
            }
          }
        },
        scales: {
          y: {
            min: 0,
            max: 100,
            grid: {
              color: '#f1f5f9',
              drawBorder: false
            },
            ticks: {
              stepSize: 20,
              color: '#64748b',
              font: {
                size: 11
              },
              callback: function(value) {
                return Math.round(value)
              }
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: '#64748b',
              font: {
                size: 11
              }
            }
          }
        }
      }
    })
  }

  initializePaceConsistencyChart() {
    const canvas = this.paceConsistencyChartTarget
    const labels = JSON.parse(canvas.dataset.labels)
    const values = JSON.parse(canvas.dataset.values)
    const goal = parseFloat(canvas.dataset.goal)

    this.paceConsistencyChart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Pace Consistency',
            data: values,
            borderColor: '#FF8C42',
            backgroundColor: '#FF8C42',
            borderWidth: 2.5,
            pointRadius: 2,
            pointHoverRadius: 4,
            tension: 0.15,
            fill: false
          },
          {
            label: 'Goal',
            data: new Array(labels.length).fill(goal),
            borderColor: '#94a3b8',
            borderWidth: 2,
            borderDash: [5, 5],
            pointRadius: 0,
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: {
            top: 10,
            right: 10,
            bottom: 5,
            left: 5
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.dataset.label + ': ' + Math.round(context.parsed.y) + '%'
              }
            }
          }
        },
        scales: {
          y: {
            min: 0,
            max: 100,
            grid: {
              color: '#f1f5f9',
              drawBorder: false
            },
            ticks: {
              stepSize: 20,
              color: '#64748b',
              font: {
                size: 11
              },
              callback: function(value) {
                return Math.round(value) + '%'
              }
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: '#64748b',
              font: {
                size: 11
              }
            }
          }
        }
      }
    })
  }

  initializeFluencyChart() {
    const canvas = this.fluencyChartTarget
    const labels = JSON.parse(canvas.dataset.labels)
    const values = JSON.parse(canvas.dataset.values)
    const goal = parseFloat(canvas.dataset.goal)

    this.fluencyChart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Fluency',
            data: values,
            borderColor: '#FF8C42',
            backgroundColor: '#FF8C42',
            borderWidth: 2.5,
            pointRadius: 2,
            pointHoverRadius: 4,
            tension: 0.15,
            fill: false
          },
          {
            label: 'Goal',
            data: new Array(labels.length).fill(goal),
            borderColor: '#94a3b8',
            borderWidth: 2,
            borderDash: [5, 5],
            pointRadius: 0,
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: {
            top: 10,
            right: 10,
            bottom: 5,
            left: 5
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.dataset.label + ': ' + Math.round(context.parsed.y) + '%'
              }
            }
          }
        },
        scales: {
          y: {
            min: 0,
            max: 100,
            grid: {
              color: '#f1f5f9',
              drawBorder: false
            },
            ticks: {
              stepSize: 20,
              color: '#64748b',
              font: {
                size: 11
              },
              callback: function(value) {
                return Math.round(value) + '%'
              }
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: '#64748b',
              font: {
                size: 11
              }
            }
          }
        }
      }
    })
  }

  initializeEngagementChart() {
    const canvas = this.engagementChartTarget
    const labels = JSON.parse(canvas.dataset.labels)
    const values = JSON.parse(canvas.dataset.values)
    const goal = parseFloat(canvas.dataset.goal)

    this.engagementChart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Engagement',
            data: values,
            borderColor: '#FF8C42',
            backgroundColor: '#FF8C42',
            borderWidth: 2.5,
            pointRadius: 2,
            pointHoverRadius: 4,
            tension: 0.15,
            fill: false
          },
          {
            label: 'Goal',
            data: new Array(labels.length).fill(goal),
            borderColor: '#94a3b8',
            borderWidth: 2,
            borderDash: [5, 5],
            pointRadius: 0,
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: {
            top: 10,
            right: 10,
            bottom: 5,
            left: 5
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.dataset.label + ': ' + Math.round(context.parsed.y) + '%'
              }
            }
          }
        },
        scales: {
          y: {
            min: 0,
            max: 100,
            grid: {
              color: '#f1f5f9',
              drawBorder: false
            },
            ticks: {
              stepSize: 20,
              color: '#64748b',
              font: {
                size: 11
              },
              callback: function(value) {
                return Math.round(value) + '%'
              }
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: '#64748b',
              font: {
                size: 11
              }
            }
          }
        }
      }
    })
  }
}
