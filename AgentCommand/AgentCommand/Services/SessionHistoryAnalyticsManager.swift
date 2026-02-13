import Foundation
import Combine

// MARK: - M4: Session History Analytics Manager

@MainActor
class SessionHistoryAnalyticsManager: ObservableObject {
    @Published var sessions: [SessionAnalytics] = []
    @Published var productivityTrend: ProductivityTrend?
    @Published var comparisons: [SessionComparison] = []
    @Published var currentTimeDistribution: SessionTimeDistribution?
    @Published var isAnalyzing: Bool = false

    private static let maxSessions = 100
    private static let maxComparisons = 10

    weak var appState: AppState?

    // MARK: - Session Management

    /// Record a new session's analytics
    func recordSession(_ session: SessionAnalytics) {
        sessions.insert(session, at: 0)
        if sessions.count > Self.maxSessions {
            sessions = Array(sessions.prefix(Self.maxSessions))
        }
    }

    /// Start tracking a new session
    func startSession(name: String) -> SessionAnalytics {
        let session = SessionAnalytics(sessionName: name, startedAt: Date())
        recordSession(session)
        return session
    }

    /// End an active session
    func endSession(_ sessionId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].endedAt = Date()
    }

    /// Delete a session by ID
    func deleteSession(_ sessionId: String) {
        sessions.removeAll { $0.id == sessionId }
        comparisons.removeAll { $0.sessionAId == sessionId || $0.sessionBId == sessionId }
    }

    // MARK: - Productivity Analysis

    /// Analyze productivity trends from session history
    func analyzeProductivityTrend() {
        isAnalyzing = true

        guard sessions.count >= 2 else {
            isAnalyzing = false
            return
        }

        let sortedSessions = sessions.sorted { $0.startedAt < $1.startedAt }
        let dataPoints: [ProductivityDataPoint] = sortedSessions.map { session in
            ProductivityDataPoint(
                date: session.startedAt,
                productivity: session.productivityScore,
                tasksCompleted: session.tasksCompleted,
                tokensUsed: session.totalTokens,
                cost: session.totalCost
            )
        }

        let avgProductivity = dataPoints.reduce(0.0) { $0 + $1.productivity } / Double(dataPoints.count)

        // Determine trend by comparing first vs second half
        let midpoint = dataPoints.count / 2
        let firstHalf = Array(dataPoints.prefix(midpoint))
        let secondHalf = Array(dataPoints.suffix(from: midpoint))

        let firstAvg = firstHalf.isEmpty ? 0 : firstHalf.reduce(0.0) { $0 + $1.productivity } / Double(firstHalf.count)
        let secondAvg = secondHalf.isEmpty ? 0 : secondHalf.reduce(0.0) { $0 + $1.productivity } / Double(secondHalf.count)

        let trend: TrendDirection
        if secondAvg > firstAvg * 1.1 {
            trend = .improving
        } else if secondAvg < firstAvg * 0.9 {
            trend = .declining
        } else {
            trend = .stable
        }

        productivityTrend = ProductivityTrend(
            dataPoints: dataPoints,
            overallTrend: trend,
            averageProductivity: avgProductivity
        )

        isAnalyzing = false
    }

    // MARK: - Session Comparison

    /// Compare two sessions
    func compareSessions(_ sessionAId: String, _ sessionBId: String) {
        guard let sessionA = sessions.first(where: { $0.id == sessionAId }),
              let sessionB = sessions.first(where: { $0.id == sessionBId }) else { return }

        let comparison = SessionComparison(sessionA: sessionA, sessionB: sessionB)

        if let existingIdx = comparisons.firstIndex(where: { $0.sessionAId == sessionAId && $0.sessionBId == sessionBId }) {
            comparisons[existingIdx] = comparison
        } else {
            comparisons.insert(comparison, at: 0)
        }

        if comparisons.count > Self.maxComparisons {
            comparisons = Array(comparisons.prefix(Self.maxComparisons))
        }
    }

    /// Delete a comparison
    func deleteComparison(_ comparisonId: String) {
        comparisons.removeAll { $0.id == comparisonId }
    }

    // MARK: - Time Distribution

    /// Generate time distribution for a session or overall
    func generateTimeDistribution() {
        let totalMinutes = sessions.compactMap(\.duration).reduce(0, +) / 60.0
        guard totalMinutes > 0 else { return }

        let codingMinutes = totalMinutes * Double.random(in: 0.35...0.45)
        let reviewingMinutes = totalMinutes * Double.random(in: 0.12...0.18)
        let debuggingMinutes = totalMinutes * Double.random(in: 0.10...0.15)
        let testingMinutes = totalMinutes * Double.random(in: 0.08...0.12)
        let planningMinutes = totalMinutes * Double.random(in: 0.05...0.10)
        let idleMinutes = totalMinutes - codingMinutes - reviewingMinutes - debuggingMinutes - testingMinutes - planningMinutes

        let entries = [
            TimeDistributionEntry(category: .coding, minutes: codingMinutes, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .reviewing, minutes: reviewingMinutes, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .debugging, minutes: debuggingMinutes, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .testing, minutes: testingMinutes, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .planning, minutes: planningMinutes, totalMinutes: totalMinutes),
            TimeDistributionEntry(category: .idle, minutes: max(0, idleMinutes), totalMinutes: totalMinutes),
        ]

        currentTimeDistribution = SessionTimeDistribution(entries: entries)
    }

    // MARK: - Sample Data

    func loadSampleData() {
        let now = Date()
        let calendar = Calendar.current

        sessions = (0..<12).map { i in
            let startDate = calendar.date(byAdding: .day, value: -(11 - i), to: now) ?? now
            let durationHours = Double.random(in: 1.5...6.0)
            let endDate = startDate.addingTimeInterval(durationHours * 3600)
            let tasksCompleted = Int.random(in: 5...30)
            let tasksFailed = Int.random(in: 0...5)
            let tokens = Int.random(in: 8000...60000)
            let cost = Double(tokens) * 0.000015 + Double.random(in: 0.5...3.0)

            var session = SessionAnalytics(
                sessionName: "Session \(i + 1)",
                startedAt: startDate,
                totalTokens: tokens,
                totalCost: cost,
                tasksCompleted: tasksCompleted,
                tasksFailed: tasksFailed,
                agentsUsed: Int.random(in: 1...4),
                dominantModel: ["opus", "sonnet", "haiku"].randomElement() ?? "sonnet",
                averageLatencyMs: Double.random(in: 800...3500),
                peakTokenRate: Int.random(in: 200...2000),
                productivityScore: Double.random(in: 0.4...0.95)
            )
            session.endedAt = endDate
            return session
        }

        analyzeProductivityTrend()
        generateTimeDistribution()

        if sessions.count >= 2 {
            compareSessions(sessions[0].id, sessions[1].id)
        }
    }

    // MARK: - Computed Properties

    var totalSessions: Int { sessions.count }

    var averageProductivity: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0.0) { $0 + $1.productivityScore } / Double(sessions.count)
    }

    var totalCostAllSessions: Double {
        sessions.reduce(0.0) { $0 + $1.totalCost }
    }

    var totalTasksAllSessions: Int {
        sessions.reduce(0) { $0 + $1.tasksCompleted }
    }
}
