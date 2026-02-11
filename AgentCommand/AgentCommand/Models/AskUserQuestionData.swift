import Foundation

/// Parsed AskUserQuestion payload from CLI stream-json
struct AskUserQuestionData: Identifiable {
    let id: UUID = UUID()
    let taskId: UUID
    let agentId: UUID
    let sessionId: String
    let questions: [UserQuestion]
}

struct UserQuestion: Identifiable {
    let id: UUID = UUID()
    let question: String
    let header: String
    let options: [QuestionOption]
    let multiSelect: Bool
}

struct QuestionOption: Identifiable, Hashable {
    let id: UUID = UUID()
    let label: String
    let description: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: QuestionOption, rhs: QuestionOption) -> Bool {
        lhs.id == rhs.id
    }
}

/// User's answer to a single question
struct UserQuestionAnswer {
    let questionId: UUID
    let selectedOptions: [String]
    let customText: String?
}
