import Foundation

/// Finite state machine engine for agent lifecycle management.
/// Registers allowed transitions and validates state changes with optional guard conditions.
@MainActor
class AgentLifecycleStateMachine {

    typealias State = AgentLifecycleState
    typealias Guard = (AgentLifecycleContext) -> Bool
    typealias Action = (AgentLifecycleContext) -> Void

    // MARK: - Transition Definition

    struct Transition {
        let from: State
        let event: LifecycleEvent
        let to: State
        let guardCondition: Guard?
        let action: Action?
    }

    // MARK: - Lookup Key

    private struct TransitionKey: Hashable {
        let from: State
        let event: LifecycleEvent
    }

    // MARK: - Properties

    private(set) var transitions: [Transition] = []
    /// O(1) lookup table indexed by (state, event) for fast transition resolution
    private var transitionIndex: [TransitionKey: [Transition]] = [:]
    var onTransition: ((UUID, State, State, LifecycleEvent) -> Void)?

    // MARK: - Registration

    func registerTransition(
        from: State,
        event: LifecycleEvent,
        to: State,
        guard guardCondition: Guard? = nil,
        action: Action? = nil
    ) {
        let t = Transition(
            from: from,
            event: event,
            to: to,
            guardCondition: guardCondition,
            action: action
        )
        transitions.append(t)
        let key = TransitionKey(from: from, event: event)
        transitionIndex[key, default: []].append(t)
    }

    // MARK: - Firing Events

    /// Attempt to transition from the current state via the given event.
    /// Uses O(1) hash lookup instead of scanning all transitions.
    func fire(event: LifecycleEvent, context: AgentLifecycleContext) -> State? {
        let current = context.currentState
        let key = TransitionKey(from: current, event: event)

        guard let candidates = transitionIndex[key] else {
            return nil
        }

        guard let transition = candidates.first(where: { t in
            t.guardCondition == nil || t.guardCondition!(context)
        }) else {
            return nil
        }

        transition.action?(context)
        onTransition?(context.agentId, current, transition.to, event)
        return transition.to
    }

    // MARK: - Query

    /// Returns all valid events that can be fired from the given state
    func validEvents(from state: State) -> [LifecycleEvent] {
        transitions
            .filter { $0.from == state }
            .map(\.event)
    }

    /// Returns the target state for a given from-state and event (ignoring guards)
    func targetState(from state: State, event: LifecycleEvent) -> State? {
        let key = TransitionKey(from: state, event: event)
        return transitionIndex[key]?.first?.to
    }

    /// Checks if a transition is defined (ignoring guards) for the from-state and event
    func canFire(event: LifecycleEvent, from state: State) -> Bool {
        let key = TransitionKey(from: state, event: event)
        return transitionIndex[key] != nil
    }

    /// Number of registered transitions
    var transitionCount: Int {
        transitions.count
    }

    // MARK: - Factory: Default Configuration

    /// Creates a fully configured state machine with all standard transitions registered
    static func createDefault() -> AgentLifecycleStateMachine {
        let fsm = AgentLifecycleStateMachine()

        // === Creation ===
        fsm.registerTransition(from: .initializing, event: .resourcesLoaded, to: .idle)

        // === Idle transitions ===
        fsm.registerTransition(from: .idle, event: .assignTask, to: .working)
        fsm.registerTransition(from: .idle, event: .poolReturn, to: .pooled,
                               guard: { $0.currentPoolSize < $0.poolCapacity })
        fsm.registerTransition(from: .idle, event: .idleTimeout, to: .suspendedIdle)
        fsm.registerTransition(from: .idle, event: .disbandScheduled, to: .destroying)

        // === Working <-> Thinking ===
        fsm.registerTransition(from: .working, event: .aiReasoning, to: .thinking)
        fsm.registerTransition(from: .thinking, event: .toolInvoked, to: .working)

        // === Working -> Interaction ===
        fsm.registerTransition(from: .working, event: .permissionNeeded, to: .requestingPermission)
        fsm.registerTransition(from: .working, event: .questionAsked, to: .waitingForAnswer)
        fsm.registerTransition(from: .working, event: .planReady, to: .reviewingPlan)

        // === Interaction -> Resume/Suspend ===
        fsm.registerTransition(from: .requestingPermission, event: .permissionGranted, to: .working)
        fsm.registerTransition(from: .requestingPermission, event: .permissionDenied, to: .suspended)
        fsm.registerTransition(from: .requestingPermission, event: .processTerminated, to: .suspended)

        fsm.registerTransition(from: .waitingForAnswer, event: .answerReceived, to: .working)
        fsm.registerTransition(from: .waitingForAnswer, event: .processTerminated, to: .suspended)

        fsm.registerTransition(from: .reviewingPlan, event: .planApproved, to: .working)
        fsm.registerTransition(from: .reviewingPlan, event: .planRejected, to: .suspended)
        fsm.registerTransition(from: .reviewingPlan, event: .processTerminated, to: .suspended)

        // === Completion ===
        fsm.registerTransition(from: .working, event: .taskCompleted, to: .completed)
        fsm.registerTransition(from: .working, event: .taskFailed, to: .error)
        fsm.registerTransition(from: .thinking, event: .taskCompleted, to: .completed)
        fsm.registerTransition(from: .thinking, event: .taskFailed, to: .error)

        // === Suspended ===
        fsm.registerTransition(from: .suspended, event: .resume, to: .working,
                               guard: { $0.sessionId != nil })
        fsm.registerTransition(from: .suspended, event: .cancel, to: .error)
        fsm.registerTransition(from: .suspended, event: .timeout, to: .suspendedIdle)

        // === SuspendedIdle ===
        fsm.registerTransition(from: .suspendedIdle, event: .assignTask, to: .working)
        fsm.registerTransition(from: .suspendedIdle, event: .cleanupTriggered, to: .destroying)

        // === Pool ===
        fsm.registerTransition(from: .pooled, event: .assignTask, to: .initializing)
        fsm.registerTransition(from: .pooled, event: .poolEviction, to: .destroying)

        // === Completed/Error -> Next phase ===
        fsm.registerTransition(from: .completed, event: .returnToPool, to: .pooled,
                               guard: { $0.currentPoolSize < $0.poolCapacity })
        fsm.registerTransition(from: .completed, event: .disbandScheduled, to: .destroying)
        fsm.registerTransition(from: .completed, event: .assignNewTask, to: .working)
        fsm.registerTransition(from: .error, event: .retry, to: .working)
        fsm.registerTransition(from: .error, event: .disbandScheduled, to: .destroying)

        // === Destruction ===
        fsm.registerTransition(from: .destroying, event: .animationComplete, to: .destroyed)

        return fsm
    }
}
