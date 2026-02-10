import Foundation

enum CommandDangerLevel {
    case safe
    case dangerous(reason: String)
}

struct DangerousCommandClassifier {
    private static let dangerousPatterns: [(pattern: String, reason: String)] = [
        ("rm\\s+-rf", "Recursive force delete (rm -rf)"),
        ("rm\\s+-r\\s", "Recursive delete (rm -r)"),
        ("rmdir", "Directory removal (rmdir)"),
        ("git\\s+push\\s+--force", "Force push (git push --force)"),
        ("git\\s+push\\s+-f", "Force push (git push -f)"),
        ("git\\s+reset\\s+--hard", "Hard reset (git reset --hard)"),
        ("git\\s+clean\\s+-f", "Force clean (git clean -f)"),
        ("DROP\\s+TABLE", "SQL DROP TABLE"),
        ("DROP\\s+DATABASE", "SQL DROP DATABASE"),
        ("TRUNCATE\\s+TABLE", "SQL TRUNCATE TABLE"),
        ("DELETE\\s+FROM\\s+\\w+\\s*$", "SQL DELETE without WHERE"),
        ("sudo\\s+", "Elevated privileges (sudo)"),
        ("chmod\\s+777", "World-writable permissions (chmod 777)"),
        ("mkfs\\.", "Format filesystem (mkfs)"),
        ("dd\\s+if=", "Raw disk write (dd)"),
        ("> /dev/", "Direct device write"),
        (":(){ :|:& };:", "Fork bomb"),
        ("curl.*\\|.*sh", "Pipe remote script to shell"),
        ("wget.*\\|.*sh", "Pipe remote script to shell"),
    ]

    static func classify(tool: String, input: String) -> CommandDangerLevel {
        let toolsToCheck = ["Bash", "bash", "shell", "terminal", "Execute"]
        guard toolsToCheck.contains(where: { tool.localizedCaseInsensitiveContains($0) }) || tool == "Bash" else {
            return .safe
        }

        let combined = input.lowercased()
        for (pattern, reason) in dangerousPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil {
                return .dangerous(reason: reason)
            }
            // Also check lowercased for simple string matches
            if combined.contains(pattern.lowercased().replacingOccurrences(of: "\\s+", with: " ").replacingOccurrences(of: "\\s", with: " ")) {
                continue // regex already checked
            }
        }

        return .safe
    }
}
