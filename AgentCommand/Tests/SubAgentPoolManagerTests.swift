import XCTest
@testable import AgentCommand

@MainActor
final class SubAgentPoolManagerTests: XCTestCase {

    var poolManager: SubAgentPoolManager!

    override func setUp() {
        super.setUp()
        poolManager = SubAgentPoolManager()
    }

    override func tearDown() {
        poolManager.shutdown()
        poolManager = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(poolManager.totalPooledCount, 0)
        XCTAssertEqual(poolManager.stats.totalPooled, 0)
        XCTAssertEqual(poolManager.stats.hitCount, 0)
        XCTAssertEqual(poolManager.stats.missCount, 0)
    }

    // MARK: - Acquire (Cache Miss)

    func testAcquire_EmptyPool_ReturnsNil() {
        let result = poolManager.acquire(role: .developer, parentId: UUID(), model: .sonnet)
        XCTAssertNil(result)
        XCTAssertEqual(poolManager.stats.missCount, 1)
        XCTAssertEqual(poolManager.stats.hitCount, 0)
    }

    func testAcquireOrCreate_EmptyPool_CreatesNewAgent() {
        let parentId = UUID()
        let agent = poolManager.acquireOrCreate(role: .developer, parentId: parentId, model: .sonnet)
        XCTAssertEqual(agent.role, .developer)
        XCTAssertEqual(agent.parentAgentId, parentId)
        XCTAssertEqual(agent.selectedModel, .sonnet)
        XCTAssertEqual(poolManager.stats.missCount, 1)
    }

    // MARK: - Release & Acquire (Cache Hit)

    func testReleaseAndAcquire_PoolHit() {
        let agent = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)

        // Release to pool
        let released = poolManager.release(agent)
        XCTAssertTrue(released)
        XCTAssertEqual(poolManager.totalPooledCount, 1)
        XCTAssertEqual(poolManager.pooledCount(for: .developer), 1)

        // Acquire from pool
        let newParent = UUID()
        let acquired = poolManager.acquire(role: .developer, parentId: newParent, model: .haiku)
        XCTAssertNotNil(acquired)
        XCTAssertEqual(acquired?.id, agent.id)
        XCTAssertEqual(acquired?.parentAgentId, newParent)
        XCTAssertEqual(acquired?.selectedModel, .haiku)
        XCTAssertEqual(acquired?.status, .idle)

        XCTAssertEqual(poolManager.stats.hitCount, 1)
        XCTAssertEqual(poolManager.totalPooledCount, 0)
    }

    func testAcquire_WrongRole_ReturnsNil() {
        let agent = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        poolManager.release(agent)

        // Try to acquire with different role
        let result = poolManager.acquire(role: .researcher, parentId: UUID(), model: .sonnet)
        XCTAssertNil(result)
        XCTAssertEqual(poolManager.stats.missCount, 1)
        XCTAssertEqual(poolManager.totalPooledCount, 1) // developer still in pool
    }

    // MARK: - Pool Capacity

    func testRelease_PoolFull_ReturnsFalse() {
        poolManager.config.maxPoolSize = 2
        poolManager.config.maxPerRole = 2

        let a1 = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        let a2 = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        let a3 = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)

        XCTAssertTrue(poolManager.release(a1))
        XCTAssertTrue(poolManager.release(a2))
        XCTAssertFalse(poolManager.release(a3)) // pool full

        XCTAssertEqual(poolManager.totalPooledCount, 2)
        XCTAssertEqual(poolManager.stats.evictionCount, 1)
    }

    func testRelease_MaxPerRoleExceeded_ReturnsFalse() {
        poolManager.config.maxPoolSize = 10
        poolManager.config.maxPerRole = 1

        let a1 = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        let a2 = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)

        XCTAssertTrue(poolManager.release(a1))
        XCTAssertFalse(poolManager.release(a2)) // max per role

        XCTAssertEqual(poolManager.pooledCount(for: .developer), 1)
    }

    // MARK: - hasAvailable

    func testHasAvailable() {
        XCTAssertFalse(poolManager.hasAvailable(role: .developer))

        let agent = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        poolManager.release(agent)

        XCTAssertTrue(poolManager.hasAvailable(role: .developer))
        XCTAssertFalse(poolManager.hasAvailable(role: .tester))
    }

    // MARK: - Dynamic Sizing

    func testShrinkPool() {
        poolManager.config.shrinkCooldownSeconds = 0 // disable cooldown for testing

        let agents = (0..<5).map { _ in
            AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        }
        for a in agents { poolManager.release(a) }

        // Should fail because maxPerRole=3, so only 3 get in
        // Let's adjust
        poolManager.config.maxPerRole = 10
        poolManager.config.maxPoolSize = 10

        // Re-release
        poolManager.removeAll()
        for a in agents { poolManager.release(a) }
        XCTAssertEqual(poolManager.totalPooledCount, 5)

        poolManager.shrinkPool(to: 2)
        XCTAssertEqual(poolManager.totalPooledCount, 2)
    }

    func testEvaluateAndResize_CriticalPressure_ShrinksToMin() {
        poolManager.config.minPoolSize = 0
        poolManager.config.shrinkCooldownSeconds = 0
        poolManager.config.maxPerRole = 10
        poolManager.config.maxPoolSize = 10

        let agents = (0..<4).map { _ in
            AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        }
        for a in agents { poolManager.release(a) }

        poolManager.evaluateAndResize(resourcePressure: .critical)
        XCTAssertEqual(poolManager.totalPooledCount, 0)
    }

    func testEvaluateAndResize_HighPressure_ShrinksToHalf() {
        poolManager.config.maxPoolSize = 10
        poolManager.config.maxPerRole = 10
        poolManager.config.shrinkCooldownSeconds = 0

        let agents = (0..<6).map { _ in
            AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        }
        for a in agents { poolManager.release(a) }

        poolManager.evaluateAndResize(resourcePressure: .high)
        XCTAssertLessThanOrEqual(poolManager.totalPooledCount, 5)
    }

    // MARK: - Stats

    func testStats_HitRate() {
        let agent = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        poolManager.release(agent)

        // 1 hit
        _ = poolManager.acquire(role: .developer, parentId: UUID(), model: .sonnet)
        // 1 miss
        _ = poolManager.acquire(role: .developer, parentId: UUID(), model: .sonnet)

        XCTAssertEqual(poolManager.stats.hitRate, 0.5)
    }

    func testStats_PeakSize() {
        poolManager.config.maxPerRole = 10
        poolManager.config.maxPoolSize = 10

        let a1 = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        let a2 = AgentFactory.createSubAgent(parentId: UUID(), role: .researcher, model: .sonnet)
        let a3 = AgentFactory.createSubAgent(parentId: UUID(), role: .tester, model: .sonnet)

        poolManager.release(a1)
        poolManager.release(a2)
        poolManager.release(a3)

        XCTAssertEqual(poolManager.stats.peakSize, 3)

        _ = poolManager.acquire(role: .developer, parentId: UUID(), model: .sonnet)
        XCTAssertEqual(poolManager.stats.peakSize, 3) // peak doesn't decrease
    }

    // MARK: - Remove All

    func testRemoveAll() {
        poolManager.config.maxPerRole = 10
        let agent = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        poolManager.release(agent)
        XCTAssertEqual(poolManager.totalPooledCount, 1)

        poolManager.removeAll()
        XCTAssertEqual(poolManager.totalPooledCount, 0)
    }

    // MARK: - Multiple Roles

    func testMultipleRoles() {
        poolManager.config.maxPerRole = 5
        poolManager.config.maxPoolSize = 20

        let dev = AgentFactory.createSubAgent(parentId: UUID(), role: .developer, model: .sonnet)
        let res = AgentFactory.createSubAgent(parentId: UUID(), role: .researcher, model: .sonnet)
        let test = AgentFactory.createSubAgent(parentId: UUID(), role: .tester, model: .sonnet)

        poolManager.release(dev)
        poolManager.release(res)
        poolManager.release(test)

        XCTAssertEqual(poolManager.pooledCount(for: .developer), 1)
        XCTAssertEqual(poolManager.pooledCount(for: .researcher), 1)
        XCTAssertEqual(poolManager.pooledCount(for: .tester), 1)
        XCTAssertEqual(poolManager.totalPooledCount, 3)

        let acquiredDev = poolManager.acquire(role: .developer, parentId: UUID(), model: .sonnet)
        XCTAssertNotNil(acquiredDev)
        XCTAssertEqual(poolManager.pooledCount(for: .developer), 0)
        XCTAssertEqual(poolManager.totalPooledCount, 2)
    }
}
