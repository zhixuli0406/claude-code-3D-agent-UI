# M-Series API Documentation

This document describes the APIs for the M-series features: Advanced Analytics Dashboard (M1), Report Export & Generation (M2), API Usage Analytics (M3), Session History Analytics (M4), and Team Performance Metrics (M5).

---

## Table of Contents

- [M1: Advanced Analytics Dashboard](#m1-advanced-analytics-dashboard)
  - [Models](#m1-models)
  - [AnalyticsDashboardManager](#analyticsdashboardmanager)
  - [AdvancedAnalyticsDashboardManager](#advancedanalyticsdashboardmanager)
- [M2: Report Export & Generation](#m2-report-export--generation)
  - [Models](#m2-models)
  - [ReportExportManager](#reportexportmanager)
  - [ReportGenerationManager](#reportgenerationmanager)
- [M3: API Usage Analytics](#m3-api-usage-analytics)
  - [Models](#m3-models)
  - [APIUsageAnalyticsManager](#apiusageanalyticsmanager)
- [M4: Session History Analytics](#m4-session-history-analytics)
  - [Models](#m4-models)
  - [SessionHistoryAnalyticsManager](#sessionhistoryanalyticsmanager)
- [M5: Team Performance Metrics](#m5-team-performance-metrics)
  - [Models](#m5-models)
  - [TeamPerformanceManager](#teamperformancemanager)
- [AppState Integration](#appstate-integration)

---

## M1: Advanced Analytics Dashboard

### M1 Models

**File:** `AgentCommand/Models/AnalyticsDashboardModels.swift`

#### DashboardReport

Custom analytics report definition.

```swift
struct DashboardReport: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var widgets: [ReportWidget]
    var createdAt: Date
    var updatedAt: Date
    var timeRange: AnalyticsTimeRange
}
```

#### ReportWidget

Configurable dashboard widget.

```swift
struct ReportWidget: Identifiable, Codable {
    let id: UUID
    var title: String
    var widgetType: WidgetType
    var dataSource: WidgetDataSource
    var size: WidgetSize
    var position: Int
}
```

**WidgetType** — `lineChart`, `barChart`, `pieChart`, `metric`, `table`, `heatmap`

**WidgetDataSource** — `tokenUsage`, `costOverTime`, `taskCompletion`, `errorRate`, `responseLatency`, `modelDistribution`

**WidgetSize** — `small`, `medium`, `large`

#### TrendForecast

```swift
struct TrendForecast: Identifiable, Codable {
    let id: UUID
    var metric: ForecastMetric
    var dataPoints: [ForecastDataPoint]
    var confidence: Double        // 0.0 – 1.0
    var generatedAt: Date
    var forecastHorizonDays: Int
}
```

**ForecastMetric** — `tokenUsage`, `cost`, `taskCount`, `errorRate`, `responseTime`

#### CostOptimizationTip

```swift
struct CostOptimizationTip: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var category: OptimizationCategory
    var impact: OptimizationImpact
    var estimatedSavings: Double  // USD
    var isApplied: Bool
}
```

**OptimizationCategory** — `modelSelection`, `promptOptimization`, `caching`, `batchProcessing`, `tokenReduction`

**OptimizationImpact** — `high`, `medium`, `low`

#### PerformanceBenchmark

```swift
struct PerformanceBenchmark: Identifiable, Codable {
    let id: UUID
    var name: String
    var metric: BenchmarkMetric
    var entries: [BenchmarkEntry]
    var createdAt: Date
}
```

**BenchmarkMetric** — `responseTime`, `tokenEfficiency`, `taskSuccessRate`, `costPerTask`, `throughput`

#### AnalyticsTimeRange

```swift
enum AnalyticsTimeRange: String, Codable, CaseIterable {
    case lastHour, last24Hours, last7Days, last30Days, last90Days, custom
}
```

#### AnalyticsDataPoint

```swift
struct AnalyticsDataPoint: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    var value: Double
    var label: String
}
```

---

### AnalyticsDashboardManager

**File:** `AgentCommand/Services/AnalyticsDashboardManager.swift`

Simplified analytics manager for standard use. `@MainActor ObservableObject`.

#### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `reports` | `[DashboardReport]` | Custom reports |
| `forecasts` | `[TrendForecast]` | Trend forecasts |
| `optimizationTips` | `[CostOptimizationTip]` | Cost optimization suggestions |
| `benchmarks` | `[PerformanceBenchmark]` | Performance benchmarks |
| `isLoading` | `Bool` | Loading state |
| `selectedTimeRange` | `AnalyticsTimeRange` | Current filter time range |

#### Computed Properties

| Property | Type | Description |
|----------|------|-------------|
| `totalPotentialSavings` | `Double` | Sum of all unapplied tip savings |
| `appliedSavingsCount` | `Int` | Count of applied optimization tips |

#### Methods

```swift
// Report management
func createReport(name: String, description: String, timeRange: AnalyticsTimeRange) -> DashboardReport
func deleteReport(id: UUID)
func addWidget(to reportId: UUID, widget: ReportWidget)
func removeWidget(from reportId: UUID, widgetId: UUID)

// Trend forecasting
func generateForecast(for metric: ForecastMetric, horizonDays: Int) -> TrendForecast

// Cost optimization
func applyOptimizationTip(id: UUID)
func dismissOptimizationTip(id: UUID)

// Benchmarking
func createBenchmark(name: String, metric: BenchmarkMetric) -> PerformanceBenchmark
func addBenchmarkEntry(to benchmarkId: UUID, entry: BenchmarkEntry)

// Data
func loadSampleData()
```

---

### AdvancedAnalyticsDashboardManager

**File:** `AgentCommand/Services/AdvancedAnalyticsDashboardManager.swift`

Full-featured analytics manager with advanced algorithms. `@MainActor ObservableObject`.

Same published properties as `AnalyticsDashboardManager`, plus advanced features:

#### Advanced Methods

```swift
// Report management (same API as simplified manager)
func createReport(name: String, description: String, timeRange: AnalyticsTimeRange) -> DashboardReport
func deleteReport(id: UUID)
func addWidget(to reportId: UUID, widget: ReportWidget)
func removeWidget(from reportId: UUID, widgetId: UUID)
func reorderWidgets(in reportId: UUID, fromIndex: Int, toIndex: Int)

// Trend forecasting (with Simple Moving Average algorithm)
func generateForecast(for metric: ForecastMetric, horizonDays: Int) -> TrendForecast

// Cost optimization analysis
func generateOptimizationTips()  // Analyzes model selection, token reduction, caching, batch processing
func applyOptimizationTip(id: UUID)
func dismissOptimizationTip(id: UUID)

// Performance benchmarking
func createBenchmark(name: String, metric: BenchmarkMetric) -> PerformanceBenchmark
func addBenchmarkEntry(to benchmarkId: UUID, entry: BenchmarkEntry)

// Time series data
func aggregateData(for source: WidgetDataSource, timeRange: AnalyticsTimeRange) -> [AnalyticsDataPoint]
```

#### Memory Limits

| Resource | Max Count |
|----------|-----------|
| Reports | 50 |
| Forecasts | 20 |
| Optimization Tips | 100 |
| Benchmarks | 30 |

---

## M2: Report Export & Generation

### M2 Models

**File:** `AgentCommand/Models/ReportExportModels.swift`

#### ExportFormat

```swift
enum ExportFormat: String, Codable, CaseIterable {
    case json, csv, markdown, pdf
}
```

#### ReportTemplate

```swift
struct ReportTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var sections: [ReportSection]
    var createdAt: Date
    var updatedAt: Date
}
```

#### ReportSection

```swift
struct ReportSection: Identifiable, Codable {
    let id: UUID
    var title: String
    var sectionType: SectionType
    var isEnabled: Bool
    var order: Int
}
```

**SectionType** — `executiveSummary`, `tokenUsage`, `costAnalysis`, `taskMetrics`, `errorAnalysis`, `performanceTrends`

#### ReportSchedule

```swift
struct ReportSchedule: Identifiable, Codable {
    let id: UUID
    var templateId: UUID
    var frequency: ScheduleFrequency
    var isEnabled: Bool
    var lastRunAt: Date?
    var nextRunAt: Date
    var format: ExportFormat
}
```

**ScheduleFrequency** — `daily`, `weekly`, `biweekly`, `monthly`

#### ExportJob

```swift
struct ExportJob: Identifiable, Codable {
    let id: UUID
    var templateId: UUID
    var format: ExportFormat
    var status: ExportStatus
    var progress: Double          // 0.0 – 1.0
    var startedAt: Date
    var completedAt: Date?
    var fileSizeBytes: Int?
    var errorMessage: String?
}
```

**ExportStatus** — `pending`, `inProgress`, `completed`, `failed`

#### ReportData

```swift
struct ReportData: Identifiable, Codable {
    let id: UUID
    var templateName: String
    var generatedAt: Date
    var timeRange: String
    var summary: ReportSummary
    var taskMetrics: ReportTaskMetrics
    var errorMetrics: ReportErrorMetrics
}
```

---

### ReportExportManager

**File:** `AgentCommand/Services/ReportExportManager.swift`

Core export workflow manager. `@MainActor ObservableObject`.

#### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `templates` | `[ReportTemplate]` | Available report templates |
| `schedules` | `[ReportSchedule]` | Configured schedules |
| `exportJobs` | `[ExportJob]` | Export job history |
| `generatedReports` | `[ReportData]` | Generated report data |
| `isExporting` | `Bool` | Export in progress |

#### Methods

```swift
// Template management
func createTemplate(name: String, description: String, sections: [ReportSection]) -> ReportTemplate
func deleteTemplate(id: UUID)

// Schedule management
func createSchedule(templateId: UUID, frequency: ScheduleFrequency, format: ExportFormat) -> ReportSchedule
func toggleSchedule(id: UUID)
func deleteSchedule(id: UUID)

// Export execution
func startExport(templateId: UUID, format: ExportFormat) async  // Simulates progress with report data generation

// Data
func loadSampleData()
```

#### Schedule Monitoring

The manager starts a `Timer` that checks schedules every **60 seconds** and triggers exports for any schedules past their `nextRunAt` date.

#### Memory Limits

| Resource | Max Count |
|----------|-----------|
| Export Jobs | 50 |
| Generated Reports | 20 |

---

### ReportGenerationManager

**File:** `AgentCommand/Services/ReportGenerationManager.swift`

Advanced report generation with format conversion. `@MainActor ObservableObject`.

#### Published Properties

Same as `ReportExportManager`, plus:

| Property | Type | Description |
|----------|------|-------------|
| `selectedFormat` | `ExportFormat` | Currently selected export format |

#### Methods

```swift
// Template management
func createTemplate(name: String, description: String) -> ReportTemplate
func deleteTemplate(id: UUID)
func updateTemplateSections(templateId: UUID, sections: [ReportSection])

// Report generation
func generateReport(from template: ReportTemplate) -> ReportData

// Format conversion
func exportToJSON(_ report: ReportData) -> String
func exportToCSV(_ report: ReportData) -> String
func exportToMarkdown(_ report: ReportData) -> String

// Schedule management
func createSchedule(templateId: UUID, frequency: ScheduleFrequency, format: ExportFormat) -> ReportSchedule
func toggleSchedule(id: UUID)
func deleteSchedule(id: UUID)
func checkSchedules()

// Persistence
func saveTemplates()   // Saves to UserDefaults
func loadTemplates()   // Loads from UserDefaults
```

#### Memory Limits

| Resource | Max Count |
|----------|-----------|
| Templates | 30 |
| Schedules | 20 |
| Export Jobs | 50 |

---

## M3: API Usage Analytics

### M3 Models

**File:** `AgentCommand/Models/APIUsageAnalyticsModels.swift`

#### APICallMetrics

```swift
struct APICallMetrics: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    var model: String
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var latencyMs: Double
    var cost: Double
    var success: Bool
    var errorMessage: String?
    var taskType: String
}
```

#### CostBreakdown

```swift
struct CostBreakdown: Identifiable, Codable {
    let id: UUID
    var period: String
    var totalCost: Double
    var entries: [CostBreakdownEntry]
    var generatedAt: Date
}
```

#### BudgetAlert

```swift
struct BudgetAlert: Identifiable, Codable {
    let id: UUID
    var budgetLimit: Double       // USD
    var currentSpend: Double
    var alertLevel: BudgetAlertLevel
    var period: String
    var resetDate: Date
}
```

**BudgetAlertLevel** — `normal`, `warning` (>70%), `critical` (>90%)

#### UsageForecast

```swift
struct UsageForecast: Identifiable, Codable {
    let id: UUID
    var projectedMonthEndCost: Double
    var projectedMonthEndTokens: Int
    var dailyAverageCost: Double
    var dailyAverageTokens: Int
    var trend: UsageTrend
    var confidence: Double
    var generatedAt: Date
}
```

**UsageTrend** — `increasing`, `stable`, `decreasing`

#### ModelUsageStats

```swift
struct ModelUsageStats: Identifiable, Codable {
    let id: UUID
    var model: String
    var totalCalls: Int
    var totalTokens: Int
    var totalCost: Double
    var averageLatency: Double
    var errorRate: Double
    var lastUsed: Date
}
```

#### APIUsageSummary

```swift
struct APIUsageSummary: Identifiable, Codable {
    let id: UUID
    var period: String
    var totalCalls: Int
    var totalTokens: Int
    var totalCost: Double
    var averageLatency: Double
    var errorRate: Double
    var mostUsedModel: String
}
```

---

### APIUsageAnalyticsManager

**File:** `AgentCommand/Services/APIUsageAnalyticsManager.swift`

Comprehensive API usage tracking and analysis. `@MainActor ObservableObject`.

#### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `callMetrics` | `[APICallMetrics]` | Individual API call records |
| `costBreakdowns` | `[CostBreakdown]` | Cost breakdowns by period |
| `budgetAlert` | `BudgetAlert?` | Current budget alert state |
| `usageForecast` | `UsageForecast?` | Projected usage |
| `modelStats` | `[ModelUsageStats]` | Per-model statistics |
| `usageSummary` | `APIUsageSummary?` | Aggregated summary |
| `isMonitoring` | `Bool` | Monitoring active state |

#### Methods

```swift
// Recording
func recordAPICall(_ metrics: APICallMetrics)

// Monitoring (Timer every 30 seconds)
func startMonitoring()
func stopMonitoring()

// Cost analysis
func generateCostBreakdown() -> CostBreakdown  // Groups costs by model

// Budget management
func setBudget(limit: Double, period: String)
func updateBudgetSpend(_ amount: Double)

// Forecasting (Simple Moving Average with trend detection)
func generateForecast() -> UsageForecast

// Statistics
func updateSummary()
func updateModelStats()

// Data
func loadSampleData()  // Generates 25 sample API calls, 3 model stats, budget alert
```

#### Monitoring Cycle

When monitoring is active, a `Timer` fires every **30 seconds** to:
1. Update the usage summary
2. Update per-model statistics
3. Regenerate the usage forecast

#### Memory Limits

| Resource | Max Count |
|----------|-----------|
| Call Metrics | 500 |
| Cost Breakdowns | 10 |

---

## M4: Session History Analytics

### M4 Models

**File:** `AgentCommand/Models/SessionHistoryAnalyticsModels.swift`

#### SessionAnalytics

```swift
struct SessionAnalytics: Identifiable, Codable, Hashable {
    let id: String  // UUID
    var sessionName: String
    var startedAt: Date
    var endedAt: Date?
    var totalTokens: Int
    var totalCost: Double
    var tasksCompleted: Int
    var tasksFailed: Int
    var agentsUsed: Int
    var dominantModel: String
    var averageLatencyMs: Double
    var peakTokenRate: Int
    var productivityScore: Double  // 0.0-1.0
}
```

Computed properties: `duration`, `formattedDuration`, `formattedCost`, `successRate`, `successRatePercentage`, `productivityLabel`, `productivityColorHex`

#### ProductivityTrend

```swift
struct ProductivityTrend: Identifiable, Codable, Hashable {
    let id: String
    var dataPoints: [ProductivityDataPoint]
    var overallTrend: TrendDirection
    var averageProductivity: Double
    var generatedAt: Date
}
```

Computed properties: `averagePercentage`

#### ProductivityDataPoint

```swift
struct ProductivityDataPoint: Identifiable, Codable, Hashable {
    let id: String
    var date: Date
    var productivity: Double  // 0.0-1.0
    var tasksCompleted: Int
    var tokensUsed: Int
    var cost: Double
}
```

#### TrendDirection

```swift
enum TrendDirection {
    case improving, stable, declining
}
```

Properties: `displayName`, `iconName`, `colorHex`

#### SessionComparison

```swift
struct SessionComparison: Identifiable, Codable, Hashable {
    let id: String
    var sessionAId: String
    var sessionBId: String
    var sessionAName: String
    var sessionBName: String
    var metrics: [ComparisonMetric]
    var generatedAt: Date
}
```

Initializer accepts two `SessionAnalytics` objects and auto-generates comparison metrics.

#### ComparisonMetric

```swift
struct ComparisonMetric: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var valueA: Double
    var valueB: Double
    var unit: String
}
```

Computed properties: `delta`, `deltaPercentage`, `deltaDisplay`

#### SessionTimeDistribution

```swift
struct SessionTimeDistribution: Identifiable, Codable, Hashable {
    let id: String
    var entries: [TimeDistributionEntry]
    var totalMinutes: Double
}
```

#### TimeDistributionEntry

```swift
struct TimeDistributionEntry: Identifiable, Codable, Hashable {
    let id: String
    var category: TimeCategory
    var minutes: Double
    var percentage: Double
}
```

**TimeCategory** — `coding`, `reviewing`, `debugging`, `testing`, `planning`, `idle`

Properties: `displayName`, `colorHex`, `iconName`

---

### SessionHistoryAnalyticsManager

**File:** `AgentCommand/Services/SessionHistoryAnalyticsManager.swift`

Session history analytics and productivity tracking. `@MainActor ObservableObject`.

#### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `sessions` | `[SessionAnalytics]` | All recorded sessions |
| `productivityTrend` | `ProductivityTrend?` | Current trend analysis |
| `comparisons` | `[SessionComparison]` | Session comparisons |
| `currentTimeDistribution` | `SessionTimeDistribution?` | Active time distribution |
| `isAnalyzing` | `Bool` | Analysis in progress |

#### Computed Properties

| Property | Type | Description |
|----------|------|-------------|
| `totalSessions` | `Int` | Total session count |
| `averageProductivity` | `Double` | Average productivity score |
| `totalTasksAllSessions` | `Int` | Sum of all tasks across sessions |
| `totalCostAllSessions` | `Double` | Sum of all costs across sessions |

#### Methods

```swift
// Session recording
func recordSession(_ session: SessionAnalytics)

// Productivity analysis
func analyzeProductivityTrend() -> ProductivityTrend

// Session comparison
func compareSessions(sessionA: SessionAnalytics, sessionB: SessionAnalytics) -> SessionComparison

// Time distribution
func analyzeTimeDistribution(for session: SessionAnalytics) -> SessionTimeDistribution

// Data
func loadSampleData()
```

#### Memory Limits

| Resource | Max Count |
|----------|-----------|
| Sessions | 100 |
| Comparisons | 20 |

---

## M5: Team Performance Metrics

### M5 Models

**File:** `AgentCommand/Models/TeamPerformanceModels.swift`

#### TeamPerformanceSnapshot

```swift
struct TeamPerformanceSnapshot: Identifiable, Codable, Hashable {
    let id: String
    var teamName: String
    var capturedAt: Date
    var memberMetrics: [AgentPerformanceMetric]
    var overallEfficiency: Double  // 0.0-1.0
    var totalTasksCompleted: Int
    var totalCost: Double
    var averageResponseTime: Double  // ms
}
```

Computed properties: `efficiencyPercentage`, `formattedCost`, `efficiencyLabel`, `efficiencyColorHex`

#### AgentPerformanceMetric

```swift
struct AgentPerformanceMetric: Identifiable, Codable, Hashable {
    let id: String
    var agentName: String
    var role: String
    var tasksCompleted: Int
    var tasksFailed: Int
    var averageLatencyMs: Double
    var totalTokens: Int
    var totalCost: Double
    var efficiency: Double  // 0.0-1.0
    var specialization: AgentSpecialization
}
```

Computed properties: `successRate`, `successRatePercentage`, `efficiencyPercentage`, `costPerTask`, `formattedCostPerTask`

**AgentSpecialization** — `general`, `codeGeneration`, `codeReview`, `testing`, `debugging`, `documentation`, `architecture`

Properties: `displayName`, `iconName`, `colorHex`

#### TeamRadarData

```swift
struct TeamRadarData: Identifiable, Codable, Hashable {
    let id: String
    var teamName: String
    var dimensions: [RadarDimension]
    var generatedAt: Date
}
```

Computed properties: `averageScore`

#### RadarDimension

```swift
struct RadarDimension: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var value: Double  // 0.0-1.0
    var category: PerformanceDimension
}
```

**PerformanceDimension** — `speed`, `quality`, `costEfficiency`, `reliability`, `collaboration`, `throughput`

Properties: `displayName`, `iconName`

#### TeamLeaderboard

```swift
struct TeamLeaderboard: Identifiable, Codable, Hashable {
    let id: String
    var metric: LeaderboardMetric
    var entries: [LeaderboardEntry]
    var generatedAt: Date
}
```

Auto-sorts entries by score on init.

**LeaderboardMetric** — `tasksCompleted`, `successRate`, `costEfficiency`, `speed`, `tokensUsed`

Properties: `displayName`, `unit`

#### LeaderboardEntry

```swift
struct LeaderboardEntry: Identifiable, Codable, Hashable {
    let id: String
    var agentName: String
    var score: Double
    var rank: Int
    var trend: TrendDirection
}
```

Computed properties: `formattedScore`

---

### TeamPerformanceManager

**File:** `AgentCommand/Services/TeamPerformanceManager.swift`

Team performance tracking and analysis. `@MainActor ObservableObject`.

#### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `snapshots` | `[TeamPerformanceSnapshot]` | Performance snapshots |
| `radarData` | `[TeamRadarData]` | Radar chart data |
| `leaderboards` | `[TeamLeaderboard]` | Leaderboard rankings |
| `isAnalyzing` | `Bool` | Analysis in progress |

#### Computed Properties

| Property | Type | Description |
|----------|------|-------------|
| `latestSnapshot` | `TeamPerformanceSnapshot?` | Most recent snapshot |

#### Methods

```swift
// Snapshot capture
func captureSnapshot(teamName: String, members: [AgentPerformanceMetric]) -> TeamPerformanceSnapshot

// Radar data generation
func generateRadarData(from snapshot: TeamPerformanceSnapshot) -> TeamRadarData

// Leaderboard generation
func generateLeaderboard(metric: LeaderboardMetric, from snapshot: TeamPerformanceSnapshot) -> TeamLeaderboard

// Data
func loadSampleData()
```

#### Memory Limits

| Resource | Max Count |
|----------|-----------|
| Snapshots | 50 |
| Radar Data | 20 |
| Leaderboards | 30 |

---

## AppState Integration

**File:** `AgentCommand/App/AppState.swift`

The M-series features are integrated into the global app state:

### Properties

```swift
// M1: Analytics Dashboard
@Published var isAnalyticsDashboardStatusVisible: Bool = false
@Published var isAnalyticsDashboardViewVisible: Bool = false
let analyticsDashboardManager = AnalyticsDashboardManager()

// M2: Report Export
@Published var isReportExportStatusVisible: Bool = false
@Published var isReportExportViewVisible: Bool = false
let reportExportManager = ReportExportManager()

// M3: API Usage Analytics
@Published var isAPIUsageAnalyticsStatusVisible: Bool = false
@Published var isAPIUsageAnalyticsViewVisible: Bool = false
let apiUsageAnalyticsManager = APIUsageAnalyticsManager()

// M4: Session History Analytics
@Published var isSessionHistoryAnalyticsStatusVisible: Bool = false
@Published var isSessionHistoryAnalyticsViewVisible: Bool = false
let sessionHistoryAnalyticsManager = SessionHistoryAnalyticsManager()

// M5: Team Performance
@Published var isTeamPerformanceStatusVisible: Bool = false
@Published var isTeamPerformanceViewVisible: Bool = false
let teamPerformanceManager = TeamPerformanceManager()
```

### Toggle Methods

```swift
func toggleAnalyticsDashboardStatus()          // Toggles M1 overlay visibility
func toggleReportExportStatus()                // Toggles M2 overlay visibility
func toggleAPIUsageAnalyticsStatus()           // Toggles M3 overlay visibility
func toggleSessionHistoryAnalyticsStatus()     // Toggles M4 overlay visibility
func toggleTeamPerformanceStatus()             // Toggles M5 overlay visibility
```

Each toggle method flips the corresponding `is*StatusVisible` boolean. The overlay views observe these properties to show/hide themselves in the scene.
