import XCTest
@testable import AgentCommand

// MARK: - Memory Benchmark Tests
// Measures memory consumption with and without optimization caps

@MainActor
final class MemoryBenchmarkTests: XCTestCase {

    // MARK: - Helpers

    /// Returns current process memory in bytes (resident size)
    private func currentMemoryBytes() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    private func memoryMB(_ bytes: Int64) -> Double {
        Double(bytes) / (1024 * 1024)
    }

    /// Write to stderr so output is visible in swift test
    private func log(_ message: String) {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
    }

    // MARK: - PerformanceMetricsManager Benchmark

    func testPerformanceMetricsManager_MemoryWithOptimization() async throws {
        let manager = PerformanceMetricsManager()
        let taskCount = 1000

        let memBefore = currentMemoryBytes()

        for i in 0..<taskCount {
            let taskId = UUID()
            let agentId = UUID()
            manager.taskStarted(taskId: taskId, agentId: agentId, prompt: "Test prompt \(i) with some realistic length content for benchmarking memory usage patterns")
            manager.recordToolCall(taskId: taskId, tool: "read_file")
            manager.recordToolCall(taskId: taskId, tool: "edit_file")
            manager.recordAssistantText(taskId: taskId, textLength: 500)
            manager.taskCompleted(taskId: taskId, costUSD: 0.05, durationMs: 3000)
        }

        let memAfter = currentMemoryBytes()
        let memUsed = memAfter - memBefore

        log("=== PerformanceMetricsManager — Optimized (cap=100) ===")
        log("  Tasks processed:  \(taskCount)")
        log("  Retained metrics: \(manager.taskMetrics.count)")
        log("  Memory delta:     \(String(format: "%.2f", memoryMB(memUsed))) MB")

        XCTAssertLessThanOrEqual(manager.taskMetrics.count, 100,
            "taskMetrics should be capped at 100 after eviction")
    }

    func testPerformanceMetricsManager_MemoryWithoutOptimization_Simulated() async throws {
        let taskCount = 1000
        var unboundedMetrics: [UUID: TaskMetrics] = [:]

        let memBefore = currentMemoryBytes()

        for i in 0..<taskCount {
            let taskId = UUID()
            let agentId = UUID()
            var metrics = TaskMetrics(taskId: taskId, agentId: agentId,
                prompt: "Test prompt \(i) with some realistic length content for benchmarking memory usage patterns")
            metrics.startTime = Date()
            metrics.toolCallCount = 2
            metrics.toolUsage = ["read_file": 1, "edit_file": 1]
            metrics.estimatedTokens = 1125
            metrics.endTime = Date()
            metrics.status = .completed
            metrics.costUSD = 0.05
            metrics.durationMs = 3000
            unboundedMetrics[taskId] = metrics
        }

        let memAfter = currentMemoryBytes()
        let memUsed = memAfter - memBefore

        log("=== PerformanceMetricsManager — Unoptimized (no cap) ===")
        log("  Tasks processed:  \(taskCount)")
        log("  Retained metrics: \(unboundedMetrics.count)")
        log("  Memory delta:     \(String(format: "%.2f", memoryMB(memUsed))) MB")

        XCTAssertEqual(unboundedMetrics.count, taskCount)
    }

    // MARK: - AnomalyDetectionManager Benchmark

    func testAnomalyDetectionManager_MemoryWithOptimization() async throws {
        let manager = AnomalyDetectionManager()
        let alertCount = 500
        let retryCount = 50

        let memBefore = currentMemoryBytes()

        for i in 0..<alertCount {
            manager.reportAnomaly(
                type: AnomalyType.allCases[i % AnomalyType.allCases.count],
                severity: AnomalySeverity.allCases[i % AnomalySeverity.allCases.count],
                message: "Anomaly #\(i): Test anomaly message with realistic content for benchmarking",
                agentName: "Agent-\(i % 10)",
                taskName: "Task-\(i)",
                metrics: ["duration_min": Double(i), "threshold": 10.0]
            )
            if i % 3 == 0, let alertId = manager.alerts.last?.id {
                manager.resolveAlert(alertId)
            }
        }

        for _ in 0..<retryCount {
            manager.configureRetry(
                strategy: RetryStrategy.allCases.randomElement()!,
                maxRetries: Int.random(in: 1...5),
                delaySeconds: Double.random(in: 1...30)
            )
        }

        let memAfter = currentMemoryBytes()
        let memUsed = memAfter - memBefore

        log("=== AnomalyDetectionManager — Optimized (caps) ===")
        log("  Alerts generated:  \(alertCount) | Retained: \(manager.alerts.count) (cap=200)")
        log("  Error patterns:    \(manager.errorPatterns.count) (cap=50)")
        log("  Retry configs:     \(manager.retryConfigs.count) (cap=20)")
        log("  Memory delta:      \(String(format: "%.2f", memoryMB(memUsed))) MB")

        XCTAssertLessThanOrEqual(manager.alerts.count, 200, "alerts should be capped at 200")
        XCTAssertLessThanOrEqual(manager.errorPatterns.count, 50, "errorPatterns should be capped at 50")
        XCTAssertLessThanOrEqual(manager.retryConfigs.count, 20, "retryConfigs should be capped at 20")
    }

    func testAnomalyDetectionManager_MemoryWithoutOptimization_Simulated() async throws {
        let alertCount = 500
        let patternCount = 100
        var unboundedAlerts: [AnomalyAlert] = []
        var unboundedPatterns: [ErrorPattern] = []
        var unboundedRetryConfigs: [RetryConfig] = []

        let memBefore = currentMemoryBytes()

        for i in 0..<alertCount {
            unboundedAlerts.append(AnomalyAlert(
                id: UUID(),
                type: AnomalyType.allCases[i % AnomalyType.allCases.count],
                severity: AnomalySeverity.allCases[i % AnomalySeverity.allCases.count],
                message: "Anomaly #\(i): Test anomaly message with realistic content for benchmarking",
                agentName: "Agent-\(i % 10)",
                taskName: "Task-\(i)",
                detectedAt: Date(),
                isResolved: i % 3 == 0,
                metrics: ["duration_min": Double(i), "threshold": 10.0]
            ))
        }

        for i in 0..<patternCount {
            unboundedPatterns.append(ErrorPattern(
                id: UUID(),
                pattern: "Pattern #\(i): test error pattern description",
                occurrenceCount: Int.random(in: 1...20),
                firstSeen: Date(),
                lastSeen: Date(),
                category: AnomalyType.allCases[i % AnomalyType.allCases.count]
            ))
        }

        for _ in 0..<50 {
            unboundedRetryConfigs.append(RetryConfig(
                id: UUID(),
                strategy: RetryStrategy.allCases.randomElement()!,
                maxRetries: Int.random(in: 1...5),
                delaySeconds: Double.random(in: 1...30),
                appliedCount: 0,
                isActive: Bool.random()
            ))
        }

        let memAfter = currentMemoryBytes()
        let memUsed = memAfter - memBefore

        log("=== AnomalyDetectionManager — Unoptimized (no caps) ===")
        log("  Alerts:        \(unboundedAlerts.count) (unbounded)")
        log("  Patterns:      \(unboundedPatterns.count) (unbounded)")
        log("  Retry configs: \(unboundedRetryConfigs.count) (unbounded)")
        log("  Memory delta:  \(String(format: "%.2f", memoryMB(memUsed))) MB")

        XCTAssertEqual(unboundedAlerts.count, alertCount)
        XCTAssertEqual(unboundedPatterns.count, patternCount)
    }

    // MARK: - Combined Scale Test

    func testCombined_LongRunningSession_MemoryStability() async throws {
        let manager = PerformanceMetricsManager()
        let anomalyManager = AnomalyDetectionManager()
        let iterations = 2000

        let memStart = currentMemoryBytes()

        for i in 0..<iterations {
            let taskId = UUID()
            let agentId = UUID()
            manager.taskStarted(taskId: taskId, agentId: agentId, prompt: "Long session task \(i)")
            manager.recordToolCall(taskId: taskId, tool: "bash")
            manager.recordToolCall(taskId: taskId, tool: "read_file")
            manager.recordToolCall(taskId: taskId, tool: "write_file")
            manager.recordAssistantText(taskId: taskId, textLength: 1000)
            if i % 5 == 0 {
                manager.taskFailed(taskId: taskId)
            } else {
                manager.taskCompleted(taskId: taskId, costUSD: 0.03, durationMs: 2000)
            }

            if i % 10 == 0 {
                anomalyManager.reportAnomaly(
                    type: AnomalyType.allCases[i % AnomalyType.allCases.count],
                    severity: .warning,
                    message: "Session anomaly iteration \(i) with context",
                    agentName: "Agent-\(i % 5)",
                    taskName: "Task-\(i)"
                )
            }
            if i % 30 == 0 {
                anomalyManager.configureRetry(
                    strategy: .exponentialBackoff,
                    maxRetries: 3,
                    delaySeconds: 5
                )
            }
        }

        let memEnd = currentMemoryBytes()
        let memDelta = memEnd - memStart

        log("=== COMBINED 2000-iteration Session ===")
        log("  TaskMetrics retained:  \(manager.taskMetrics.count) (cap=100, without opt: \(iterations))")
        log("  Reduction:             \(String(format: "%.1f", (1.0 - Double(manager.taskMetrics.count) / Double(iterations)) * 100))%")
        log("  Alerts retained:       \(anomalyManager.alerts.count) (cap=200)")
        log("  Error patterns:        \(anomalyManager.errorPatterns.count) (cap=50)")
        log("  Retry configs:         \(anomalyManager.retryConfigs.count) (cap=20)")
        log("  Memory delta:          \(String(format: "%.2f", memoryMB(memDelta))) MB")

        XCTAssertLessThanOrEqual(manager.taskMetrics.count, 101)
        XCTAssertLessThanOrEqual(anomalyManager.alerts.count, 200)
        XCTAssertLessThanOrEqual(anomalyManager.errorPatterns.count, 50)
        XCTAssertLessThanOrEqual(anomalyManager.retryConfigs.count, 20)
    }

    // MARK: - Object Size Estimation

    func testObjectSizeEstimation() async throws {
        let taskMetricSize = MemoryLayout<TaskMetrics>.stride
        let alertSize = MemoryLayout<AnomalyAlert>.stride
        let patternSize = MemoryLayout<ErrorPattern>.stride
        let retryConfigSize = MemoryLayout<RetryConfig>.stride

        let savedTaskCount = 2000 - 100
        let savedTaskBytes = savedTaskCount * taskMetricSize

        log("=== Object Size Estimation ===")
        log("  TaskMetrics stride:   \(taskMetricSize) bytes")
        log("  AnomalyAlert stride:  \(alertSize) bytes")
        log("  ErrorPattern stride:  \(patternSize) bytes")
        log("  RetryConfig stride:   \(retryConfigSize) bytes")
        log("  Evicted TaskMetrics:  \(savedTaskCount) (~\(savedTaskBytes / 1024) KB struct-only)")
        log("  Note: Actual savings higher due to heap String/Dict allocations")

        XCTAssertGreaterThan(taskMetricSize, 0)
        XCTAssertGreaterThan(alertSize, 0)
    }
}
