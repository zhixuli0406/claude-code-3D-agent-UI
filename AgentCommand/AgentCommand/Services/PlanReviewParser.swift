import Foundation

/// Parses ExitPlanMode tool_use input and reads the plan file
struct PlanReviewParser {

    static func parse(
        inputJSON: String,
        planContent: String,
        taskId: UUID,
        agentId: UUID,
        sessionId: String
    ) -> PlanReviewData? {
        let allowedPrompts = parseAllowedPrompts(from: inputJSON)

        guard !planContent.isEmpty else { return nil }

        return PlanReviewData(
            taskId: taskId,
            agentId: agentId,
            sessionId: sessionId,
            planContent: planContent,
            allowedPrompts: allowedPrompts
        )
    }

    /// Try to read the most recently modified plan file from ~/.claude/plans/
    static func readLatestPlanFile() -> String? {
        let planDir = NSHomeDirectory() + "/.claude/plans"
        let fm = FileManager.default

        guard fm.fileExists(atPath: planDir),
              let files = try? fm.contentsOfDirectory(atPath: planDir) else {
            return nil
        }

        let mdFiles = files.filter { $0.hasSuffix(".md") }
        guard !mdFiles.isEmpty else { return nil }

        // Find the most recently modified .md file
        var latestFile: String?
        var latestDate: Date = .distantPast

        for file in mdFiles {
            let path = planDir + "/" + file
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let modDate = attrs[.modificationDate] as? Date,
               modDate > latestDate {
                latestDate = modDate
                latestFile = path
            }
        }

        guard let path = latestFile else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    // MARK: - Private

    private static func parseAllowedPrompts(from inputJSON: String) -> [PlanAllowedPrompt] {
        guard let data = inputJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let prompts = json["allowedPrompts"] as? [[String: Any]]
        else { return [] }

        return prompts.compactMap { dict in
            guard let tool = dict["tool"] as? String,
                  let prompt = dict["prompt"] as? String else { return nil }
            return PlanAllowedPrompt(tool: tool, prompt: prompt)
        }
    }
}
