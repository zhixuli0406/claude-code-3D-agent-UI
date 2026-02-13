# M-Series Configuration Reference

Complete configuration reference for the M-series Data & Analytics features.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
  - [4-Layer Architecture](#4-layer-architecture)
  - [Feature Matrix](#feature-matrix)
- [AppState Configuration](#appstate-configuration)
  - [Visibility Properties](#visibility-properties)
  - [Toggle Methods](#toggle-methods)
  - [Manager Instances](#manager-instances)
- [Memory Limits](#memory-limits)
  - [M1: AnalyticsDashboardManager](#m1-analyticsdashboardmanager)
  - [M1: AdvancedAnalyticsDashboardManager](#m1-advancedanalyticsdashboardmanager)
  - [M2: ReportExportManager](#m2-reportexportmanager)
  - [M2: ReportGenerationManager](#m2-reportgenerationmanager)
  - [M3: APIUsageAnalyticsManager](#m3-apiusageanalyticsmanager)
  - [M4: SessionHistoryAnalyticsManager](#m4-sessionhistoryanalyticsmanager)
  - [M5: TeamPerformanceManager](#m5-teamperformancemanager)
- [Timer-Based Background Tasks](#timer-based-background-tasks)
  - [Starting/Stopping Timers](#startingstopping-timers)
- [Persistence Configuration](#persistence-configuration)
  - [ReportGenerationManager (M2)](#reportgenerationmanager-m2)
  - [Other Managers](#other-managers)
- [Theme Colors](#theme-colors)
  - [Primary Feature Colors](#primary-feature-colors)
  - [Status Colors (Shared)](#status-colors-shared)
  - [Leaderboard Rank Colors](#leaderboard-rank-colors)
  - [M3 Model Colors (3D Visualization)](#m3-model-colors-3d-visualization)
  - [M4 Trend Direction Colors](#m4-trend-direction-colors)
  - [M5 Agent Specialization Colors](#m5-agent-specialization-colors)
- [3D Visualization Configuration](#3d-visualization-configuration)
  - [Rotation Speeds](#rotation-speeds)
  - [Node Naming Convention](#node-naming-convention)
  - [Display Limits (3D)](#display-limits-3d)
- [Localization Keys](#localization-keys)
- [File Reference](#file-reference)
  - [Models](#models)
  - [Services](#services)
  - [Views](#views)
  - [Charts (Shared)](#charts-shared)
  - [3D Visualization](#3d-visualization)
  - [Tests](#tests)

---

## Architecture Overview

### 4-Layer Architecture

Each M-series feature follows a consistent pattern:

```
┌─────────────────────────────────────┐
│          AppState (Toggle)          │  ← Global visibility state
├─────────────────────────────────────┤
│     View Layer (SwiftUI)            │  ← Overlay + Full View + Chart Panel
├─────────────────────────────────────┤
│   Service Manager (ObservableObject)│  ← Business logic & data
├─────────────────────────────────────┤
│  3D Visualization (SceneKit)        │  ← 3D scene node construction
└─────────────────────────────────────┘
```

### Feature Matrix

| Feature | ID | Manager Class | Theme Color | Overlay | Full View | Chart Panel | 3D Builder |
|---------|-----|---------------|-------------|---------|-----------|-------------|------------|
| Analytics Dashboard | M1 | AnalyticsDashboardManager | #00BCD4 (Cyan) | Yes | Yes (4 tabs) | No | Yes |
| Report Export | M2 | ReportExportManager | #E91E63 (Pink) | Yes | Yes (3 tabs) | No | Yes |
| API Usage Analytics | M3 | APIUsageAnalyticsManager | #FF9800 (Orange) | Yes | Yes (4 tabs) | No | Yes |
| Session History | M4 | SessionHistoryAnalyticsManager | #9C27B0 (Purple) | Yes | Yes (4 tabs) | Yes | Yes |
| Team Performance | M5 | TeamPerformanceManager | #FF5722 (Deep Orange) | Yes | Yes (4 tabs) | Yes | Yes |

---

## AppState Configuration

### Visibility Properties

Each feature has two visibility flags:

| Feature | Status Overlay | Full View |
|---------|---------------|-----------|
| M1 | `isAnalyticsDashboardStatusVisible` | `isAnalyticsDashboardViewVisible` |
| M2 | `isReportExportStatusVisible` | `isReportExportViewVisible` |
| M3 | `isAPIUsageAnalyticsStatusVisible` | `isAPIUsageAnalyticsViewVisible` |
| M4 | `isSessionHistoryAnalyticsStatusVisible` | `isSessionHistoryAnalyticsViewVisible` |
| M5 | `isTeamPerformanceStatusVisible` | `isTeamPerformanceViewVisible` |

### Toggle Methods

```swift
func toggleAnalyticsDashboardStatus()        // M1
func toggleReportExportStatus()              // M2
func toggleAPIUsageAnalyticsStatus()         // M3
func toggleSessionHistoryAnalyticsStatus()   // M4
func toggleTeamPerformanceStatus()           // M5
```

### Manager Instances

All managers are instantiated as properties of `AppState`:

```swift
let analyticsDashboardManager = AnalyticsDashboardManager()
let reportExportManager = ReportExportManager()
let apiUsageAnalyticsManager = APIUsageAnalyticsManager()
let sessionHistoryAnalyticsManager = SessionHistoryAnalyticsManager()
let teamPerformanceManager = TeamPerformanceManager()
```

---

## Memory Limits

All managers enforce maximum collection sizes to prevent unbounded memory growth. Oldest entries are removed (FIFO) when limits are exceeded.

### M1: AnalyticsDashboardManager

| Resource | Max Count | Overflow Policy |
|----------|-----------|-----------------|
| Reports | 50 | Remove oldest |
| Forecasts | 20 | Remove oldest |
| Optimization Tips | 100 | Remove oldest |
| Benchmarks | 30 | Remove oldest |

### M1: AdvancedAnalyticsDashboardManager

Same limits as AnalyticsDashboardManager.

### M2: ReportExportManager

| Resource | Max Count | Overflow Policy |
|----------|-----------|-----------------|
| Export Jobs | 50 | Remove oldest |
| Generated Reports | 20 | Remove oldest |

### M2: ReportGenerationManager

| Resource | Max Count | Overflow Policy |
|----------|-----------|-----------------|
| Templates | 30 | Remove oldest |
| Schedules | 20 | Remove oldest |
| Export Jobs | 50 | Remove oldest |

### M3: APIUsageAnalyticsManager

| Resource | Max Count | Overflow Policy |
|----------|-----------|-----------------|
| Call Metrics | 500 | Remove oldest |
| Cost Breakdowns | 10 | Remove oldest |

### M4: SessionHistoryAnalyticsManager

| Resource | Max Count | Overflow Policy |
|----------|-----------|-----------------|
| Sessions | 100 | Remove oldest |
| Comparisons | 20 | Remove oldest |

### M5: TeamPerformanceManager

| Resource | Max Count | Overflow Policy |
|----------|-----------|-----------------|
| Snapshots | 50 | Remove oldest |
| Radar Data | 20 | Remove oldest |
| Leaderboards | 30 | Remove oldest |

---

## Timer-Based Background Tasks

| Manager | Feature | Interval | Actions |
|---------|---------|----------|---------|
| ReportExportManager | M2 | 60s | Check schedules, trigger pending exports |
| ReportGenerationManager | M2 | 3600s (1h) | Check schedules |
| APIUsageAnalyticsManager | M3 | 30s | Update summary, model stats, forecast |

### Starting/Stopping Timers

```swift
// M2: Schedule monitoring
appState.reportExportManager.startScheduleMonitoring()
appState.reportExportManager.stopScheduleMonitoring()

// M3: API monitoring
appState.apiUsageAnalyticsManager.startMonitoring()
appState.apiUsageAnalyticsManager.stopMonitoring()
```

---

## Persistence Configuration

### ReportGenerationManager (M2)

Templates and schedules are persisted to UserDefaults:

| Key | Type | Content |
|-----|------|---------|
| `"reportTemplates"` | `Data` | JSON-encoded `[ReportTemplate]` |
| `"reportSchedules"` | `Data` | JSON-encoded `[ReportSchedule]` |

```swift
// Save/load explicitly
reportGenerationManager.saveTemplates()
reportGenerationManager.loadTemplates()
```

### Other Managers

M1, M3, M4, M5 managers hold data in memory only. Data is lost on app restart unless explicitly persisted by the host application.

---

## Theme Colors

### Primary Feature Colors

| Feature | Hex | RGB | Usage |
|---------|-----|-----|-------|
| M1: Analytics Dashboard | `#00BCD4` | (0, 188, 212) | Overlay borders, hub sphere, accent elements |
| M2: Report Export | `#E91E63` | (233, 30, 99) | Overlay borders, document hub, accent elements |
| M3: API Usage | `#FF9800` | (255, 152, 0) | Overlay borders, gauge ring, accent elements |
| M4: Session History | `#9C27B0` | (156, 39, 176) | Overlay borders, timeline hub, accent elements |
| M5: Team Performance | `#FF5722` | (255, 87, 34) | Overlay borders, performance hub, accent elements |

### Status Colors (Shared)

| Status | Hex | Usage |
|--------|-----|-------|
| Success / Applied | `#4CAF50` | Green -- successful operations, active states |
| Warning | `#FF9800` | Orange -- budget warnings, medium impact |
| Error / Critical | `#F44336` | Red -- errors, budget critical, low productivity |
| Inactive | `#9E9E9E` | Gray -- disabled, inactive states |
| High Productivity | `#4CAF50` | Green -- productivity > 80% |
| Medium Productivity | `#8BC34A` | Light Green -- productivity 60-80% |
| Low Productivity | `#FF9800` | Orange -- productivity 40-60% |
| Very Low Productivity | `#F44336` | Red -- productivity < 40% |

### Leaderboard Rank Colors

| Rank | Hex | Metal |
|------|-----|-------|
| 1st | `#FFD700` | Gold |
| 2nd | `#C0C0C0` | Silver |
| 3rd | `#CD7F32` | Bronze |
| 4th+ | White (40% opacity) | -- |

### M3 Model Colors (3D Visualization)

| Model | Hex |
|-------|-----|
| Opus | `#9C27B0` |
| Sonnet | `#2196F3` |
| Haiku | `#4CAF50` |
| Other | `#FF9800` |

### M4 Trend Direction Colors

| Trend | Hex | Icon |
|-------|-----|------|
| Improving | `#4CAF50` | arrow.up.right |
| Stable | `#FF9800` | arrow.right |
| Declining | `#F44336` | arrow.down.right |

### M5 Agent Specialization Colors

| Specialization | Hex |
|----------------|-----|
| General | `#9E9E9E` |
| Code Generation | `#2196F3` |
| Code Review | `#9C27B0` |
| Testing | `#4CAF50` |
| Debugging | `#F44336` |
| Documentation | `#FF9800` |
| Architecture | `#00BCD4` |

---

## 3D Visualization Configuration

### Rotation Speeds

| Builder | Container Rotation | Ring/Orbit Rotation | Pulse |
|---------|-------------------|---------------------|-------|
| M1: AnalyticsDashboard | 80s full cycle | Hub ring: 10s, Opt ring: 45s | Hub: 2s scale 1.0-1.1 |
| M2: ReportExport | 75s full cycle | Schedule ring: 50s | Hub: 1.5s scale 1.0-1.05, In-progress: 0.5s fade |
| M3: APIUsage | 60s full cycle | Call trail: 30s | Budget ring: conditional pulse |
| M4: SessionHistory | 70s full cycle | Hub ring: 12s | Hub: 2s scale 1.0-1.1 |
| M5: TeamPerformance | 65s full cycle | Hub ring: 10s | Hub: 2s scale 1.0-1.1 |

### Node Naming Convention

All 3D nodes follow this naming pattern:

- Container: `{feature}Visualization` (e.g., `analyticsDashboardVisualization`)
- Child nodes: `{type}_{id}` (e.g., `report_UUID`, `exportJob_UUID`, `session_UUID`)
- Groups: `{groupName}` (e.g., `optimizationRing`, `scheduleRing`, `apiCallTrail`)

### Display Limits (3D)

To maintain rendering performance, each builder caps displayed elements:

| Builder | Element | Max Displayed |
|---------|---------|---------------|
| M1 | Reports | 4 |
| M1 | Forecasts | 3 |
| M1 | Optimization Tips | 5 |
| M2 | Export Jobs | 5 |
| M2 | Schedules | 4 |
| M3 | Model Columns | All models |
| M3 | Call Trail | Most recent |
| M4 | Sessions | Based on data |
| M5 | Members | All members |

---

## Localization Keys

M-series features use the `LocalizationManager` service for UI strings. Key prefixes:

| Feature | Key Prefix | Example Keys |
|---------|------------|-------------|
| M4 | `sh` | `shSessionAnalytics`, `shTotalSessions`, `shProductivity`, `shTotalTasks`, `shTrend`, `shTimeDistribution`, `shComparisons`, `shNoTrend`, `shNoSessions` |
| M5 | `tp` | `tpTeamPerformance`, `tpEfficiency`, `tpMembers`, `tpRadar`, `tpLeaderboard`, `tpSpecialization`, `tpNoData` |
| Shared | `au` | `auTotalCost` |

---

## File Reference

Complete list of all M-series source files:

### Models

| File | Feature | Line Count |
|------|---------|------------|
| `Models/AnalyticsDashboardModels.swift` | M1 | ~200 |
| `Models/ReportExportModels.swift` | M2 | ~310 |
| `Models/APIUsageAnalyticsModels.swift` | M3 | ~250 |
| `Models/SessionHistoryAnalyticsModels.swift` | M4 | ~200 |
| `Models/TeamPerformanceModels.swift` | M5 | ~250 |

### Services

| File | Feature | Line Count |
|------|---------|------------|
| `Services/AnalyticsDashboardManager.swift` | M1 | ~450 |
| `Services/AdvancedAnalyticsDashboardManager.swift` | M1 | ~440 |
| `Services/ReportExportManager.swift` | M2 | ~350 |
| `Services/ReportGenerationManager.swift` | M2 | ~384 |
| `Services/APIUsageAnalyticsManager.swift` | M3 | ~454 |
| `Services/SessionHistoryAnalyticsManager.swift` | M4 | ~300 |
| `Services/TeamPerformanceManager.swift` | M5 | ~300 |

### Views

| File | Feature |
|------|---------|
| `Views/Overlays/AnalyticsDashboardOverlay.swift` | M1 |
| `Views/Overlays/AnalyticsDashboardView.swift` | M1 |
| `Views/Overlays/ReportExportOverlay.swift` | M2 |
| `Views/Overlays/ReportExportView.swift` | M2 |
| `Views/Overlays/APIUsageAnalyticsOverlay.swift` | M3 |
| `Views/Overlays/APIUsageAnalyticsView.swift` | M3 |
| `Views/Overlays/SessionHistoryAnalyticsOverlay.swift` | M4 |
| `Views/Overlays/SessionHistoryAnalyticsView.swift` | M4 |
| `Views/Overlays/TeamPerformanceOverlay.swift` | M5 |
| `Views/Overlays/TeamPerformanceView.swift` | M5 |

### Charts (Shared)

| File | Used By |
|------|---------|
| `Views/Components/Charts/MiniBarChart.swift` | M4, M5 |
| `Views/Components/Charts/MiniLineChart.swift` | M4 |
| `Views/Components/Charts/MiniPieChart.swift` | M4, M5 |
| `Views/Components/Charts/MiniRadarChart.swift` | M5 |
| `Views/Components/Charts/StatCard.swift` | M4, M5 |
| `Views/Components/Charts/SessionHistoryChartPanel.swift` | M4 |
| `Views/Components/Charts/TeamPerformanceChartPanel.swift` | M5 |

### 3D Visualization

| File | Feature |
|------|---------|
| `Scene3D/Effects/AnalyticsDashboardVisualizationBuilder.swift` | M1 |
| `Scene3D/Effects/ReportExportVisualizationBuilder.swift` | M2 |
| `Scene3D/Effects/APIUsageVisualizationBuilder.swift` | M3 |
| `Scene3D/Effects/SessionHistoryVisualizationBuilder.swift` | M4 |
| `Scene3D/Effects/TeamPerformanceVisualizationBuilder.swift` | M5 |

### Tests

| File | Feature |
|------|---------|
| `Tests/AnalyticsDashboardModelsTests.swift` | M1 |
| `Tests/ReportExportModelsTests.swift` | M2 |
| `Tests/APIUsageAnalyticsModelsTests.swift` | M3 |
| `Tests/SessionHistoryAnalyticsModelsTests.swift` | M4 |
| `Tests/SessionHistoryAnalyticsManagerTests.swift` | M4 |
| `Tests/TeamPerformanceModelsTests.swift` | M5 |
| `Tests/TeamPerformanceManagerTests.swift` | M5 |
| `Tests/M4M5IntegrationTests.swift` | M4+M5 |
| `Tests/MSeriesDataVisualizationTests.swift` | Charts |
| `Tests/MSeriesIntegrationTests.swift` | M1-M3 |
