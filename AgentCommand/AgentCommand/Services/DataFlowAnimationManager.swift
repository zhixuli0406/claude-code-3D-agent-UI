import Foundation
import Combine

// MARK: - J4: Data Flow Animation Manager

@MainActor
class DataFlowAnimationManager: ObservableObject {
    @Published var tokenFlows: [TokenFlowEvent] = []
    @Published var pipelineStages: [IOPipelineStage] = []
    @Published var toolCallChain: [ToolCallChainEntry] = []
    @Published var stats: DataFlowStats = DataFlowStats()
    @Published var isAnimating: Bool = false

    private var animationTimer: Timer?

    deinit {
        animationTimer?.invalidate()
    }

    func startAnimating() {
        isAnimating = true
        // Only generate sample data if no real data exists
        if tokenFlows.isEmpty && pipelineStages.isEmpty && toolCallChain.isEmpty {
            generateSampleData()
        }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickAnimation()
            }
        }
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        isAnimating = false
    }

    func recordTokenFlow(agentId: UUID, type: DataFlowType, tokenCount: Int) {
        let flow = TokenFlowEvent(
            id: UUID(),
            agentId: agentId,
            flowType: type,
            tokenCount: tokenCount,
            timestamp: Date()
        )
        tokenFlows.append(flow)
        // Keep only last 50 events
        if tokenFlows.count > 50 {
            tokenFlows.removeFirst(tokenFlows.count - 50)
        }
        updateStats()
    }

    func recordToolCall(agentId: UUID, toolName: String, input: String) {
        let entry = ToolCallChainEntry(
            id: UUID(),
            agentId: agentId,
            toolName: toolName,
            input: String(input.prefix(100)),
            timestamp: Date(),
            sequenceIndex: toolCallChain.count
        )
        toolCallChain.append(entry)
        // Keep only last 30 entries
        if toolCallChain.count > 30 {
            toolCallChain.removeFirst(toolCallChain.count - 30)
        }
        updateStats()
    }

    func completeToolCall(entryId: UUID, output: String, duration: TimeInterval) {
        if let idx = toolCallChain.firstIndex(where: { $0.id == entryId }) {
            toolCallChain[idx].output = String(output.prefix(100))
            toolCallChain[idx].duration = duration
        }
    }

    func updatePipelineStage(name: String, type: DataFlowType, status: PipelineStageStatus, dataSize: Int) {
        if let idx = pipelineStages.firstIndex(where: { $0.name == name }) {
            pipelineStages[idx].status = status
            pipelineStages[idx].dataSize = dataSize
            if status == .active && pipelineStages[idx].startedAt == nil {
                pipelineStages[idx].startedAt = Date()
            }
            if status == .completed {
                pipelineStages[idx].completedAt = Date()
            }
        } else {
            let stage = IOPipelineStage(
                id: UUID(),
                name: name,
                flowType: type,
                status: status,
                dataSize: dataSize,
                startedAt: status == .active ? Date() : nil
            )
            pipelineStages.append(stage)
        }
    }

    private func tickAnimation() {
        // Deactivate old flows
        let cutoff = Date().addingTimeInterval(-5)
        for i in tokenFlows.indices {
            if tokenFlows[i].timestamp < cutoff {
                tokenFlows[i].isActive = false
            }
        }
        updateStats()
    }

    private func generateSampleData() {
        let agentId = UUID()

        tokenFlows = [
            TokenFlowEvent(id: UUID(), agentId: agentId, flowType: .promptSend, tokenCount: 150, timestamp: Date().addingTimeInterval(-10)),
            TokenFlowEvent(id: UUID(), agentId: agentId, flowType: .tokenStream, tokenCount: 450, timestamp: Date().addingTimeInterval(-8)),
            TokenFlowEvent(id: UUID(), agentId: agentId, flowType: .toolCall, tokenCount: 80, timestamp: Date().addingTimeInterval(-5)),
            TokenFlowEvent(id: UUID(), agentId: agentId, flowType: .responseReceive, tokenCount: 320, timestamp: Date().addingTimeInterval(-2)),
        ]

        pipelineStages = [
            IOPipelineStage(id: UUID(), name: "Prompt Encode", flowType: .promptSend, status: .completed, dataSize: 150, startedAt: Date().addingTimeInterval(-12), completedAt: Date().addingTimeInterval(-10)),
            IOPipelineStage(id: UUID(), name: "API Request", flowType: .promptSend, status: .completed, dataSize: 150, startedAt: Date().addingTimeInterval(-10), completedAt: Date().addingTimeInterval(-8)),
            IOPipelineStage(id: UUID(), name: "Token Stream", flowType: .tokenStream, status: .active, dataSize: 450, startedAt: Date().addingTimeInterval(-8)),
            IOPipelineStage(id: UUID(), name: "Response Parse", flowType: .responseReceive, status: .pending, dataSize: 0),
        ]

        toolCallChain = [
            ToolCallChainEntry(id: UUID(), agentId: agentId, toolName: "Read", input: "AppState.swift", output: "1200 lines", duration: 0.3, timestamp: Date().addingTimeInterval(-6), sequenceIndex: 0),
            ToolCallChainEntry(id: UUID(), agentId: agentId, toolName: "Grep", input: "func toggle", output: "15 matches", duration: 0.2, timestamp: Date().addingTimeInterval(-4), sequenceIndex: 1),
            ToolCallChainEntry(id: UUID(), agentId: agentId, toolName: "Edit", input: "ContentView.swift", timestamp: Date().addingTimeInterval(-2), sequenceIndex: 2),
        ]

        updateStats()
    }

    private func updateStats() {
        stats.totalTokensIn = tokenFlows.filter { $0.flowType == .promptSend }.reduce(0) { $0 + $1.tokenCount }
        stats.totalTokensOut = tokenFlows.filter { $0.flowType == .responseReceive || $0.flowType == .tokenStream }.reduce(0) { $0 + $1.tokenCount }
        stats.totalToolCalls = toolCallChain.count
        let durations = toolCallChain.compactMap { $0.duration }
        stats.avgResponseTime = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        stats.activeFlows = tokenFlows.filter { $0.isActive }.count
    }
}
