import Foundation

/// Represents a single JSON event from `claude -p --output-format stream-json`
enum CLIStreamEvent {
    case system(sessionId: String?)
    case assistantText(text: String)
    case assistantToolUse(tool: String, input: String)
    case toolResult(tool: String, output: String)
    case resultSuccess(result: String, costUSD: Double?, durationMs: Int?, sessionId: String?)
    case resultError(error: String)
    case unknown(type: String)

    /// Parse a raw JSON line from the stream into a CLIStreamEvent
    static func parse(from data: Data) -> CLIStreamEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        let subtype = json["subtype"] as? String

        switch (type, subtype) {
        case ("system", _):
            let sessionId = json["session_id"] as? String
            return .system(sessionId: sessionId)

        case ("assistant", _):
            // assistant messages contain content blocks
            if let message = json["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for block in content {
                    let blockType = block["type"] as? String
                    if blockType == "text", let text = block["text"] as? String {
                        return .assistantText(text: text)
                    }
                    if blockType == "tool_use" {
                        let tool = block["name"] as? String ?? "unknown"
                        let input = block["input"] as? [String: Any]
                        let inputStr: String
                        if let inputData = try? JSONSerialization.data(withJSONObject: input ?? [:]),
                           let s = String(data: inputData, encoding: .utf8) {
                            inputStr = s
                        } else {
                            inputStr = ""
                        }
                        return .assistantToolUse(tool: tool, input: inputStr)
                    }
                }
            }
            return .unknown(type: "assistant")

        case ("user", _):
            // user messages typically contain tool_result blocks
            if let message = json["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for block in content {
                    if block["type"] as? String == "tool_result" {
                        let output = block["content"] as? String ?? ""
                        return .toolResult(tool: "tool_result", output: output)
                    }
                }
            }
            return .unknown(type: "user")

        case ("result", "success"),
             ("result", _) where json["is_error"] as? Bool == false:
            let result = json["result"] as? String ?? ""
            let cost = json["cost_usd"] as? Double
            let duration = json["duration_ms"] as? Int
            let session = json["session_id"] as? String
            return .resultSuccess(result: result, costUSD: cost, durationMs: duration, sessionId: session)

        case ("result", "error"),
             ("result", _) where json["is_error"] as? Bool == true:
            let error = json["error"] as? String ?? json["result"] as? String ?? "Unknown error"
            return .resultError(error: error)

        default:
            return .unknown(type: type)
        }
    }
}
