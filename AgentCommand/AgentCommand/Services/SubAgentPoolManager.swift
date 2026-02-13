import Foundation
import Combine

// MARK: - SubAgent Pool Manager with Dynamic Sizing

/// Manages a reusable pool of sub-agents with dynamic sizing based on workload and resource pressure.
/// Eliminates idle sub-agents by recycling completed agents back into the pool and evicting
/// agents that exceed TTL or when pool capacity is reduced under pressure.
@MainActor
class SubAgentPoolManager: ObservableObject {

    // MARK: - Configuration

    struct PoolConfig: Codable, Equatable {
        var maxPoolSize: Int = 12
        var maxPerRole: Int = 3
        var ttlSeconds: TimeInterval = 600
        var minPoolSize: Int = 0
        var shrinkCooldownSeconds: TimeInterval = 30.0
        var growthFactor: Double = 1.5
        var shrinkThreshold: Double = 0.25

        static let `default` = PoolConfig()

        static let compact = PoolConfig(
            maxPoolSize: 6,
            maxPerRole: 2,
            ttlSeconds: 120,
            shrinkCooldownSeconds: 15.0
        )
    }

    // MARK: - Pool Entry

    struct PoolEntry: Identifiable {
        let id: UUID
        var agent: Agent
        let pooledAt: Date
        var lastUsedAt: Date
        var useCount: Int

        var age: TimeInterval {
            Date().timeIntervalSince(pooledAt)
        }

        var idleDuration: TimeInterval {
            Date().timeIntervalSince(lastUsedAt)
        }
    }

    // MARK: - Published State

    @Published var config: PoolConfig = .default
    @Published private(set) var pool: [AgentRole: [PoolEntry]] = [:]
    @Published private(set) var stats: PoolStats = PoolStats()

    // MARK: - Dependencies

    weak var lifecycleManager: AgentLifecycleManager?

    // MARK: - Private State

    private var evictionTimers: [UUID: DispatchWorkItem] = [:]
    private var lastShrinkTime: Date = .distantPast
    private var demandHistory: [Date] = []

    // MARK: - Pool Stats

    struct PoolStats: Equatable {
        var totalPooled: Int = 0
        var hitCount: Int = 0
        var missCount: Int = 0
        var evictionCount: Int = 0
        var totalAcquired: Int = 0
        var totalReleased: Int = 0
        var currentCapacity: Int = 12
        var peakSize: Int = 0
        var perRoleCounts: [String: Int] = [:]

        var hitRate: Double {
            let total = hitCount + missCount
            guard total > 0 else { return 0 }
            return Double(hitCount) / Double(total)
        }

        var utilizationRate: Double {
            guard currentCapacity > 0 else { return 0 }
            return Double(totalPooled) / Double(currentCapacity)
        }
    }

    // MARK: - Acquire

    /// Acquire an agent from the pool, or return nil if no matching agent is available.
    /// The caller should create a new agent if nil is returned.
    func acquire(role: AgentRole, parentId: UUID?, model: ClaudeModel) -> Agent? {
        recordDemand()

        guard var entries = pool[role], !entries.isEmpty else {
            stats.missCount += 1
            stats.totalAcquired += 1
            return nil
        }

        // Pick the most recently used agent (warm cache)
        entries.sort { $0.lastUsedAt > $1.lastUsedAt }
        var entry = entries.removeFirst()
        pool[role] = entries.isEmpty ? nil : entries

        // Cancel eviction timer
        cancelEvictionTimer(for: entry.id)

        // Reconfigure the agent for the new task
        entry.agent.parentAgentId = parentId
        entry.agent.selectedModel = model
        entry.agent.status = .idle
        entry.agent.assignedTaskIds = []
        entry.agent.subAgentIds = []

        stats.hitCount += 1
        stats.totalAcquired += 1
        updatePoolStats()

        // Transition lifecycle state
        lifecycleManager?.fireEvent(.assignNewTask, forAgent: entry.agent.id)

        return entry.agent
    }

    /// Acquire or create: tries pool first, falls back to factory
    func acquireOrCreate(role: AgentRole, parentId: UUID?, model: ClaudeModel) -> Agent {
        if let pooled = acquire(role: role, parentId: parentId, model: model) {
            return pooled
        }
        return AgentFactory.createSubAgent(parentId: parentId ?? UUID(), role: role, model: model)
    }

    // MARK: - Release

    /// Release a completed agent back to the pool. Returns false if pool is full.
    @discardableResult
    func release(_ agent: Agent) -> Bool {
        let role = agent.role

        // Check capacity
        let currentCount = pool[role]?.count ?? 0
        let totalCount = totalPooledCount
        guard totalCount < config.maxPoolSize,
              currentCount < config.maxPerRole else {
            stats.evictionCount += 1
            return false
        }

        let entry = PoolEntry(
            id: agent.id,
            agent: agent,
            pooledAt: Date(),
            lastUsedAt: Date(),
            useCount: 1
        )

        pool[role, default: []].append(entry)
        scheduleEviction(for: agent.id, role: role)

        stats.totalReleased += 1
        updatePoolStats()

        // Transition to pooled state
        lifecycleManager?.fireEvent(.returnToPool, forAgent: agent.id)

        return true
    }

    // MARK: - Dynamic Sizing

    /// Evaluate current demand and adjust pool capacity accordingly
    func evaluateAndResize(resourcePressure: ResourcePressure) {
        let recentDemand = recentDemandRate()

        switch resourcePressure {
        case .critical:
            shrinkPool(to: config.minPoolSize)
        case .high:
            let target = max(config.minPoolSize, config.maxPoolSize / 2)
            shrinkPool(to: target)
        case .elevated:
            if recentDemand < config.shrinkThreshold {
                let target = max(config.minPoolSize, totalPooledCount - 2)
                shrinkPool(to: target)
            }
        case .normal:
            if recentDemand > 0.75 {
                let target = min(config.maxPoolSize, Int(Double(totalPooledCount + 2) * config.growthFactor))
                config.maxPoolSize = max(config.maxPoolSize, target)
            }
        }

        stats.currentCapacity = config.maxPoolSize
    }

    /// Force shrink pool to a target size by evicting oldest entries
    func shrinkPool(to targetSize: Int) {
        let now = Date()
        guard now.timeIntervalSince(lastShrinkTime) > config.shrinkCooldownSeconds else { return }
        lastShrinkTime = now

        var evicted: [UUID] = []

        while totalPooledCount > targetSize {
            // Find the oldest entry across all roles
            var oldestRole: AgentRole?
            var oldestAge: TimeInterval = -1

            for (role, entries) in pool {
                if let oldest = entries.min(by: { $0.pooledAt < $1.pooledAt }) {
                    let age = oldest.age
                    if age > oldestAge {
                        oldestAge = age
                        oldestRole = role
                    }
                }
            }

            guard let role = oldestRole, var entries = pool[role], !entries.isEmpty else { break }

            let removed = entries.removeFirst()
            pool[role] = entries.isEmpty ? nil : entries
            cancelEvictionTimer(for: removed.id)
            evicted.append(removed.id)
            stats.evictionCount += 1
        }

        // Trigger destruction for evicted agents
        for agentId in evicted {
            lifecycleManager?.fireEvent(.poolEviction, forAgent: agentId)
        }

        updatePoolStats()
    }

    // MARK: - Eviction Timers

    private func scheduleEviction(for agentId: UUID, role: AgentRole) {
        cancelEvictionTimer(for: agentId)

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.evict(agentId: agentId, role: role)
            }
        }
        evictionTimers[agentId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + config.ttlSeconds, execute: workItem)
    }

    private func evict(agentId: UUID, role: AgentRole) {
        guard var entries = pool[role] else { return }
        entries.removeAll { $0.id == agentId }
        pool[role] = entries.isEmpty ? nil : entries
        evictionTimers.removeValue(forKey: agentId)
        stats.evictionCount += 1
        updatePoolStats()

        lifecycleManager?.fireEvent(.poolEviction, forAgent: agentId)
    }

    private func cancelEvictionTimer(for agentId: UUID) {
        evictionTimers[agentId]?.cancel()
        evictionTimers.removeValue(forKey: agentId)
    }

    // MARK: - Demand Tracking

    private func recordDemand() {
        demandHistory.append(Date())
        // Keep only last 60 seconds of demand records
        let cutoff = Date().addingTimeInterval(-60)
        demandHistory.removeAll { $0 < cutoff }
    }

    /// Returns demand rate as requests per second over the last 60 seconds, normalized to 0-1
    private func recentDemandRate() -> Double {
        let cutoff = Date().addingTimeInterval(-60)
        let recentCount = demandHistory.filter { $0 > cutoff }.count
        // Normalize: 0 requests = 0.0, 12+ requests in 60s = 1.0
        return min(1.0, Double(recentCount) / 12.0)
    }

    // MARK: - Queries

    var totalPooledCount: Int {
        pool.values.reduce(0) { $0 + $1.count }
    }

    func pooledCount(for role: AgentRole) -> Int {
        pool[role]?.count ?? 0
    }

    func hasAvailable(role: AgentRole) -> Bool {
        (pool[role]?.count ?? 0) > 0
    }

    // MARK: - Cleanup

    func removeAll() {
        for timer in evictionTimers.values { timer.cancel() }
        evictionTimers.removeAll()
        pool.removeAll()
        updatePoolStats()
    }

    func shutdown() {
        removeAll()
        demandHistory.removeAll()
    }

    // MARK: - Private Helpers

    private func updatePoolStats() {
        let total = totalPooledCount
        stats.totalPooled = total
        stats.peakSize = max(stats.peakSize, total)
        stats.perRoleCounts = Dictionary(
            pool.map { ($0.key.rawValue, $0.value.count) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
