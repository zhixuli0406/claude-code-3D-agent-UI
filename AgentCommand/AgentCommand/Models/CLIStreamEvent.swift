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

        case ("result", _):
            // Determine if this is an error result:
            // - subtype == "error"
            // - is_error == true (Bool or Int/Number)
            let isError: Bool = {
                if subtype == "error" { return true }
                if let boolVal = json["is_error"] as? Bool { return boolVal }
                if let numVal = json["is_error"] as? NSNumber { return numVal.boolValue }
                return false
            }()

            if isError {
                let error = json["error"] as? String
                    ?? json["error_message"] as? String
                    ?? json["result"] as? String
                    ?? json["message"] as? String
                if error == nil {
                    // Log the raw JSON so we can diagnose unexpected error formats
                    if let rawStr = String(data: data, encoding: .utf8) {
                        print("[CLIStreamEvent] Error result with no recognized error field. Raw JSON: \(String(rawStr.prefix(1000)))")
                    }
                }
                return .resultError(error: error ?? "Unknown error")
            } else {
                let result = json["result"] as? String ?? ""
                let cost = json["cost_usd"] as? Double
                let duration = json["duration_ms"] as? Int
                let session = json["session_id"] as? String
                return .resultSuccess(result: result, costUSD: cost, durationMs: duration, sessionId: session)
            }

        default:
            return .unknown(type: type)
        }
    }
}
