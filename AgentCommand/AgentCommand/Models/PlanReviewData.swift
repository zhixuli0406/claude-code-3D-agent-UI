import Foundation

/// Parsed ExitPlanMode payload for plan review
struct PlanReviewData: Identifiable {
    let id: UUID = UUID()
    let taskId: UUID
    let agentId: UUID
    let sessionId: String
    let planContent: String
    let allowedPrompts: [PlanAllowedPrompt]
}

struct PlanAllowedPrompt: Identifiable {
    let id: UUID = UUID()
    let tool: String
    let prompt: String
}
