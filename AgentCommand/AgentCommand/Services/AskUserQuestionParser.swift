import Foundation

/// Parses AskUserQuestion tool_use input JSON into structured data
struct AskUserQuestionParser {

    static func parse(
        inputJSON: String,
        taskId: UUID,
        agentId: UUID,
        sessionId: String
    ) -> AskUserQuestionData? {
        guard let data = inputJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let questionsArray = json["questions"] as? [[String: Any]]
        else { return nil }

        let questions: [UserQuestion] = questionsArray.compactMap { qDict in
            guard let questionText = qDict["question"] as? String else { return nil }
            let header = qDict["header"] as? String ?? ""
            let multiSelect = qDict["multiSelect"] as? Bool ?? false

            let options: [QuestionOption] = (qDict["options"] as? [[String: Any]] ?? []).compactMap { oDict in
                guard let label = oDict["label"] as? String else { return nil }
                let desc = oDict["description"] as? String
                return QuestionOption(label: label, description: desc)
            }

            return UserQuestion(
                question: questionText,
                header: header,
                options: options,
                multiSelect: multiSelect
            )
        }

        guard !questions.isEmpty else { return nil }

        return AskUserQuestionData(
            taskId: taskId,
            agentId: agentId,
            sessionId: sessionId,
            questions: questions
        )
    }
}
