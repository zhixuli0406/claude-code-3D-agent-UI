# M-Series Usage Guide

Practical guide for using the M-series Data & Analytics features in AgentCommand.

---

## Table of Contents

- [Quick Start](#quick-start)
- [M1: Advanced Analytics Dashboard](#m1-advanced-analytics-dashboard)
- [M2: Report Export & Generation](#m2-report-export--generation)
- [M3: API Usage Analytics](#m3-api-usage-analytics)
- [M4: Session History Analytics](#m4-session-history-analytics)
- [M5: Team Performance Metrics](#m5-team-performance-metrics)
- [Cross-Feature Workflows](#cross-feature-workflows)
- [Running Tests](#running-tests)

---

## Quick Start

The M-series provides 5 analytics modules:

- **M1**: Advanced Analytics Dashboard — Custom reports, trend forecasting, cost optimization, benchmarking
- **M2**: Report Export & Generation — Template-based reports, scheduled exports, multi-format output
- **M3**: API Usage Analytics — Call tracking, cost analysis, budget alerts, usage forecasting
- **M4**: Session History Analytics — Session recording, productivity trends, time distribution, session comparison
- **M5**: Team Performance Metrics — Team snapshots, radar charts, leaderboards, agent specialization tracking

### Enabling Features

All M-series features are enabled by default. Toggle visibility via AppState:

```swift
appState.toggleAnalyticsDashboardStatus()      // M1
appState.toggleReportExportStatus()             // M2
appState.toggleAPIUsageAnalyticsStatus()        // M3
appState.toggleSessionHistoryAnalyticsStatus()  // M4
appState.toggleTeamPerformanceStatus()          // M5
```

### Loading Sample Data

For development and testing:

```swift
appState.analyticsDashboardManager.loadSampleData()
appState.reportExportManager.loadSampleData()
appState.apiUsageAnalyticsManager.loadSampleData()
appState.sessionHistoryAnalyticsManager.loadSampleData()
appState.teamPerformanceManager.loadSampleData()
```

---

## M1: Advanced Analytics Dashboard

### Creating Custom Reports

Create a report and populate it with widgets to visualize your analytics data:

```swift
let manager = appState.analyticsDashboardManager
let report = manager.createReport(
    name: "Weekly Performance",
    description: "Weekly overview of agent performance",
    timeRange: .last7Days
)
```

### Configuring Widgets

Add widgets to a report by specifying the widget type, data source, and size:

```swift
let widget = ReportWidget(
    id: UUID(),
    title: "Token Usage Over Time",
    widgetType: .lineChart,
    dataSource: .tokenUsage,
    size: .large,
    position: 0
)
manager.addWidget(to: report.id, widget: widget)
```

**Widget Types:** `lineChart`, `barChart`, `pieChart`, `metric`, `table`, `heatmap`

**Data Sources:** `tokenUsage`, `costOverTime`, `taskCompletion`, `errorRate`, `responseLatency`, `modelDistribution`

**Sizes:** `small`, `medium`, `large`

### Trend Forecasting

Generate a forecast for any supported metric over a configurable time horizon:

```swift
let forecast = manager.generateForecast(for: .cost, horizonDays: 30)
// forecast.confidence: 0.0-1.0
// forecast.dataPoints: predicted values
```

### Cost Optimization

Cost optimization tips are auto-generated across 5 categories: `modelSelection`, `promptOptimization`, `caching`, `batchProcessing`, `tokenReduction`. Apply or dismiss individual tips:

```swift
manager.applyOptimizationTip(id: tipId)
manager.dismissOptimizationTip(id: tipId)
```

Check the total potential savings across all unapplied tips:

```swift
let savings = manager.totalPotentialSavings  // USD
```

### Performance Benchmarking

Create benchmarks to compare performance across models and agents:

```swift
let benchmark = manager.createBenchmark(name: "Model Comparison", metric: .costEfficiency)
manager.addBenchmarkEntry(to: benchmark.id, entry: entry)
```

### UI Components

- **Overlay (AnalyticsDashboardOverlay)**: Quick summary panel showing report count, forecasts, savings
- **Full View (AnalyticsDashboardView)**: 4 tabs — Reports, Trends, Cost Optimization, Benchmarks
- **3D Visualization**: Central hub with report panels, forecast arrows, optimization ring

---

## M2: Report Export & Generation

### Creating Templates

Define reusable report templates with configurable sections:

```swift
let manager = appState.reportExportManager
let template = manager.createTemplate(
    name: "Monthly Report",
    description: "Comprehensive monthly analysis",
    sections: [
        ReportSection(type: .executiveSummary, isEnabled: true, sortOrder: 0),
        ReportSection(type: .tokenUsage, isEnabled: true, sortOrder: 1),
        ReportSection(type: .costAnalysis, isEnabled: true, sortOrder: 2)
    ]
)
```

6 section types are available: `executiveSummary`, `tokenUsage`, `costAnalysis`, `taskMetrics`, `errorAnalysis`, `performanceTrends`.

### Scheduling Exports

Set up automated recurring exports:

```swift
let schedule = manager.createSchedule(
    name: "Daily Summary",
    templateId: template.id,
    frequency: .daily,
    format: .json
)
```

Frequencies: `daily`, `weekly`, `biweekly`, `monthly`. The manager checks schedules every 60 seconds and triggers exports for any schedules past their `nextRunAt` date.

### Running Exports

Trigger a one-time export and track its progress:

```swift
manager.exportReport(format: .json, templateId: template.id)
// Track progress via exportJobs array
// Cancel with: manager.cancelExport(jobId)
```

### Export Formats

| Format | Description | Use Case |
|--------|-------------|----------|
| JSON | Structured data | API integration, programmatic processing |
| CSV | Tabular data | Spreadsheet analysis, data import |
| Markdown | Formatted text | Documentation, README updates |
| PDF | Print-ready | Stakeholder reports, archival |

### Advanced: ReportGenerationManager

For direct format conversion without going through the export job pipeline:

```swift
let genManager = ReportGenerationManager()
let report = genManager.generateReport(from: template)
let json = genManager.exportToJSON(report)
let csv = genManager.exportToCSV(report)
let md = genManager.exportToMarkdown(report)
```

Templates persist via `UserDefaults` with the key `"reportTemplates"`.

---

## M3: API Usage Analytics

### Recording API Calls

Record individual API call metrics as they occur:

```swift
let manager = appState.apiUsageAnalyticsManager
manager.recordAPICall(APICallMetrics(
    model: "claude-opus-4-6",
    inputTokens: 1500,
    outputTokens: 800,
    latencyMs: 450.0,
    costUSD: 0.045,
    isError: false,
    taskType: "code_generation",
    timestamp: Date()
))
```

### Monitoring

Enable real-time monitoring to keep summary, model stats, and forecasts up to date:

```swift
manager.startMonitoring()  // Updates every 30 seconds
// Updates: summary, model stats, forecast
manager.stopMonitoring()
```

### Budget Management

Set a spending budget and receive threshold-based alerts:

```swift
manager.setBudget(limit: 100.0, period: "monthly")
// Thresholds:
// < 70%: normal (green)
// 70-90%: warning (orange)
// > 90%: critical (red)
```

### Cost Analysis

Generate a breakdown of costs grouped by model:

```swift
let breakdown = manager.generateCostBreakdown()
// Groups costs by model with percentage breakdown
```

### Usage Forecasting

Project end-of-month spending using Simple Moving Average trend detection:

```swift
let forecast = manager.generateForecast()
// forecast.projectedMonthEndCost
// forecast.trend: .increasing / .stable / .decreasing
```

### UI Components

- **Overlay**: Shows total calls, cost, error rate, budget status, top models
- **Full View**: 4 tabs — Overview, Call History, Cost Analysis, Budget Management
- **3D**: Budget gauge ring, model columns, call trail particles

---

## M4: Session History Analytics

### Recording Sessions

Record a completed work session with its full set of metrics:

```swift
let manager = appState.sessionHistoryAnalyticsManager
manager.recordSession(SessionAnalytics(
    sessionName: "Feature Implementation",
    startedAt: Date().addingTimeInterval(-3600),
    endedAt: Date(),
    totalTokens: 25000,
    totalCost: 0.75,
    tasksCompleted: 12,
    tasksFailed: 1,
    agentsUsed: 3,
    dominantModel: "claude-opus-4-6",
    averageLatencyMs: 320,
    peakTokenRate: 1500,
    productivityScore: 0.85
))
```

### Productivity Analysis

Analyze productivity trends across all recorded sessions:

```swift
let trend = manager.analyzeProductivityTrend()
// trend.overallTrend: .improving / .stable / .declining
// trend.averageProductivity: 0.0-1.0
// trend.dataPoints: historical data
```

### Session Comparison

Compare two sessions side-by-side with computed deltas:

```swift
let comparison = manager.compareSessions(sessionA: session1, sessionB: session2)
// comparison.metrics: [ComparisonMetric] with name, valueA, valueB, delta
```

### Time Distribution

Analyze how time was allocated across activity categories within a session:

```swift
let distribution = manager.analyzeTimeDistribution(for: session)
// Categories: coding, reviewing, debugging, testing, planning, idle
// Each with minutes and percentage
```

### UI Components

- **Overlay (purple theme)**: Session count, productivity %, tasks, cost, recent sessions
- **Full View**: 4 tabs — Sessions, Productivity, Time Distribution, Comparisons
- **Chart Panel**: Stats grid, line chart, pie chart, comparison bars, bar chart
- **3D**: Timeline hub, session arcs, trend line, time distribution ring

---

## M5: Team Performance Metrics

### Capturing Snapshots

Capture a point-in-time snapshot of team performance:

```swift
let manager = appState.teamPerformanceManager
let snapshot = manager.captureSnapshot(
    teamName: "AI Agent Team",
    members: [
        AgentPerformanceMetric(
            agentName: "CodeGen Agent",
            role: "Developer",
            tasksCompleted: 45,
            tasksFailed: 3,
            averageLatencyMs: 280,
            totalTokens: 150000,
            totalCost: 4.50,
            efficiency: 0.92,
            specialization: .codeGeneration
        ),
        // ... more agents
    ]
)
```

### Radar Chart Data

Generate multi-dimensional performance data for radar chart visualization:

```swift
let radar = manager.generateRadarData(from: snapshot)
// 6 dimensions: speed, quality, costEfficiency, reliability, collaboration, throughput
// Each 0.0-1.0
```

### Leaderboard

Rank team members by a specific performance metric:

```swift
let leaderboard = manager.generateLeaderboard(
    metric: .successRate,
    from: snapshot
)
// Auto-sorted by score, ranked entries with trend direction
```

### Agent Specializations

7 specialization types are available, each with a display name, icon, and color:

| Specialization | Description |
|----------------|-------------|
| `general` | General-purpose agent |
| `codeGeneration` | Code generation and creation |
| `codeReview` | Code review and analysis |
| `testing` | Test writing and execution |
| `debugging` | Bug diagnosis and resolution |
| `documentation` | Documentation writing |
| `architecture` | System design and architecture |

### UI Components

- **Overlay (orange theme)**: Efficiency %, tasks, cost, members, top agents
- **Full View**: 4 tabs — Overview, Members, Radar, Leaderboard
- **Chart Panel**: Stats grid, radar chart, efficiency bars, leaderboard list, specialization pie
- **3D**: Performance hub, member columns, radar ring, leaderboard podium

---

## Cross-Feature Workflows

### End-to-End Analytics Pipeline

1. Record API calls (M3) during agent operations
2. Record session data (M4) when sessions complete
3. Capture team snapshots (M5) periodically
4. Analyze trends and generate reports (M1)
5. Export and share reports (M2)

### Dashboard + Budget Monitoring

Combine M1 cost optimization tips with M3 budget alerts for comprehensive cost management. Use M1 forecasts to anticipate when M3 budget thresholds will be triggered, and apply M1 optimization tips to reduce projected spending.

### Session-to-Team Analysis

Use M4 session data to feed M5 team performance analysis. Compare individual session productivity with team-wide efficiency metrics. Session comparison (M4) can help identify which team members (M5) are driving performance improvements.

---

## Running Tests

Run the full test suite:

```bash
cd AgentCommand
swift test
```

Run tests by feature:

```bash
swift test --filter AnalyticsDashboardModelsTests    # M1
swift test --filter ReportExportModelsTests           # M2
swift test --filter APIUsageAnalyticsModelsTests      # M3
swift test --filter SessionHistoryAnalyticsModelsTests # M4 models
swift test --filter SessionHistoryAnalyticsManagerTests # M4 manager
swift test --filter TeamPerformanceModelsTests         # M5 models
swift test --filter TeamPerformanceManagerTests         # M5 manager
swift test --filter M4M5IntegrationTests               # M4+M5 integration
swift test --filter MSeriesDataVisualizationTests      # Chart components
```
