import Foundation

/// Manages adaptive cleanup of idle, completed, and failed agents.
/// Replaces the fixed 8-second disband delay with a multi-tier strategy
/// that accounts for resource pressure.
@MainActor
class AgentCleanupManager: ObservableObject {

    // MARK: - Published State

    @Published var policy: CleanupPolicy = .default
    @Published private(set) var resourcePressure: ResourcePressure = .normal

    // MARK: - Internal Tracking

    private(set) var cleanupTimers: [UUID: DispatchWorkItem] = [:]
    private(set) var idleTracking: [UUID: Date] = [:]
    private var monitorTimer: Timer?

    // MARK: - Dependencies

    weak var lifecycleManager: AgentLifecycleManager?
    private let logger: LifecycleLogger?

    // MARK: - Activity monitoring
    private(set) var lastActivityTimes: [UUID: Date] = [:]
    private(set) var agentResourceUsage: [UUID: AgentResourceSnapshot] = [:]

    struct AgentResourceSnapshot {
        let timestamp: Date
        let cpuPercent: Double
        let memoryMB: Int
    }

    // MARK: - Init

    init(logger: LifecycleLogger? = nil) {
        self.logger = logger
    }

    // MARK: - Resource Monitoring

    func startMonitoring() {
        guard policy.enableResourceMonitoring else { return }
        stopMonitoring()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor in self?.evaluateResourcePressure() }
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func evaluateResourcePressure() {
        let memoryMB = currentMemoryUsageMB()
        let agentCount = lifecycleManager?.activeAgentCount ?? 0
        let processCount = lifecycleManager?.runningProcessCount ?? 0

        let newPressure: ResourcePressure
        if memoryMB > policy.memoryCriticalThresholdMB {
            newPressure = .critical
        } else if agentCount > policy.maxConcurrentAgents ||
                  processCount > policy.maxConcurrentProcesses ||
                  memoryMB > policy.memoryWarningThresholdMB {
            newPressure = .high
        } else if agentCount > policy.maxConcurrentAgents / 2 {
            newPressure = .elevated
        } else {
            newPressure = .normal
        }

        if newPressure != resourcePressure {
            logger?.logResourcePressureChange(from: resourcePressure, to: newPressure)
            resourcePressure = newPressure
            applyPressurePolicy(newPressure)
        }
    }

    private func applyPressurePolicy(_ pressure: ResourcePressure) {
        switch pressure {
        case .normal:
            break
        case .elevated:
            rescheduleAllTimers(multiplier: 0.5)
        case .high:
            rescheduleAllTimers(multiplier: 0.25)
            lifecycleManager?.evictOldestPooledAgents(count: 4)
        case .critical:
            lifecycleManager?.emergencyCleanup()
        }
    }

    // MARK: - Idle Tracking

    func agentBecameIdle(_ agentId: UUID) {
        let now = Date()
        idleTracking[agentId] = now
        lastActivityTimes[agentId] = now
        scheduleIdleCheck(agentId)
    }

    func agentBecameActive(_ agentId: UUID) {
        idleTracking.removeValue(forKey: agentId)
        lastActivityTimes[agentId] = Date()
        cancelTimer(for: agentId)
    }

    func recordActivity(for agentId: UUID) {
        lastActivityTimes[agentId] = Date()
    }

    func recordResourceUsage(for agentId: UUID, cpuPercent: Double, memoryMB: Int) {
        agentResourceUsage[agentId] = AgentResourceSnapshot(
            timestamp: Date(),
            cpuPercent: cpuPercent,
            memoryMB: memoryMB
        )
    }

    func idleDuration(for agentId: UUID) -> TimeInterval {
        guard let idleSince = idleTracking[agentId] else { return 0 }
        return Date().timeIntervalSince(idleSince)
    }

    func timeSinceLastActivity(for agentId: UUID) -> TimeInterval {
        guard let lastActivity = lastActivityTimes[agentId] else { return 0 }
        return Date().timeIntervalSince(lastActivity)
    }

    private func scheduleIdleCheck(_ agentId: UUID) {
        cancelTimer(for: agentId)
        let timeout = adjustedTimeout(policy.idleAgentTimeout)
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.lifecycleManager?.fireEvent(.idleTimeout, forAgent: agentId)
            }
        }
        cleanupTimers[agentId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }

    // MARK: - Team Cleanup Scheduling

    func scheduleTeamCleanup(commanderId: UUID, allCompleted: Bool) {
        cancelTimer(for: commanderId)
        let delay = allCompleted
            ? adjustedTimeout(policy.completedTeamDelay)
            : adjustedTimeout(policy.failedTeamDelay)

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.lifecycleManager?.initiateTeamDisband(commanderId: commanderId)
            }
        }
        cleanupTimers[commanderId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func cancelTeamCleanup(commanderId: UUID) {
        cancelTimer(for: commanderId)
    }

    // MARK: - Suspended Agent Timeout

    func scheduleSuspendedTimeout(_ agentId: UUID) {
        cancelTimer(for: agentId)
        let timeout = adjustedTimeout(policy.suspendedIdleTimeout)
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.lifecycleManager?.fireEvent(.timeout, forAgent: agentId)
            }
        }
        cleanupTimers[agentId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }

    // MARK: - Timer Management

    func cancelTimer(for id: UUID) {
        cleanupTimers[id]?.cancel()
        cleanupTimers.removeValue(forKey: id)
    }

    func cancelAllTimers() {
        for item in cleanupTimers.values { item.cancel() }
        cleanupTimers.removeAll()
    }

    private func rescheduleAllTimers(multiplier: Double) {
        // Existing timers are DispatchWorkItems already enqueued;
        // we cannot reschedule them directly. Instead, this multiplier
        // affects future timer calculations through adjustedTimeout.
        // For active pressure changes, we rely on the next timer
        // scheduling to pick up the new pressure level.
    }

    // MARK: - Timeout Adjustment

    func adjustedTimeout(_ base: TimeInterval) -> TimeInterval {
        switch resourcePressure {
        case .normal: return base
        case .elevated: return base * 0.5
        case .high: return base * 0.25
        case .critical: return max(base * 0.1, 1.0)
        }
    }

    // MARK: - Memory Query

    func currentMemoryUsageMB() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size / 1_048_576) : 0
    }

    // MARK: - Cleanup Agent Tracking

    func removeAgent(_ agentId: UUID) {
        cancelTimer(for: agentId)
        idleTracking.removeValue(forKey: agentId)
        lastActivityTimes.removeValue(forKey: agentId)
        agentResourceUsage.removeValue(forKey: agentId)
    }

    // MARK: - Shutdown

    func shutdown() {
        stopMonitoring()
        cancelAllTimers()
        idleTracking.removeAll()
        lastActivityTimes.removeAll()
        agentResourceUsage.removeAll()
    }

    // MARK: - Stats

    var pendingCleanupCount: Int { cleanupTimers.count }
    var trackedIdleAgentCount: Int { idleTracking.count }
}
