# M-Series Component Documentation

This document describes the UI components, 3D visualizations, and service architecture for the M-series features.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [M1: Analytics Dashboard Components](#m1-analytics-dashboard-components)
- [M2: Report Export Components](#m2-report-export-components)
- [M3: API Usage Analytics Components](#m3-api-usage-analytics-components)
- [3D Visualization Builders](#3d-visualization-builders)
- [Configuration & Customization](#configuration--customization)
- [Testing](#testing)

---

## Architecture Overview

Each M-series feature follows a consistent 4-layer architecture:

```
┌─────────────────────────────────────┐
│          AppState (Toggle)          │  ← Global state with visibility toggles
├─────────────────────────────────────┤
│        Overlay View (SwiftUI)       │  ← 2D floating panel overlay
├─────────────────────────────────────┤
│      Service Manager (ObservableObject)  │  ← Business logic & data management
├─────────────────────────────────────┤
│    3D Visualization Builder (SceneKit)   │  ← 3D scene node construction
└─────────────────────────────────────┘
```

### File Organization

```
AgentCommand/
├── Models/
│   ├── AnalyticsDashboardModels.swift     # M1 data models
│   ├── ReportExportModels.swift           # M2 data models
│   └── APIUsageAnalyticsModels.swift      # M3 data models
├── Services/
│   ├── AnalyticsDashboardManager.swift           # M1 simplified manager
│   ├── AdvancedAnalyticsDashboardManager.swift   # M1 advanced manager
│   ├── ReportExportManager.swift                 # M2 export manager
│   ├── ReportGenerationManager.swift             # M2 generation manager
│   └── APIUsageAnalyticsManager.swift            # M3 usage manager
├── Views/Overlays/
│   ├── AnalyticsDashboardOverlay.swift    # M1 overlay panel
│   ├── ReportExportOverlay.swift          # M2 overlay panel
│   └── APIUsageAnalyticsOverlay.swift     # M3 overlay panel
└── Scene3D/Effects/
    ├── AnalyticsDashboardVisualizationBuilder.swift  # M1 3D scene
    ├── ReportExportVisualizationBuilder.swift         # M2 3D scene
    └── APIUsageVisualizationBuilder.swift             # M3 3D scene
```

---

## M1: Analytics Dashboard Components

### AnalyticsDashboardOverlay

**File:** `Views/Overlays/AnalyticsDashboardOverlay.swift` (107 lines)

A right-aligned floating panel that provides a quick summary of analytics data.

**Display Elements:**
- Report count badge
- Forecast count badge
- Total potential savings (USD)
- Top 3 unapplied optimization tips with estimated savings

**Usage:**
```swift
AnalyticsDashboardOverlay()
    .environmentObject(appState)
```

The overlay reads from `appState.analyticsDashboardManager` and is shown/hidden via `appState.isAnalyticsDashboardViewVisible`.

### AnalyticsDashboardManager (Simplified)

**File:** `Services/AnalyticsDashboardManager.swift` (449 lines)

Provides the standard analytics feature set:

| Feature | Description |
|---------|-------------|
| Report Builder | Create custom reports with configurable widgets |
| Widget Types | 6 types: line chart, bar chart, pie chart, metric card, table, heatmap |
| Data Sources | 6 sources: token usage, cost over time, task completion, error rate, response latency, model distribution |
| Trend Forecasting | Generate forecasts for 5 metric types with configurable horizon |
| Cost Optimization | Auto-generated tips across 5 categories with savings estimates |
| Benchmarking | Compare performance across models and agents with 5 metric types |

### AdvancedAnalyticsDashboardManager

**File:** `Services/AdvancedAnalyticsDashboardManager.swift` (438 lines)

Extends the simplified manager with:

- **Simple Moving Average (SMA)** algorithm for trend forecasting
- **Standard deviation** calculation for confidence intervals
- **Automated optimization analysis** scanning for model selection, token reduction, caching, and batch processing opportunities
- **Time-series aggregation** for widget data rendering
- **Widget reordering** within reports

### AnalyticsDashboardVisualizationBuilder

**File:** `Scene3D/Effects/AnalyticsDashboardVisualizationBuilder.swift` (210 lines)

Builds a 3D SceneKit node hierarchy:

```
analyticsRoot
├── analyticsHub (central pulsating sphere + rotating ring)
├── reportWidgets (arc-arranged widget panels)
│   └── widget_N (colored by widget count, sized by widget size)
├── forecastTrends (trend lines with arrows)
│   └── forecast_N (arrow + confidence indicator sphere)
└── optimizationRing (cylindrical columns)
    └── tip_N (height reflects savings, green=applied / orange=unapplied)
```

**Animations:**
- Hub sphere: continuous pulsation (scale 1.0 → 1.15)
- Hub ring: continuous Y-axis rotation (10s period)
- Forecast arrows: positioned along forecast trajectory
- Optimization tips: height-scaled cylinders with color coding

---

## M2: Report Export Components

### ReportExportOverlay

**File:** `Views/Overlays/ReportExportOverlay.swift` (113 lines)

Right-aligned floating panel showing:

- Template count
- Active schedule count
- Completed export count
- Top 3 export jobs with format, status, and progress bar

**Usage:**
```swift
ReportExportOverlay()
    .environmentObject(appState)
```

### ReportExportManager

**File:** `Services/ReportExportManager.swift` (348 lines)

Core export workflow:

| Feature | Description |
|---------|-------------|
| Templates | Create reusable report templates with 6 section types |
| Scheduling | Automated export with 4 frequency options |
| Export Jobs | Async export execution with progress tracking |
| Report Data | Generates structured report data with summary, task metrics, error metrics |
| Schedule Monitor | Timer checks every 60s for pending scheduled exports |

**Section Types:**
1. Executive Summary
2. Token Usage
3. Cost Analysis
4. Task Metrics
5. Error Analysis
6. Performance Trends

### ReportGenerationManager

**File:** `Services/ReportGenerationManager.swift` (384 lines)

Advanced generation with format converters:

| Format | Output |
|--------|--------|
| JSON | Structured JSON with report metadata, summary, task metrics, errors |
| CSV | Tabular format with headers for period, tokens, cost, tasks, errors |
| Markdown | Formatted document with headers, tables, and sections |
| PDF | Placeholder (marked for future native PDF rendering) |

**Persistence:** Templates are saved to/loaded from `UserDefaults` with the key `"reportTemplates"`.

### ReportExportVisualizationBuilder

**File:** `Scene3D/Effects/ReportExportVisualizationBuilder.swift` (171 lines)

3D node hierarchy:

```
reportExportRoot
├── documentHub (central box + upward arrow)
├── exportJobs (circular arrangement)
│   └── job_N (geometry varies by format: box=JSON, cylinder=CSV, pyramid=MD, sphere=PDF)
└── scheduleRing (outer ring of schedule nodes)
    └── schedule_N (active=green with rotating clock, inactive=gray)
```

**Format-Specific Geometry:**
| Format | 3D Shape | Color |
|--------|----------|-------|
| JSON | Box | Blue |
| CSV | Cylinder | Green |
| Markdown | Pyramid | Purple |
| PDF | Sphere | Red |

**Animations:**
- In-progress jobs: pulsation effect (scale 1.0 → 1.3)
- Active schedules: rotating clock icon (5s Y-axis rotation)

---

## M3: API Usage Analytics Components

### APIUsageAnalyticsOverlay

**File:** `Views/Overlays/APIUsageAnalyticsOverlay.swift` (135 lines)

Right-aligned floating panel showing:

- Total API call count
- Total cost (USD)
- Error rate (percentage)
- Budget status (spend percentage, alert level with color coding)
- Top 3 model usage statistics with cost breakdown

**Budget Alert Colors:**
| Level | Color |
|-------|-------|
| Normal | Green |
| Warning | Orange |
| Critical | Red |

**Usage:**
```swift
APIUsageAnalyticsOverlay()
    .environmentObject(appState)
```

### APIUsageAnalyticsManager

**File:** `Services/APIUsageAnalyticsManager.swift` (454 lines)

Comprehensive API tracking:

| Feature | Description |
|---------|-------------|
| Call Recording | Track individual API calls with full metrics |
| Real-time Monitoring | Timer updates every 30 seconds |
| Cost Breakdown | Group costs by model with period tracking |
| Budget Alerts | Configurable budget with 3-level threshold alerts |
| Usage Forecasting | SMA-based trend detection with month-end projections |
| Model Statistics | Per-model aggregation of calls, tokens, cost, latency, errors |

**Monitoring Cycle (every 30 seconds):**
1. `updateSummary()` — Recalculate aggregated metrics
2. `updateModelStats()` — Refresh per-model statistics
3. `generateForecast()` — Update usage projections

**Budget Thresholds:**
| Spend % | Alert Level |
|---------|-------------|
| < 70% | Normal |
| 70% – 90% | Warning |
| > 90% | Critical |

**Sample Data:** `loadSampleData()` generates 25 API call records across 3 models (Claude Opus, Sonnet, Haiku) with realistic token counts, latencies, and costs.

### APIUsageVisualizationBuilder

**File:** `Scene3D/Effects/APIUsageVisualizationBuilder.swift` (182 lines)

3D node hierarchy:

```
apiUsageRoot
├── usageGauge (central ring representing budget + sphere sized by spend %)
├── modelColumns (cylindrical columns per model)
│   └── model_N (height=cost, colored by model; red ring if high error rate)
└── callTrails (particle trail of recent API calls)
    └── call_N (green sphere=success, red sphere=failure)
```

**Visual Encodings:**
| Element | Encoding |
|---------|----------|
| Budget ring radius | Budget limit |
| Central sphere size | Current spend percentage |
| Column height | Model cost |
| Column color | Unique per model |
| Error ring | Shown when model error rate > 10% |
| Call particles | Green = success, Red = failure |

---

## Configuration & Customization

### Enabling M-Series Features

All M-series features are enabled by default. Toggle visibility programmatically:

```swift
// Toggle overlay visibility
appState.toggleAnalyticsDashboardStatus()  // M1
appState.toggleReportExportStatus()         // M2
appState.toggleAPIUsageAnalyticsStatus()    // M3
```

### Loading Sample Data

Each manager provides a `loadSampleData()` method for development and testing:

```swift
appState.analyticsDashboardManager.loadSampleData()
appState.reportExportManager.loadSampleData()
appState.apiUsageAnalyticsManager.loadSampleData()
```

### Memory Management

All managers enforce configurable limits to prevent unbounded memory growth:

| Manager | Resource | Limit |
|---------|----------|-------|
| AnalyticsDashboard | Reports | 50 |
| AnalyticsDashboard | Forecasts | 20 |
| AnalyticsDashboard | Tips | 100 |
| AnalyticsDashboard | Benchmarks | 30 |
| ReportExport | Export Jobs | 50 |
| ReportExport | Generated Reports | 20 |
| ReportGeneration | Templates | 30 |
| ReportGeneration | Schedules | 20 |
| ReportGeneration | Export Jobs | 50 |
| APIUsageAnalytics | Call Metrics | 500 |
| APIUsageAnalytics | Cost Breakdowns | 10 |

When limits are exceeded, oldest entries are automatically removed (FIFO).

### Timer-Based Background Tasks

| Manager | Interval | Actions |
|---------|----------|---------|
| ReportExportManager | 60s | Check schedules, trigger pending exports |
| APIUsageAnalyticsManager | 30s | Update summary, model stats, forecast |

---

## Testing

### Test Files

| File | Tests | Coverage |
|------|-------|----------|
| `Tests/AnalyticsDashboardModelsTests.swift` | M1 model encoding/decoding, report CRUD, widget management | Models & Manager |
| `Tests/ReportExportModelsTests.swift` | M2 template CRUD, schedule management, export job lifecycle | Models & Manager |
| `Tests/APIUsageAnalyticsModelsTests.swift` | M3 call recording, cost breakdown, budget alerts, forecasting | Models & Manager |
| `Tests/MSeriesIntegrationTests.swift` | Cross-feature integration, AppState toggles, data flow | Integration |

### Running Tests

```bash
cd AgentCommand
swift test
```

Or run specific test files:

```bash
swift test --filter AnalyticsDashboardModelsTests
swift test --filter ReportExportModelsTests
swift test --filter APIUsageAnalyticsModelsTests
swift test --filter MSeriesIntegrationTests
```
