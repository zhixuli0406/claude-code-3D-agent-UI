import Foundation

/// Central coordinator for agent lifecycle management.
/// Owns the state machine, cleanup manager, and logger.
/// Extracts lifecycle logic from AppState into a dedicated service.
@MainActor
class AgentLifecycleManager: ObservableObject {

    // MARK: - Sub-managers

    let stateMachine: AgentLifecycleStateMachine
    let cleanupManager: AgentCleanupManager
    let logger: LifecycleLogger

    // MARK: - Agent State Tracking

    @Published private(set) var agentStates: [UUID: AgentLifecycleState] = [:]

    // MARK: - Callbacks (for integration with AppState)

    var onStateChanged: ((UUID, AgentLifecycleState, AgentLifecycleState, LifecycleEvent) -> Void)?
    var onTeamDisbandRequested: ((UUID) -> Void)?
    var onEmergencyCleanupRequested: (() -> Void)?

    // MARK: - Computed Properties

    var activeAgentCount: Int {
        agentStates.values.filter { $0.isActive }.count
    }

    var runningProcessCount: Int {
        agentStates.values.filter { $0 == .working || $0 == .thinking }.count
    }

    var idleAgentCount: Int {
        agentStates.values.filter { $0 == .idle }.count
    }

    var suspendedAgentCount: Int {
        agentStates.values.filter { $0.isSuspended }.count
    }

    var totalManagedAgents: Int {
        agentStates.count
    }

    // MARK: - Init

    init(stateMachine: AgentLifecycleStateMachine? = nil, logger: LifecycleLogger? = nil) {
        let log = logger ?? LifecycleLogger()
        self.logger = log
        self.stateMachine = stateMachine ?? AgentLifecycleStateMachine.createDefault()
        self.cleanupManager = AgentCleanupManager(logger: log)
        self.cleanupManager.lifecycleManager = self
    }

    // MARK: - Initialization & Shutdown

    func initialize() {
        cleanupManager.lifecycleManager = self

        stateMachine.onTransition = { [weak self] agentId, from, to, event in
            self?.logger.logTransition(
                agentId: agentId,
                from: from,
                to: to,
                event: event
            )
        }

        cleanupManager.startMonitoring()
    }

    func shutdown() {
        cleanupManager.shutdown()
    }

    // MARK: - Agent Registration

    /// Register a new agent with an initial state
    func registerAgent(_ agentId: UUID, initialState: AgentLifecycleState = .initializing) {
        agentStates[agentId] = initialState
        logger.logTransition(
            agentId: agentId,
            from: initialState,
            to: initialState,
            event: .create,
            message: "Agent registered"
        )
    }

    /// Remove an agent from tracking (after destruction)
    func unregisterAgent(_ agentId: UUID) {
        agentStates.removeValue(forKey: agentId)
        cleanupManager.removeAgent(agentId)
    }

    // MARK: - State Transitions

    /// Fire a lifecycle event for a specific agent.
    /// Returns the new state if the transition was valid, nil otherwise.
    @discardableResult
    func fireEvent(
        _ event: LifecycleEvent,
        forAgent agentId: UUID,
        sessionId: String? = nil,
        taskId: UUID? = nil,
        poolCapacity: Int = 12,
        currentPoolSize: Int = 0
    ) -> AgentLifecycleState? {
        guard let currentState = agentStates[agentId] else {
            logger.logInvalidTransition(
                agentId: agentId,
                currentState: .destroyed,
                event: event,
                reason: "Agent not registered"
            )
            return nil
        }

        let context = AgentLifecycleContext(
            agentId: agentId,
            currentState: currentState,
            sessionId: sessionId,
            taskId: taskId,
            poolCapacity: poolCapacity,
            currentPoolSize: currentPoolSize,
            idleDuration: cleanupManager.idleDuration(for: agentId)
        )

        guard let newState = stateMachine.fire(event: event, context: context) else {
            logger.logInvalidTransition(
                agentId: agentId,
                currentState: currentState,
                event: event
            )
            return nil
        }

        let oldState = currentState
        agentStates[agentId] = newState

        // Log the successful transition
        logger.logTransition(
            agentId: agentId,
            from: oldState,
            to: newState,
            event: event
        )

        // Handle side effects
        handleStateTransitionSideEffects(agentId: agentId, from: oldState, to: newState, event: event)

        // Notify observers
        onStateChanged?(agentId, oldState, newState, event)

        return newState
    }

    /// Get the current lifecycle state for an agent
    func currentState(for agentId: UUID) -> AgentLifecycleState? {
        agentStates[agentId]
    }

    /// Check if an event can be fired for an agent (without actually firing it)
    func canFireEvent(_ event: LifecycleEvent, forAgent agentId: UUID) -> Bool {
        guard let currentState = agentStates[agentId] else { return false }
        return stateMachine.canFire(event: event, from: currentState)
    }

    // MARK: - Team Operations

    func initiateTeamDisband(commanderId: UUID) {
        onTeamDisbandRequested?(commanderId)
    }

    func evictOldestPooledAgents(count: Int) {
        let pooledAgents = agentStates
            .filter { $0.value == .pooled }
            .map(\.key)
            .prefix(count)

        for agentId in pooledAgents {
            fireEvent(.poolEviction, forAgent: agentId)
        }
    }

    func emergencyCleanup() {
        let candidates = agentStates.filter { $0.value.isCleanupCandidate || $0.value == .pooled }
        logger.logEmergencyCleanup(agentCount: candidates.count, reason: "Critical resource pressure")

        for (agentId, _) in candidates {
            agentStates[agentId] = .destroyed
            cleanupManager.removeAgent(agentId)
        }

        onEmergencyCleanupRequested?()
    }

    // MARK: - Batch Operations

    /// Transition all agents in a set of IDs to the destroying state
    func beginDestroyingAgents(_ agentIds: Set<UUID>) {
        for agentId in agentIds {
            if let state = agentStates[agentId], state != .destroyed && state != .destroying {
                agentStates[agentId] = .destroying
                logger.logTransition(
                    agentId: agentId,
                    from: state,
                    to: .destroying,
                    event: .disbandScheduled,
                    message: "Batch destroy"
                )
            }
        }
    }

    /// Mark agents as destroyed after animation completes
    func completeDestruction(for agentIds: Set<UUID>) {
        for agentId in agentIds {
            if agentStates[agentId] == .destroying {
                agentStates[agentId] = .destroyed
                cleanupManager.removeAgent(agentId)
                logger.logTransition(
                    agentId: agentId,
                    from: .destroying,
                    to: .destroyed,
                    event: .animationComplete
                )
            }
        }
    }

    // MARK: - Query

    /// Get all agent IDs in a specific state
    func agents(in state: AgentLifecycleState) -> [UUID] {
        agentStates.filter { $0.value == state }.map(\.key)
    }

    /// Get all agent IDs that are cleanup candidates
    func cleanupCandidates() -> [UUID] {
        agentStates.filter { $0.value.isCleanupCandidate }.map(\.key)
    }

    /// Get all agent IDs that are available for task assignment
    func availableAgents() -> [UUID] {
        agentStates.filter { $0.value.isAvailableForTask }.map(\.key)
    }

    // MARK: - Private: Side Effects

    private func handleStateTransitionSideEffects(
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
            cleanupManager.scheduleSuspendedTimeout(agentId)

        case .destroyed:
            cleanupManager.removeAgent(agentId)

        default:
            break
        }
    }
}
