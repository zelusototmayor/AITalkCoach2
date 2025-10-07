import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static targets = ["fillerChart", "paceChart", "clarityChart"]

  connect() {
    console.log("Progress dashboard controller connected")

    if (this.hasFillerChartTarget) {
      this.initializeFillerChart()
    }

    if (this.hasPaceChartTarget) {
      this.initializePaceChart()
    }

    if (this.hasClarityChartTarget) {
      this.initializeClarityChart()
    }
  }

  disconnect() {
    // Clean up charts when controller disconnects
    if (this.fillerChart) this.fillerChart.destroy()
    if (this.paceChart) this.paceChart.destroy()
    if (this.clarityChart) this.clarityChart.destroy()
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
            borderColor: '#6366f1',
            backgroundColor: '#6366f1',
            borderWidth: 2,
            pointRadius: 5,
            pointHoverRadius: 7,
            tension: 0.4,
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
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.dataset.label + ': ' + context.parsed.y + '%'
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            max: Math.max(...values, goal) * 1.2,
            ticks: {
              callback: function(value) {
                return value + '%'
              }
            }
          },
          x: {
            grid: {
              display: false
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
            borderColor: '#6366f1',
            backgroundColor: '#6366f1',
            borderWidth: 2,
            pointRadius: 5,
            pointHoverRadius: 7,
            tension: 0.4,
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
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.dataset.label + ': ' + context.parsed.y + ' WPM'
              }
            }
          }
        },
        scales: {
          y: {
            min: 100,
            max: 200,
            ticks: {
              callback: function(value) {
                return value + ' WPM'
              }
            }
          },
          x: {
            grid: {
              display: false
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
            borderColor: '#6366f1',
            backgroundColor: '#6366f1',
            borderWidth: 2,
            pointRadius: 5,
            pointHoverRadius: 7,
            tension: 0.4,
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
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return context.dataset.label + ': ' + context.parsed.y
              }
            }
          }
        },
        scales: {
          y: {
            min: 0,
            max: 100,
            ticks: {
              callback: function(value) {
                return value
              }
            }
          },
          x: {
            grid: {
              display: false
            }
          }
        }
      }
    })
  }
}
