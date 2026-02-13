# SubAgent Lifecycle Management System - Architecture Design Document

> Version: 2.0
> Date: 2026-02-14
> Status: Proposed
> Scope: AgentCommand 3D Agent UI

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current System Analysis](#2-current-system-analysis)
3. [Enhanced State Machine Design](#3-enhanced-state-machine-design)
4. [Idle Agent Auto-Cleanup Strategy](#4-idle-agent-auto-cleanup-strategy)
5. [Agent Pool Management](#5-agent-pool-management)
6. [Resume & Data Persistence](#6-resume--data-persistence)
7. [State Transition Diagrams](#7-state-transition-diagrams)
8. [Implementation Plan](#8-implementation-plan)
9. [API Reference](#9-api-reference)

---

## 1. Executive Summary

### 1.1 Problem Statement

The current AgentCommand system manages subagent lifecycles through a combination of `AgentStatus` enum, `CLIProcessManager`, `AppState` callbacks, and timer-based team disbanding. While functional, the system has several architectural gaps:

| Issue | Impact | Severity |
|-------|--------|----------|
| No explicit `suspended`/`paused` state | Agents waiting for user input have ambiguous lifecycle status | High |
| Fixed 8-second disband timer | No adaptive cleanup based on resource pressure | Medium |
| No agent pooling/reuse | Every task creates new agents from scratch, wasting 3D scene rebuilds | High |
| Scattered lifecycle logic | State transitions spread across AppState (1600+ lines), CLIProcessManager, and Orchestrator | High |
| Limited resume persistence | Only `sessionId` is stored; full agent context is lost on app restart | Medium |
| No resource monitoring | No awareness of memory/process count when spawning new agents | Medium |

### 1.2 Goals

1. **Unified State Machine**: A single, well-defined FSM governing all agent state transitions
2. **Adaptive Cleanup**: Resource-aware idle agent cleanup replacing the fixed 8-second timer
3. **Agent Pool**: Reusable agent instances reducing scene rebuild overhead
4. **Robust Persistence**: Full agent context serialization for resume across sessions
5. **Centralized Lifecycle Manager**: A dedicated `AgentLifecycleManager` service extracting lifecycle logic from AppState

---

## 2. Current System Analysis

### 2.1 Existing Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AppState                              │
│  (@MainActor, ObservableObject, ~1600 lines)                │
│                                                              │
│  ┌──────────┐  ┌───────────────────┐  ┌──────────────────┐  │
│  │ agents[] │  │ CLIProcessManager │  │ Orchestrator     │  │
│  │ tasks[]  │  │  processes: [:]   │  │ activeOrch: [:]  │  │
│  └──────────┘  └───────────────────┘  └──────────────────┘  │
│                                                              │
│  disbandTimers: [UUID: DispatchWorkItem]                     │
│  disbandingTeamIds: Set<UUID>                                │
│  disbandDelay: 8.0 seconds (fixed)                           │
│                                                              │
│  Key Methods:                                                │
│  - handleAgentStatusChange()  → updates agent + 3D scene     │
│  - scheduleDisbandIfNeeded()  → 8s timer → disbandTeam()     │
│  - disbandTeam()              → animation → removeTeamData() │
│  - removeTeamData()           → remove agents/tasks/scene    │
│  - submitPromptTask()         → create task + start CLI      │
│  - startCLIProcess()          → setup callbacks + launch     │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Current State Enum

```swift
// File: Models/AgentStatus.swift
enum AgentStatus: String, Codable, CaseIterable {
    case idle                  // Grey #888888
    case working               // Green #4CAF50
    case thinking              // Orange #FF9800
    case completed             // Blue #2196F3
    case error                 // Red #F44336
    case requestingPermission  // Orange #FF9800
    case waitingForAnswer      // Blue #2196F3
    case reviewingPlan         // Purple #9C27B0
}
```

### 2.3 Identified Gaps in Current States

| Gap | Description |
|-----|-------------|
| No `created` state | Agents jump directly to `idle` upon creation; no initialization phase |
| No `suspended` state | When CLI process pauses for user Q&A, agent shows `waitingForAnswer` but the process has actually terminated |
| No `resuming` state | Resume reuses `working` state; no distinction from fresh execution |
| No `destroying` state | Disband animation runs but agent data model has no "being destroyed" marker |
| No `pooled` state | No concept of agent reuse; completed agents are always destroyed |

### 2.4 Current Lifecycle Flow

```
AgentFactory.createTeam()
    → agents.append()
    → rebuildScene()
    → walkAgentToDesk() animation
    → submitPromptTask()
    → CLIProcess.start()
    → [working/thinking/requesting/waiting/reviewing]
    → onCompleted() or onFailed()
    → scheduleDisbandIfNeeded()
    → 8s delay
    → disbandTeam() animation
    → removeTeamData()
    → rebuildScene()
```

---

## 3. Enhanced State Machine Design

### 3.1 New Agent State Enum

```swift
/// Enhanced agent lifecycle states
/// File: Models/AgentLifecycleState.swift
enum AgentLifecycleState: String, Codable, CaseIterable {

    // === Creation Phase ===
    case initializing      // Agent created, loading resources

    // === Active Phase ===
    case idle              // Ready for task assignment
    case working           // Executing CLI process
    case thinking          // AI model is reasoning

    // === Interaction Phase ===
    case requestingPermission  // Dangerous command needs approval
    case waitingForAnswer      // AskUserQuestion pending
    case reviewingPlan         // Plan mode review pending

    // === Suspended Phase ===
    case suspended         // CLI process terminated; waiting for user resume
    case suspendedIdle     // Task completed/failed; agent awaiting reuse or cleanup

    // === Completion Phase ===
    case completed         // Task finished successfully
    case error             // Task failed with error

    // === Lifecycle Terminal Phase ===
    case pooled            // Returned to pool, available for reuse
    case destroying        // Disband animation in progress
    case destroyed         // Fully removed (terminal state)

    // === Metadata ===
    var isTerminal: Bool {
        self == .destroyed
    }

    var isActive: Bool {
        [.working, .thinking, .requestingPermission,
         .waitingForAnswer, .reviewingPlan].contains(self)
    }

    var isAvailableForTask: Bool {
        [.idle, .pooled, .suspendedIdle].contains(self)
    }

    var isCleanupCandidate: Bool {
        [.completed, .error, .suspendedIdle, .idle].contains(self)
    }
}
```

### 3.2 State Transition Table

| From State | Event | To State | Guard Condition |
|------------|-------|----------|-----------------|
| — | `create` | `initializing` | — |
| `initializing` | `resourcesLoaded` | `idle` | Scene position assigned |
| `idle` | `assignTask` | `working` | Task available |
| `idle` | `poolReturn` | `pooled` | Pool has capacity |
| `idle` | `idleTimeout` | `suspendedIdle` | Exceeds idle threshold |
| `working` | `aiReasoning` | `thinking` | — |
| `working` | `permissionNeeded` | `requestingPermission` | Dangerous command detected |
| `working` | `questionAsked` | `waitingForAnswer` | AskUserQuestion tool used |
| `working` | `planReady` | `reviewingPlan` | ExitPlanMode tool used |
| `working` | `taskCompleted` | `completed` | CLI exit code 0 |
| `working` | `taskFailed` | `error` | CLI exit code != 0 |
| `thinking` | `toolInvoked` | `working` | — |
| `thinking` | `taskCompleted` | `completed` | — |
| `requestingPermission` | `permissionGranted` | `working` | User approved |
| `requestingPermission` | `permissionDenied` | `suspended` | User denied |
| `requestingPermission` | `processTerminated` | `suspended` | CLI -p mode exits |
| `waitingForAnswer` | `answerReceived` | `working` | Resume with answer |
| `waitingForAnswer` | `processTerminated` | `suspended` | CLI -p mode exits |
| `reviewingPlan` | `planApproved` | `working` | Resume with approval |
| `reviewingPlan` | `planRejected` | `suspended` | User rejected plan |
| `reviewingPlan` | `processTerminated` | `suspended` | CLI -p mode exits |
| `suspended` | `resume` | `working` | Session ID available |
| `suspended` | `cancel` | `error` | User cancels |
| `suspended` | `timeout` | `suspendedIdle` | Exceeds suspend threshold |
| `suspendedIdle` | `assignTask` | `working` | New task assigned |
| `suspendedIdle` | `cleanupTriggered` | `destroying` | Cleanup policy |
| `completed` | `assignNewTask` | `working` | Agent reused |
| `completed` | `returnToPool` | `pooled` | Pool has capacity |
| `completed` | `disbandScheduled` | `destroying` | Team disband timer |
| `error` | `retry` | `working` | Retry policy allows |
| `error` | `disbandScheduled` | `destroying` | Team disband timer |
| `pooled` | `assignTask` | `initializing` | Task needs this role |
| `pooled` | `poolEviction` | `destroying` | Pool capacity exceeded |
| `destroying` | `animationComplete` | `destroyed` | 3D disband done |

### 3.3 State Machine Implementation

```swift
/// File: Services/AgentLifecycleStateMachine.swift
@MainActor
class AgentLifecycleStateMachine {

    typealias State = AgentLifecycleState

    struct Transition {
        let from: State
        let event: LifecycleEvent
        let to: State
        let guard_: ((AgentContext) -> Bool)?
        let action: ((AgentContext) -> Void)?
    }

    private var transitions: [Transition] = []
    private var onTransition: ((UUID, State, State, LifecycleEvent) -> Void)?

    func registerTransition(
        from: State,
        event: LifecycleEvent,
        to: State,
        guard_: ((AgentContext) -> Bool)? = nil,
        action: ((AgentContext) -> Void)? = nil
    ) {
        transitions.append(Transition(
            from: from, event: event, to: to,
            guard_: guard_, action: action
        ))
    }

    func fire(event: LifecycleEvent, context: AgentContext) -> State? {
        let current = context.currentState

        guard let transition = transitions.first(where: { t in
            t.from == current && t.event == event &&
            (t.guard_ == nil || t.guard_!(context))
        }) else {
            print("[FSM] Invalid transition: \(current) + \(event)")
            return nil
        }

        transition.action?(context)
        onTransition?(context.agentId, current, transition.to, event)
        return transition.to
    }
}

/// All possible lifecycle events
enum LifecycleEvent: String {
    case create
    case resourcesLoaded
    case assignTask
    case aiReasoning
    case toolInvoked
    case permissionNeeded
    case permissionGranted
    case permissionDenied
    case questionAsked
    case answerReceived
    case planReady
    case planApproved
    case planRejected
    case processTerminated
    case taskCompleted
    case taskFailed
    case resume
    case cancel
    case retry
    case timeout
    case idleTimeout
    case poolReturn
    case poolEviction
    case assignNewTask
    case returnToPool
    case disbandScheduled
    case cleanupTriggered
    case animationComplete
}

/// Context passed to guard/action closures
struct AgentContext {
    let agentId: UUID
    let currentState: AgentLifecycleState
    let agent: Agent
    let sessionId: String?
    let taskId: UUID?
    let poolCapacity: Int
    let currentPoolSize: Int
    let idleDuration: TimeInterval
}
```

---

## 4. Idle Agent Auto-Cleanup Strategy

### 4.1 Overview

Replace the fixed 8-second `disbandDelay` with a multi-tier adaptive cleanup system.

### 4.2 Cleanup Tiers

```
┌──────────────────────────────────────────────────────────┐
│                  Cleanup Policy Engine                     │
│                                                           │
│  Tier 1: Graceful Cleanup (default)                       │
│  ├── Completed teams: 15s delay → pool or destroy         │
│  ├── Failed teams: 10s delay → destroy                    │
│  └── Idle agents: 120s → suspendedIdle → pool candidate   │
│                                                           │
│  Tier 2: Pressure Cleanup (resource constrained)          │
│  ├── Agent count > maxAgents → evict oldest idle          │
│  ├── Process count > maxProcesses → suspend oldest        │
│  └── Memory > threshold → aggressive pool drain           │
│                                                           │
│  Tier 3: Emergency Cleanup (critical)                     │
│  ├── Memory > 80% → destroy all idle + pooled             │
│  └── Process hang > 300s → force terminate + error        │
│                                                           │
│  Tier 0: User Override                                    │
│  ├── Manual disband → immediate destroy                   │
│  └── Keep alive → cancel all timers for team              │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

### 4.3 Configuration

```swift
/// File: Models/CleanupPolicy.swift
struct CleanupPolicy: Codable {
    // Tier 1: Time-based thresholds
    var completedTeamDelay: TimeInterval = 15.0     // Seconds before cleanup
    var failedTeamDelay: TimeInterval = 10.0
    var idleAgentTimeout: TimeInterval = 120.0      // Seconds before suspendedIdle
    var suspendedIdleTimeout: TimeInterval = 300.0  // Seconds before destroy

    // Tier 2: Resource thresholds
    var maxConcurrentAgents: Int = 24               // Trigger pressure cleanup
    var maxConcurrentProcesses: Int = 8             // Trigger process suspension
    var memoryWarningThresholdMB: Int = 2048        // Trigger aggressive cleanup

    // Tier 3: Emergency thresholds
    var memoryCriticalThresholdMB: Int = 3072       // Emergency drain
    var processHangTimeoutSeconds: TimeInterval = 300

    // Behavior flags
    var enableAutoPoolReturn: Bool = true
    var enableResourceMonitoring: Bool = true
    var preserveAgentMemoryOnDestroy: Bool = true

    static let `default` = CleanupPolicy()
    static let aggressive = CleanupPolicy(
        completedTeamDelay: 5.0,
        failedTeamDelay: 3.0,
        idleAgentTimeout: 30.0,
        maxConcurrentAgents: 12
    )
}
```

### 4.4 Cleanup Manager

```swift
/// File: Services/AgentCleanupManager.swift
@MainActor
class AgentCleanupManager: ObservableObject {

    @Published var policy: CleanupPolicy = .default
    @Published var resourcePressure: ResourcePressure = .normal

    private var cleanupTimers: [UUID: DispatchWorkItem] = [:]
    private var idleTracking: [UUID: Date] = [:]  // agentId → idle since
    private var monitorTimer: Timer?

    weak var lifecycleManager: AgentLifecycleManager?

    // MARK: - Resource Monitoring

    func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor in self?.evaluateResourcePressure() }
        }
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
            resourcePressure = newPressure
            applyPressurePolicy(newPressure)
        }
    }

    private func applyPressurePolicy(_ pressure: ResourcePressure) {
        switch pressure {
        case .normal:
            break
        case .elevated:
            // Shorten cleanup timers
            adjustTimers(multiplier: 0.5)
        case .high:
            // Evict oldest idle agents from pool
            lifecycleManager?.evictOldestPooledAgents(count: 4)
        case .critical:
            // Emergency: destroy all idle + pooled
            lifecycleManager?.emergencyCleanup()
        }
    }

    // MARK: - Idle Tracking

    func agentBecameIdle(_ agentId: UUID) {
        idleTracking[agentId] = Date()
        scheduleIdleCheck(agentId)
    }

    func agentBecameActive(_ agentId: UUID) {
        idleTracking.removeValue(forKey: agentId)
        cleanupTimers[agentId]?.cancel()
        cleanupTimers.removeValue(forKey: agentId)
    }

    private func scheduleIdleCheck(_ agentId: UUID) {
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
        cleanupTimers[commanderId]?.cancel()
        cleanupTimers.removeValue(forKey: commanderId)
    }

    // MARK: - Helpers

    private func adjustedTimeout(_ base: TimeInterval) -> TimeInterval {
        switch resourcePressure {
        case .normal: return base
        case .elevated: return base * 0.5
        case .high: return base * 0.25
        case .critical: return 1.0  // Near-immediate
        }
    }

    private func currentMemoryUsageMB() -> Int {
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

    func shutdown() {
        monitorTimer?.invalidate()
        for item in cleanupTimers.values { item.cancel() }
        cleanupTimers.removeAll()
        idleTracking.removeAll()
    }
}

enum ResourcePressure: String, Codable {
    case normal     // < 50% capacity
    case elevated   // 50-75% capacity
    case high       // 75-100% capacity
    case critical   // > 100% capacity or memory critical
}
```

---

## 5. Agent Pool Management

### 5.1 Pool Architecture

```
┌───────────────────────────────────────────────────┐
│                  AgentPoolManager                  │
│                                                    │
│  ┌──────────────────┐  ┌───────────────────────┐  │
│  │  Active Registry  │  │  Pool (reusable)      │  │
│  │  [UUID: Agent]    │  │  [AgentRole: [Agent]] │  │
│  │                   │  │                        │  │
│  │  Commander #1     │  │  developer: [Bot A]    │  │
│  │  ├─ Dev Bot       │  │  researcher: [Unit B]  │  │
│  │  └─ Research Unit │  │  reviewer: []           │  │
│  │  Commander #2     │  │  tester: [Runner C]    │  │
│  │  └─ Test Runner   │  │  designer: []           │  │
│  └──────────────────┘  └───────────────────────┘  │
│                                                    │
│  Pool Config:                                      │
│  ├── maxPoolSize: 12                               │
│  ├── maxPerRole: 3                                 │
│  ├── preWarmCount: 0                               │
│  └── ttlSeconds: 600                               │
│                                                    │
│  Pool Metrics:                                     │
│  ├── hitCount: 42                                  │
│  ├── missCount: 8                                  │
│  ├── evictionCount: 3                              │
│  └── avgReuseLatency: 0.12s                        │
│                                                    │
└───────────────────────────────────────────────────┘
```

### 5.2 Pool Manager Implementation

```swift
/// File: Services/AgentPoolManager.swift
@MainActor
class AgentPoolManager: ObservableObject {

    struct PoolConfig: Codable {
        var maxPoolSize: Int = 12
        var maxPerRole: Int = 3
        var preWarmCount: Int = 0       // Pre-create agents at startup
        var ttlSeconds: TimeInterval = 600  // Time-to-live in pool
        var enablePooling: Bool = true
    }

    struct PoolMetrics {
        var hitCount: Int = 0        // Reused from pool
        var missCount: Int = 0       // Had to create new
        var evictionCount: Int = 0   // Evicted from pool
        var totalCreated: Int = 0
        var totalDestroyed: Int = 0

        var hitRate: Double {
            let total = hitCount + missCount
            return total > 0 ? Double(hitCount) / Double(total) : 0
        }
    }

    @Published var config: PoolConfig = PoolConfig()
    @Published var metrics: PoolMetrics = PoolMetrics()

    // Pool storage: role → [(agent, pooledAt)]
    private var pool: [AgentRole: [(agent: Agent, pooledAt: Date)]] = [:]

    // TTL eviction timers
    private var evictionTimers: [UUID: DispatchWorkItem] = [:]

    /// Acquire an agent from pool, or create a new one
    func acquire(role: AgentRole, parentId: UUID?, model: ClaudeModel) -> Agent {
        guard config.enablePooling else {
            metrics.missCount += 1
            metrics.totalCreated += 1
            return createNewAgent(role: role, parentId: parentId, model: model)
        }

        // Try to get from pool
        if var rolePool = pool[role], !rolePool.isEmpty {
            let (agent, _) = rolePool.removeFirst()
            pool[role] = rolePool

            // Cancel eviction timer
            evictionTimers[agent.id]?.cancel()
            evictionTimers.removeValue(forKey: agent.id)

            // Reconfigure for new assignment
            var reusedAgent = agent
            reusedAgent.parentAgentId = parentId
            reusedAgent.selectedModel = model
            reusedAgent.assignedTaskIds = []
            reusedAgent.subAgentIds = []
            reusedAgent.status = .idle

            metrics.hitCount += 1
            return reusedAgent
        }

        // Pool miss — create new
        metrics.missCount += 1
        metrics.totalCreated += 1
        return createNewAgent(role: role, parentId: parentId, model: model)
    }

    /// Return an agent to the pool for future reuse
    func release(_ agent: Agent) -> Bool {
        guard config.enablePooling else { return false }

        let role = agent.role
        let roleCount = pool[role]?.count ?? 0
        let totalCount = pool.values.reduce(0) { $0 + $1.count }

        // Check capacity
        guard roleCount < config.maxPerRole,
              totalCount < config.maxPoolSize else {
            metrics.evictionCount += 1
            return false  // Pool full, caller should destroy
        }

        // Clean agent state for pooling
        var pooledAgent = agent
        pooledAgent.parentAgentId = nil
        pooledAgent.subAgentIds = []
        pooledAgent.assignedTaskIds = []
        pooledAgent.status = .idle

        pool[role, default: []].append((agent: pooledAgent, pooledAt: Date()))

        // Schedule TTL eviction
        scheduleEviction(agentId: pooledAgent.id, role: role)

        return true
    }

    /// Evict oldest pooled agents (called under resource pressure)
    func evictOldest(count: Int) -> [UUID] {
        var allPooled: [(role: AgentRole, index: Int, date: Date, id: UUID)] = []
        for (role, agents) in pool {
            for (i, entry) in agents.enumerated() {
                allPooled.append((role, i, entry.pooledAt, entry.agent.id))
            }
        }

        // Sort by pooledAt ascending (oldest first)
        allPooled.sort { $0.date < $1.date }

        var evictedIds: [UUID] = []
        for item in allPooled.prefix(count) {
            pool[item.role]?.removeAll { $0.agent.id == item.id }
            evictionTimers[item.id]?.cancel()
            evictionTimers.removeValue(forKey: item.id)
            evictedIds.append(item.id)
            metrics.evictionCount += 1
        }

        return evictedIds
    }

    var totalPooledCount: Int {
        pool.values.reduce(0) { $0 + $1.count }
    }

    func pooledCount(for role: AgentRole) -> Int {
        pool[role]?.count ?? 0
    }

    func drain() {
        for item in evictionTimers.values { item.cancel() }
        evictionTimers.removeAll()
        let totalDrained = pool.values.reduce(0) { $0 + $1.count }
        metrics.totalDestroyed += totalDrained
        pool.removeAll()
    }

    // MARK: - Private

    private func createNewAgent(role: AgentRole, parentId: UUID?, model: ClaudeModel) -> Agent {
        if let parentId = parentId {
            return AgentFactory.createSubAgent(parentId: parentId, role: role, model: model)
        } else {
            return AgentFactory.createCommander(model: model)
        }
    }

    private func scheduleEviction(agentId: UUID, role: AgentRole) {
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.pool[role]?.removeAll { $0.agent.id == agentId }
                self?.evictionTimers.removeValue(forKey: agentId)
                self?.metrics.evictionCount += 1
                self?.metrics.totalDestroyed += 1
            }
        }
        evictionTimers[agentId] = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + config.ttlSeconds,
            execute: workItem
        )
    }
}
```

### 5.3 Pool Integration Flow

```
Task Submitted
    │
    ▼
AgentPoolManager.acquire(role, parentId, model)
    │
    ├─ Pool HIT → reuse existing agent (skip 3D creation)
    │              → update parentId, model, status
    │              → walk to new desk position
    │
    └─ Pool MISS → AgentFactory.createSubAgent()
                   → full 3D scene rebuild
    │
    ▼
Agent executes task...
    │
    ▼
Task completed/failed
    │
    ▼
AgentPoolManager.release(agent)
    │
    ├─ Pool has capacity → return to pool
    │                      → remove from 3D scene
    │                      → schedule TTL eviction
    │
    └─ Pool full → proceed to destroy
                   → disband animation
                   → removeTeamData()
```

---

## 6. Resume & Data Persistence

### 6.1 Persistence Architecture

```
┌──────────────────────────────────────────────────────────┐
│               AgentPersistenceManager                     │
│                                                           │
│  Storage Location:                                        │
│  ~/Library/Application Support/AgentCommand/              │
│  ├── Sessions/                                            │
│  │   ├── index.json           (SessionSummary[])          │
│  │   └── session-{uuid}.json  (SessionRecord)             │
│  ├── AgentState/              ← NEW                       │
│  │   ├── snapshot.json        (AgentStateSnapshot)        │
│  │   ├── pool-state.json      (PoolState)                 │
│  │   └── pending-resumes/                                 │
│  │       └── {agentId}.json   (ResumeContext)             │
│  └── Memory/                  (existing)                  │
│      └── agent-memory.sqlite                              │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

### 6.2 Resume Context Model

```swift
/// File: Models/ResumeContext.swift

/// Complete context needed to resume a suspended agent
struct ResumeContext: Codable, Identifiable {
    var id: UUID { agentId }

    // Agent identity
    let agentId: UUID
    let agentName: String
    let agentRole: AgentRole
    let agentModel: ClaudeModel
    let agentPersonality: AgentPersonality
    let agentAppearance: VoxelAppearance

    // CLI session
    let sessionId: String
    let workingDirectory: String

    // Task context
    let taskId: UUID
    let taskTitle: String
    let taskDescription: String
    let originalPrompt: String

    // Suspension info
    let suspendedAt: Date
    let suspensionReason: SuspensionReason
    let lastOutput: [CLIOutputEntry]  // Last N entries
    let toolCallCount: Int
    let progressEstimate: Double

    // Team context
    let commanderId: UUID?
    let teamAgentIds: [UUID]

    // Orchestration context (if part of auto-decomposition)
    let orchestrationId: UUID?
    let orchestrationTaskIndex: Int?

    // Pending interaction (what user needs to respond to)
    let pendingInteraction: PendingInteraction?
}

enum SuspensionReason: String, Codable {
    case userQuestion       // AskUserQuestion tool
    case planReview         // ExitPlanMode tool
    case permissionDenied   // User denied dangerous command
    case userPaused         // Manual pause
    case appTerminated      // App quit while running
    case processTimeout     // Process exceeded time limit
}

struct PendingInteraction: Codable {
    let type: InteractionType
    let sessionId: String
    let inputJSON: String
    let receivedAt: Date

    enum InteractionType: String, Codable {
        case question
        case planReview
        case permissionRequest
    }
}
```

### 6.3 State Snapshot for App Restart

```swift
/// File: Models/AgentStateSnapshot.swift

/// Full application state snapshot for recovery after restart
struct AgentStateSnapshot: Codable {
    let savedAt: Date
    let appVersion: String

    // Active agents (not in pool)
    let agents: [Agent]
    let tasks: [AgentTask]

    // Suspended contexts (can be resumed)
    let resumeContexts: [ResumeContext]

    // Orchestration states
    let orchestrationStates: [OrchestrationState]

    // Pool state
    let pooledAgents: [PooledAgentEntry]

    // Timeline (last 100 events)
    let recentTimelineEvents: [TimelineEvent]

    // Settings
    let cleanupPolicy: CleanupPolicy
    let poolConfig: AgentPoolManager.PoolConfig
}

struct PooledAgentEntry: Codable {
    let agent: Agent
    let pooledAt: Date
}
```

### 6.4 Persistence Manager

```swift
/// File: Services/AgentPersistenceManager.swift
@MainActor
class AgentPersistenceManager: ObservableObject {

    private let baseDir: URL
    private let snapshotURL: URL
    private let poolStateURL: URL
    private let pendingResumesDir: URL

    private var autoSaveTimer: Timer?
    private let autoSaveInterval: TimeInterval = 30.0

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("AgentCommand")

        baseDir = appSupport.appendingPathComponent("AgentState")
        snapshotURL = baseDir.appendingPathComponent("snapshot.json")
        poolStateURL = baseDir.appendingPathComponent("pool-state.json")
        pendingResumesDir = baseDir.appendingPathComponent("pending-resumes")

        try? FileManager.default.createDirectory(
            at: pendingResumesDir,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Resume Context

    func saveResumeContext(_ context: ResumeContext) {
        let url = pendingResumesDir.appendingPathComponent("\(context.agentId).json")
        if let data = try? JSONEncoder().encode(context) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func loadResumeContext(agentId: UUID) -> ResumeContext? {
        let url = pendingResumesDir.appendingPathComponent("\(agentId).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ResumeContext.self, from: data)
    }

    func removeResumeContext(agentId: UUID) {
        let url = pendingResumesDir.appendingPathComponent("\(agentId).json")
        try? FileManager.default.removeItem(at: url)
    }

    func allPendingResumes() -> [ResumeContext] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: pendingResumesDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(ResumeContext.self, from: data)
        }
    }

    // MARK: - State Snapshot

    func saveSnapshot(_ snapshot: AgentStateSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: snapshotURL, options: .atomic)
        }
    }

    func loadSnapshot() -> AgentStateSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? JSONDecoder().decode(AgentStateSnapshot.self, from: data)
    }

    // MARK: - Auto-Save

    func startAutoSave(snapshotProvider: @escaping () -> AgentStateSnapshot) {
        autoSaveTimer = Timer.scheduledTimer(
            withTimeInterval: autoSaveInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                let snapshot = snapshotProvider()
                self?.saveSnapshot(snapshot)
            }
        }
    }

    func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
}
```

### 6.5 Resume Flow

```
App Launch
    │
    ▼
AgentPersistenceManager.loadSnapshot()
    │
    ├─ No snapshot → fresh start
    │
    └─ Has snapshot
       │
       ▼
       Restore agents, tasks, pool state
       │
       ▼
       allPendingResumes()
       │
       ├─ For each ResumeContext:
       │   │
       │   ▼
       │   Show "Pending Resume" badge on agent
       │   │
       │   ├─ User clicks "Resume"
       │   │   │
       │   │   ▼
       │   │   CLIProcessManager.startProcess(
       │   │       resumeSessionId: context.sessionId,
       │   │       prompt: buildResumePrompt(context)
       │   │   )
       │   │   │
       │   │   ▼
       │   │   Agent → working state
       │   │   removeResumeContext(agentId)
       │   │
       │   └─ User clicks "Discard"
       │       │
       │       ▼
       │       removeResumeContext(agentId)
       │       Agent → destroying → destroyed
       │
       └─ No pending resumes → normal operation
```

---

## 7. State Transition Diagrams

### 7.1 Complete Agent Lifecycle State Diagram

```
                          ┌─────────────┐
                          │             │
            ┌─────────────│ DESTROYED   │ (terminal)
            │             │             │
            │             └─────────────┘
            │                    ▲
            │                    │ animationComplete
            │                    │
            │             ┌─────────────┐
            │             │             │
            │    ┌────────│ DESTROYING  │◄──────────────┐
            │    │        │             │               │
            │    │        └─────────────┘               │
            │    │              ▲  ▲  ▲                 │
            │    │              │  │  │                 │
            │    │   disbandSch.│  │  │poolEviction     │
            │    │              │  │  │                 │
            │    │              │  │  │                 │cleanupTriggered
            │    │              │  │  │                 │
 ┌──────────┴────┴──┐   ┌──────┴──┴──┴──┐    ┌────────┴────────┐
 │                   │   │               │    │                  │
 │   INITIALIZING    │   │  COMPLETED    │    │  SUSPENDED_IDLE  │
 │                   │   │               │    │                  │
 └───────┬───────────┘   └──────┬────────┘    └──────▲───────────┘
         │                      │                     │
         │resourcesLoaded       │returnToPool         │timeout
         │                      │                     │
         ▼                      ▼                     │
 ┌───────────────┐      ┌─────────────┐       ┌──────┴──────────┐
 │               │      │             │       │                  │
 │     IDLE      │◄─────│   POOLED    │       │   SUSPENDED      │
 │               │      │             │       │                  │
 └───┬───────────┘      └─────────────┘       └──────▲───────────┘
     │                                                │
     │assignTask                          processTerminated
     │                                    permissionDenied
     ▼                                    planRejected
 ┌───────────────┐      ┌─────────────┐       │
 │               │◄─────│             │       │
 │   WORKING     │      │  THINKING   │       │
 │               │─────►│             │       │
 └───┬──┬──┬─────┘      └─────────────┘       │
     │  │  │                                   │
     │  │  │    ┌──────────────────────┐       │
     │  │  └───►│ REQUESTING_PERMISSION│───────┘
     │  │       └──────────────────────┘
     │  │
     │  │       ┌──────────────────────┐
     │  └──────►│ WAITING_FOR_ANSWER   │───────┘
     │          └──────────────────────┘
     │
     │          ┌──────────────────────┐
     └─────────►│ REVIEWING_PLAN       │───────┘
                └──────────────────────┘

     │                                   ┌─────────────┐
     ├─ taskCompleted ──────────────────►│  COMPLETED   │
     │                                   └─────────────┘
     │                                   ┌─────────────┐
     └─ taskFailed ─────────────────────►│    ERROR     │
                                         └─────────────┘
```

### 7.2 Team Lifecycle (Commander + SubAgents)

```
User submits prompt
        │
        ▼
┌─────────────────────┐
│  CREATE COMMANDER   │  AgentPoolManager.acquire(.commander)
│  state: initializing│
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ WALK TO DESK + WAVE │  sceneManager.walkAgentToDesk()
│  state: idle        │
└────────┬────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│              AUTO-DECOMPOSITION CHECK                │
│  Orchestrator.shouldDecompose(prompt)?               │
│                                                      │
│  YES ──► Phase 1: Decompose (Haiku CLI)              │
│          Phase 2: Create SubAgents → Execute Waves   │
│          Phase 3: Synthesize Results                  │
│                                                      │
│  NO ───► Direct Execution (single CLI process)       │
└────────┬────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────┐
│  EXECUTION PHASE    │
│                     │
│  Commander: working │──► thinking ──► working ──►...
│  SubAgent1: working │──► thinking ──► completed
│  SubAgent2: working │──► waitingForAnswer ──► suspended
│                     │
└────────┬────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│              COMPLETION ASSESSMENT                    │
│                                                      │
│  All completed? ──► Schedule cleanup (15s)           │
│  Any failed? ────► Schedule cleanup (10s)            │
│  Any suspended? ─► Wait for user action              │
│  Any active? ────► Continue monitoring               │
│                                                      │
└────────┬────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│              CLEANUP / POOL RETURN                    │
│                                                      │
│  For each agent in team:                             │
│  ├─ Pool has capacity? ──► release(agent) → pooled   │
│  └─ Pool full? ──────────► destroying → destroyed    │
│                                                      │
│  Remove completed/failed tasks                       │
│  Update 3D scene                                     │
│  End session recording if no agents remain           │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### 7.3 Orchestration Phase Transitions

```
┌──────────────┐     parse success      ┌──────────────┐
│              │ ──────────────────────► │              │
│ DECOMPOSING  │                         │  EXECUTING   │
│              │ ──────┐                 │              │
└──────────────┘       │                 └──────┬───────┘
                       │ parse fail /            │
                       │ ≤1 subtask              │ all waves done
                       │                         ▼
                       │                 ┌──────────────┐
                       │                 │              │
                       │                 │ SYNTHESIZING │
                       │                 │              │
                       │                 └──────┬───────┘
                       │                        │
                       ▼                        ▼
              ┌──────────────┐          ┌──────────────┐
              │              │          │              │
              │   FAILED     │          │  COMPLETED   │
              │  (fallback)  │          │              │
              └──────────────┘          └──────────────┘
```

---

## 8. Implementation Plan

### 8.1 Centralized Lifecycle Manager

```swift
/// File: Services/AgentLifecycleManager.swift
///
/// Central coordinator that owns state machine, cleanup, pool, and persistence.
/// Extracts lifecycle logic from AppState into a dedicated service.
@MainActor
class AgentLifecycleManager: ObservableObject {

    // Sub-managers
    let stateMachine = AgentLifecycleStateMachine()
    let cleanupManager = AgentCleanupManager()
    let poolManager = AgentPoolManager()
    let persistenceManager = AgentPersistenceManager()

    // References
    weak var appState: AppState?

    // Agent state tracking
    @Published var agentStates: [UUID: AgentLifecycleState] = [:]

    var activeAgentCount: Int {
        agentStates.values.filter { $0.isActive }.count
    }

    var runningProcessCount: Int {
        appState?.cliProcessManager.processes.values.filter { $0.isRunning }.count ?? 0
    }

    // MARK: - Initialization

    func initialize() {
        cleanupManager.lifecycleManager = self
        registerAllTransitions()
        cleanupManager.startMonitoring()
        persistenceManager.startAutoSave { [weak self] in
            self?.buildSnapshot() ?? AgentStateSnapshot(
                savedAt: Date(), appVersion: "1.0",
                agents: [], tasks: [], resumeContexts: [],
                orchestrationStates: [], pooledAgents: [],
                recentTimelineEvents: [],
                cleanupPolicy: .default,
                poolConfig: AgentPoolManager.PoolConfig()
            )
        }

        // Restore from snapshot if available
        restoreFromSnapshot()
    }

    func shutdown() {
        cleanupManager.shutdown()
        persistenceManager.stopAutoSave()

        // Save final snapshot
        persistenceManager.saveSnapshot(buildSnapshot())

        // Save resume contexts for all active agents
        saveAllResumeContexts()
    }

    // MARK: - State Transitions

    func fireEvent(_ event: LifecycleEvent, forAgent agentId: UUID) {
        guard let agent = appState?.agents.first(where: { $0.id == agentId }),
              let currentState = agentStates[agentId] else { return }

        let context = AgentContext(
            agentId: agentId,
            currentState: currentState,
            agent: agent,
            sessionId: appState?.cliProcessManager.processes.values
                .first(where: { $0.agentId == agentId })?.sessionId,
            taskId: agent.assignedTaskIds.last,
            poolCapacity: poolManager.config.maxPoolSize,
            currentPoolSize: poolManager.totalPooledCount,
            idleDuration: cleanupManager.idleDuration(for: agentId)
        )

        guard let newState = stateMachine.fire(event: event, context: context) else {
            return
        }

        agentStates[agentId] = newState

        // Map to legacy AgentStatus for backward compatibility
        let legacyStatus = mapToLegacyStatus(newState)
        appState?.handleAgentStatusChange(agentId, to: legacyStatus)

        // Trigger side effects
        handleStateTransition(agentId: agentId, from: currentState, to: newState, event: event)
    }

    // MARK: - Team Operations

    func createTeam(model: ClaudeModel, subAgentCount: Int = 2) -> (commander: Agent, subAgents: [Agent]) {
        let commander = poolManager.acquire(role: .commander, parentId: nil, model: model)
        agentStates[commander.id] = .initializing

        var subAgents: [Agent] = []
        let roles: [AgentRole] = [.developer, .researcher, .reviewer, .tester, .designer]

        for i in 0..<subAgentCount {
            let role = roles[i % roles.count]
            let sub = poolManager.acquire(role: role, parentId: commander.id, model: model)
            agentStates[sub.id] = .initializing
            subAgents.append(sub)
        }

        return (commander, subAgents)
    }

    func initiateTeamDisband(commanderId: UUID) {
        guard let appState = appState else { return }

        let teamIds = [commanderId] + appState.subAgents(of: commanderId).map(\.id)

        for agentId in teamIds {
            let agent = appState.agents.first(where: { $0.id == agentId })

            // Try to return to pool first
            if let agent = agent, poolManager.release(agent) {
                agentStates[agentId] = .pooled
            } else {
                agentStates[agentId] = .destroying
            }
        }

        // Animate disband for destroying agents
        let destroyingIds = teamIds.filter { agentStates[$0] == .destroying }
        if !destroyingIds.isEmpty {
            appState.sceneManager.disbandTeam(agentIds: destroyingIds) { [weak self] in
                Task { @MainActor in
                    for agentId in destroyingIds {
                        self?.agentStates[agentId] = .destroyed
                    }
                    self?.finalizeTeamRemoval(commanderId: commanderId, teamIds: teamIds)
                }
            }
        } else {
            finalizeTeamRemoval(commanderId: commanderId, teamIds: teamIds)
        }
    }

    func evictOldestPooledAgents(count: Int) {
        let evictedIds = poolManager.evictOldest(count: count)
        for id in evictedIds {
            agentStates[id] = .destroyed
        }
    }

    func emergencyCleanup() {
        guard let appState = appState else { return }

        // Destroy all idle and pooled agents
        let candidates = agentStates.filter { $0.value.isCleanupCandidate || $0.value == .pooled }
        for (agentId, _) in candidates {
            agentStates[agentId] = .destroyed
            appState.agents.removeAll { $0.id == agentId }
        }
        poolManager.drain()
        appState.rebuildScene()
    }

    // MARK: - Resume

    func suspendAgent(_ agentId: UUID, reason: SuspensionReason) {
        guard let appState = appState,
              let agent = appState.agents.first(where: { $0.id == agentId }) else { return }

        let cliProcess = appState.cliProcessManager.processes.values
            .first(where: { $0.agentId == agentId })

        let context = ResumeContext(
            agentId: agentId,
            agentName: agent.name,
            agentRole: agent.role,
            agentModel: agent.selectedModel,
            agentPersonality: agent.personality,
            agentAppearance: agent.appearance,
            sessionId: cliProcess?.sessionId ?? "",
            workingDirectory: appState.workspaceManager.activeDirectory,
            taskId: agent.assignedTaskIds.last ?? UUID(),
            taskTitle: appState.tasks.first(where: { $0.assignedAgentId == agentId })?.title ?? "",
            taskDescription: "",
            originalPrompt: cliProcess?.prompt ?? "",
            suspendedAt: Date(),
            suspensionReason: reason,
            lastOutput: Array((cliProcess?.outputEntries ?? []).suffix(20)),
            toolCallCount: cliProcess?.toolCallCount ?? 0,
            progressEstimate: 0,
            commanderId: agent.parentAgentId,
            teamAgentIds: [],
            orchestrationId: nil,
            orchestrationTaskIndex: nil,
            pendingInteraction: nil
        )

        persistenceManager.saveResumeContext(context)
        agentStates[agentId] = .suspended
    }

    func resumeAgent(_ agentId: UUID) {
        guard let context = persistenceManager.loadResumeContext(agentId: agentId),
              let appState = appState else { return }

        agentStates[agentId] = .working

        let _ = appState.cliProcessManager.startProcess(
            taskId: context.taskId,
            agentId: agentId,
            prompt: "Continue from where you left off.",
            workingDirectory: context.workingDirectory,
            model: context.agentModel,
            resumeSessionId: context.sessionId,
            onStatusChange: { [weak appState] agentId, status in
                Task { @MainActor in
                    appState?.handleAgentStatusChange(agentId, to: status)
                }
            },
            onProgress: { [weak appState] taskId, progress in
                Task { @MainActor in
                    if let idx = appState?.tasks.firstIndex(where: { $0.id == taskId }) {
                        appState?.tasks[idx].progress = progress
                    }
                }
            },
            onCompleted: { [weak appState] taskId, result in
                Task { @MainActor in
                    appState?.handleCLICompleted(taskId, result: result)
                }
            },
            onFailed: { [weak appState] taskId, error in
                Task { @MainActor in
                    appState?.handleCLIFailed(taskId, error: error)
                }
            }
        )

        persistenceManager.removeResumeContext(agentId: agentId)
    }

    // MARK: - Private Helpers

    private func mapToLegacyStatus(_ state: AgentLifecycleState) -> AgentStatus {
        switch state {
        case .initializing, .idle, .pooled, .suspendedIdle:
            return .idle
        case .working:
            return .working
        case .thinking:
            return .thinking
        case .requestingPermission:
            return .requestingPermission
        case .waitingForAnswer:
            return .waitingForAnswer
        case .reviewingPlan:
            return .reviewingPlan
        case .completed:
            return .completed
        case .error:
            return .error
        case .suspended:
            return .waitingForAnswer  // Closest legacy mapping
        case .destroying, .destroyed:
            return .idle
        }
    }

    private func handleStateTransition(
        agentId: UUID,
        from: AgentLifecycleState,
        to: AgentLifecycleState,
        event: LifecycleEvent
    ) {
        switch to {
        case .idle:
            cleanupManager.agentBecameIdle(agentId)
        case .working, .thinking:
            cleanupManager.agentBecameActive(agentId)
        case .completed, .error:
            cleanupManager.agentBecameIdle(agentId)
        case .suspended:
            suspendAgent(agentId, reason: .userQuestion)
        default:
            break
        }
    }

    private func finalizeTeamRemoval(commanderId: UUID, teamIds: [UUID]) {
        guard let appState = appState else { return }

        let destroyedIds = Set(teamIds.filter { agentStates[$0] == .destroyed })

        appState.agents.removeAll { destroyedIds.contains($0.id) }
        appState.tasks.removeAll { task in
            (task.status == .completed || task.status == .failed) &&
            task.teamAgentIds.contains(where: { destroyedIds.contains($0) })
        }

        for id in destroyedIds {
            agentStates.removeValue(forKey: id)
        }

        appState.rebuildScene()
    }

    private func registerAllTransitions() {
        // Creation
        stateMachine.registerTransition(from: .initializing, event: .resourcesLoaded, to: .idle)

        // Idle → Active
        stateMachine.registerTransition(from: .idle, event: .assignTask, to: .working)
        stateMachine.registerTransition(from: .idle, event: .poolReturn, to: .pooled)
        stateMachine.registerTransition(from: .idle, event: .idleTimeout, to: .suspendedIdle)

        // Working ↔ Thinking
        stateMachine.registerTransition(from: .working, event: .aiReasoning, to: .thinking)
        stateMachine.registerTransition(from: .thinking, event: .toolInvoked, to: .working)

        // Working → Interaction
        stateMachine.registerTransition(from: .working, event: .permissionNeeded, to: .requestingPermission)
        stateMachine.registerTransition(from: .working, event: .questionAsked, to: .waitingForAnswer)
        stateMachine.registerTransition(from: .working, event: .planReady, to: .reviewingPlan)

        // Interaction → Resume/Suspend
        stateMachine.registerTransition(from: .requestingPermission, event: .permissionGranted, to: .working)
        stateMachine.registerTransition(from: .requestingPermission, event: .permissionDenied, to: .suspended)
        stateMachine.registerTransition(from: .requestingPermission, event: .processTerminated, to: .suspended)

        stateMachine.registerTransition(from: .waitingForAnswer, event: .answerReceived, to: .working)
        stateMachine.registerTransition(from: .waitingForAnswer, event: .processTerminated, to: .suspended)

        stateMachine.registerTransition(from: .reviewingPlan, event: .planApproved, to: .working)
        stateMachine.registerTransition(from: .reviewingPlan, event: .planRejected, to: .suspended)
        stateMachine.registerTransition(from: .reviewingPlan, event: .processTerminated, to: .suspended)

        // Completion
        stateMachine.registerTransition(from: .working, event: .taskCompleted, to: .completed)
        stateMachine.registerTransition(from: .working, event: .taskFailed, to: .error)
        stateMachine.registerTransition(from: .thinking, event: .taskCompleted, to: .completed)
        stateMachine.registerTransition(from: .thinking, event: .taskFailed, to: .error)

        // Suspended
        stateMachine.registerTransition(from: .suspended, event: .resume, to: .working)
        stateMachine.registerTransition(from: .suspended, event: .cancel, to: .error)
        stateMachine.registerTransition(from: .suspended, event: .timeout, to: .suspendedIdle)

        // SuspendedIdle
        stateMachine.registerTransition(from: .suspendedIdle, event: .assignTask, to: .working)
        stateMachine.registerTransition(from: .suspendedIdle, event: .cleanupTriggered, to: .destroying)

        // Pool
        stateMachine.registerTransition(from: .pooled, event: .assignTask, to: .initializing)
        stateMachine.registerTransition(from: .pooled, event: .poolEviction, to: .destroying)

        // Cleanup/Destroy
        stateMachine.registerTransition(from: .completed, event: .returnToPool, to: .pooled)
        stateMachine.registerTransition(from: .completed, event: .disbandScheduled, to: .destroying)
        stateMachine.registerTransition(from: .completed, event: .assignNewTask, to: .working)
        stateMachine.registerTransition(from: .error, event: .retry, to: .working)
        stateMachine.registerTransition(from: .error, event: .disbandScheduled, to: .destroying)
        stateMachine.registerTransition(from: .idle, event: .disbandScheduled, to: .destroying)
        stateMachine.registerTransition(from: .destroying, event: .animationComplete, to: .destroyed)
    }

    private func buildSnapshot() -> AgentStateSnapshot {
        AgentStateSnapshot(
            savedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            agents: appState?.agents ?? [],
            tasks: appState?.tasks ?? [],
            resumeContexts: persistenceManager.allPendingResumes(),
            orchestrationStates: Array(appState?.orchestrator.activeOrchestrations.values ?? [].makeIterator()),
            pooledAgents: [],  // Pool state serialized separately
            recentTimelineEvents: Array((appState?.timelineManager.events ?? []).suffix(100)),
            cleanupPolicy: cleanupManager.policy,
            poolConfig: poolManager.config
        )
    }

    private func restoreFromSnapshot() {
        guard let snapshot = persistenceManager.loadSnapshot() else { return }

        // Restore cleanup policy
        cleanupManager.policy = snapshot.cleanupPolicy
        poolManager.config = snapshot.poolConfig

        // Notify about pending resumes
        let pending = snapshot.resumeContexts
        if !pending.isEmpty {
            print("[Lifecycle] Found \(pending.count) pending resume context(s)")
        }
    }

    private func saveAllResumeContexts() {
        guard let appState = appState else { return }

        for agent in appState.agents where agentStates[agent.id]?.isActive == true {
            suspendAgent(agent.id, reason: .appTerminated)
        }
    }
}
```

---

## 9. API Reference

### 9.1 Manager Integration Map

```
┌──────────────────────────────────────────────────────────────┐
│                         AppState                              │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │           AgentLifecycleManager (NEW)                    │  │
│  │                                                          │  │
│  │  ┌──────────────────┐  ┌──────────────────┐             │  │
│  │  │ StateMachine     │  │ CleanupManager   │             │  │
│  │  │ (transitions)    │  │ (timers, monitor)│             │  │
│  │  └──────────────────┘  └──────────────────┘             │  │
│  │                                                          │  │
│  │  ┌──────────────────┐  ┌──────────────────┐             │  │
│  │  │ PoolManager      │  │ PersistenceManager│            │  │
│  │  │ (acquire/release)│  │ (snapshot, resume)│            │  │
│  │  └──────────────────┘  └──────────────────┘             │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  Existing Managers (unchanged):                               │
│  ├── CLIProcessManager    (process spawn/kill)                │
│  ├── SessionHistoryManager (recording/replay)                 │
│  ├── AutoDecompositionOrchestrator (task decomposition)       │
│  ├── AgentMemorySystemManager (knowledge persistence)         │
│  └── ThemeableScene       (3D visualization)                  │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### 9.2 Key Public APIs

| Manager | Method | Description |
|---------|--------|-------------|
| `AgentLifecycleManager` | `fireEvent(_:forAgent:)` | Trigger state transition |
| `AgentLifecycleManager` | `createTeam(model:subAgentCount:)` | Create team with pool support |
| `AgentLifecycleManager` | `initiateTeamDisband(commanderId:)` | Pool/destroy team |
| `AgentLifecycleManager` | `suspendAgent(_:reason:)` | Persist resume context |
| `AgentLifecycleManager` | `resumeAgent(_:)` | Resume from persisted context |
| `AgentLifecycleManager` | `emergencyCleanup()` | Critical resource pressure |
| `AgentPoolManager` | `acquire(role:parentId:model:)` | Get agent (pool or new) |
| `AgentPoolManager` | `release(_:)` | Return to pool |
| `AgentPoolManager` | `evictOldest(count:)` | Pressure eviction |
| `AgentPoolManager` | `drain()` | Empty entire pool |
| `AgentCleanupManager` | `scheduleTeamCleanup(commanderId:allCompleted:)` | Adaptive delay |
| `AgentCleanupManager` | `cancelTeamCleanup(commanderId:)` | Cancel pending cleanup |
| `AgentPersistenceManager` | `saveResumeContext(_:)` | Persist for resume |
| `AgentPersistenceManager` | `loadResumeContext(agentId:)` | Load resume data |
| `AgentPersistenceManager` | `saveSnapshot(_:)` | Full state snapshot |
| `AgentPersistenceManager` | `loadSnapshot()` | Restore from snapshot |

### 9.3 Migration Path from Current System

| Current Code | Replacement | Notes |
|--------------|-------------|-------|
| `AppState.disbandTimers` | `AgentCleanupManager.cleanupTimers` | Adaptive timers |
| `AppState.disbandDelay = 8.0` | `CleanupPolicy.completedTeamDelay = 15.0` | Configurable |
| `AppState.scheduleDisbandIfNeeded()` | `AgentCleanupManager.scheduleTeamCleanup()` | Resource-aware |
| `AppState.disbandTeam()` | `AgentLifecycleManager.initiateTeamDisband()` | Pool-aware |
| `AppState.removeTeamData()` | `AgentLifecycleManager.finalizeTeamRemoval()` | Separated |
| `AgentFactory.createTeam()` | `AgentLifecycleManager.createTeam()` | Pool-first |
| `AgentStatus` enum | `AgentLifecycleState` + backward compat map | Non-breaking |
| `CLIProcess.resumeSessionId` | `ResumeContext` + `AgentPersistenceManager` | Full context |

### 9.4 Backward Compatibility

The new `AgentLifecycleState` enum is separate from the existing `AgentStatus` enum. The `mapToLegacyStatus()` method provides backward compatibility so all existing views, animations, and scene management continue to work without changes. The migration can be incremental:

1. **Phase 1**: Add `AgentLifecycleManager` alongside existing AppState logic
2. **Phase 2**: Route new state transitions through `AgentLifecycleManager`
3. **Phase 3**: Migrate cleanup logic from AppState to `AgentCleanupManager`
4. **Phase 4**: Add `AgentPoolManager` for agent reuse
5. **Phase 5**: Add `AgentPersistenceManager` for resume persistence
6. **Phase 6**: Deprecate legacy lifecycle methods in AppState

---

## Appendix A: File Structure

```
AgentCommand/
├── Models/
│   ├── AgentLifecycleState.swift      (NEW - enhanced states)
│   ├── CleanupPolicy.swift            (NEW - cleanup config)
│   ├── ResumeContext.swift             (NEW - resume data)
│   ├── AgentStateSnapshot.swift        (NEW - persistence)
│   ├── Agent.swift                     (existing)
│   ├── AgentStatus.swift               (existing, kept for compat)
│   ├── AgentTask.swift                 (existing)
│   └── OrchestrationModels.swift       (existing)
├── Services/
│   ├── AgentLifecycleManager.swift     (NEW - central coordinator)
│   ├── AgentLifecycleStateMachine.swift (NEW - FSM engine)
│   ├── AgentCleanupManager.swift       (NEW - adaptive cleanup)
│   ├── AgentPoolManager.swift          (NEW - agent reuse pool)
│   ├── AgentPersistenceManager.swift   (NEW - state persistence)
│   ├── CLIProcessManager.swift         (existing)
│   ├── AgentFactory.swift              (existing)
│   ├── AgentCoordinator.swift          (existing)
│   └── AutoDecompositionOrchestrator.swift (existing)
└── App/
    └── AppState.swift                  (existing, gradually migrated)
```

## Appendix B: Metrics & Observability

```swift
/// Published metrics for dashboard display
struct LifecycleMetrics {
    // Pool
    var poolHitRate: Double
    var poolSize: Int
    var poolCapacity: Int

    // Agents
    var totalActive: Int
    var totalIdle: Int
    var totalSuspended: Int
    var totalPooled: Int

    // Cleanup
    var resourcePressure: ResourcePressure
    var cleanupsPending: Int
    var totalCleanupsExecuted: Int

    // Resume
    var pendingResumes: Int
    var successfulResumes: Int
    var failedResumes: Int

    // Process
    var runningProcesses: Int
    var avgProcessDuration: TimeInterval
}
```

---

*End of Architecture Design Document*
