import Foundation

struct DangerousCommandAlertData: Identifiable {
    let id: UUID = UUID()
    let taskId: UUID
    let agentId: UUID
    let tool: String
    let input: String
    let reason: String
}
