import Foundation

// MARK: - Template Categories

enum TemplateCategory: String, Codable, CaseIterable {
    case bugFix
    case feature
    case refactor
    case review
    case custom

    var displayName: String {
        switch self {
        case .bugFix: return "Bug Fix"
        case .feature: return "Feature"
        case .refactor: return "Refactor"
        case .review: return "Review"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .bugFix: return "ladybug.fill"
        case .feature: return "sparkles"
        case .refactor: return "arrow.triangle.2.circlepath"
        case .review: return "checkmark.shield.fill"
        case .custom: return "square.and.pencil"
        }
    }

    var themeColor: String {
        switch self {
        case .bugFix: return "#FF5722"
        case .feature: return "#4CAF50"
        case .refactor: return "#2196F3"
        case .review: return "#FF9800"
        case .custom: return "#9C27B0"
        }
    }
}

// MARK: - Template Variable

struct TemplateVariable: Codable, Hashable {
    let key: String
    var displayName: String
    var defaultValue: String
}

// MARK: - Prompt Template

struct PromptTemplate: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var description: String
    var category: TemplateCategory
    var content: String
    var variables: [TemplateVariable]
    var tags: [String]
    let isBuiltIn: Bool
    let createdAt: Date
    var updatedAt: Date

    /// Extract variable keys from content using {{variableName}} pattern
    static func extractVariables(from content: String) -> [String] {
        let pattern = "\\{\\{\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        var keys: [String] = []
        var seen = Set<String>()
        for match in matches {
            if let keyRange = Range(match.range(at: 1), in: content) {
                let key = String(content[keyRange])
                if !seen.contains(key) {
                    seen.insert(key)
                    keys.append(key)
                }
            }
        }
        return keys
    }

    /// Render the template content by replacing {{variable}} with provided values
    func render(with values: [String: String]) -> String {
        var result = content
        for variable in variables {
            let value = values[variable.key] ?? variable.defaultValue
            result = result.replacingOccurrences(of: "{{\(variable.key)}}", with: value)
            // Also handle spaces: {{ variable }}
            let pattern = "\\{\\{\\s*\(NSRegularExpression.escapedPattern(for: variable.key))\\s*\\}\\}"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: value)
            }
        }
        return result
    }
}

// MARK: - Pre-built Template Catalog

struct PreBuiltTemplateCatalog {
    private static let now = Date()

    static let allTemplates: [PromptTemplate] = bugFixTemplates + featureTemplates + refactorTemplates + reviewTemplates

    // MARK: - Bug Fix

    static let bugFixTemplates: [PromptTemplate] = [
        PromptTemplate(
            id: "builtin:bugfix-debug-error",
            name: "Debug Error",
            description: "Investigate and fix a specific error or exception in the codebase.",
            category: .bugFix,
            content: "I'm seeing an error: \"{{errorMessage}}\"\n\nIt occurs in {{filePath}}. Please investigate the root cause, explain what's going wrong, and fix it. Make sure the fix doesn't break any existing tests.",
            variables: [
                TemplateVariable(key: "errorMessage", displayName: "Error Message", defaultValue: ""),
                TemplateVariable(key: "filePath", displayName: "File Path", defaultValue: ""),
            ],
            tags: ["debug", "error", "fix"],
            isBuiltIn: true, createdAt: now, updatedAt: now
        ),
        PromptTemplate(
            id: "builtin:bugfix-test-failure",
            name: "Fix Test Failure",
            description: "Analyze and fix failing tests.",
            category: .bugFix,
            content: "The test {{testName}} is failing. Please run the test, analyze the failure, and fix the underlying issue. Don't just modify the test to pass — fix the actual bug in the source code.",
            variables: [
                TemplateVariable(key: "testName", displayName: "Test Name", defaultValue: ""),
            ],
            tags: ["test", "fix", "failure"],
            isBuiltIn: true, createdAt: now, updatedAt: now
        ),
        PromptTemplate(
            id: "builtin:bugfix-regression",
            name: "Fix Regression",
            description: "Identify and fix a regression bug introduced by recent changes.",
            category: .bugFix,
            content: "There's a regression: {{description}}. This worked before but is now broken. Please check recent git changes, identify what broke it, and fix it while preserving the intended new behavior.",
            variables: [
                TemplateVariable(key: "description", displayName: "Regression Description", defaultValue: ""),
            ],
            tags: ["regression", "fix", "git"],
            isBuiltIn: true, createdAt: now, updatedAt: now
        ),
    ]

    // MARK: - Feature

    static let featureTemplates: [PromptTemplate] = [
        PromptTemplate(
            id: "builtin:feature-new",
            name: "Add New Feature",
            description: "Implement a new feature from scratch with proper structure.",
            category: .feature,
            content: "Please implement the following feature: {{featureDescription}}\n\nRequirements:\n- {{requirements}}\n\nPlease follow existing code patterns and conventions in the project. Add appropriate error handling and ensure the feature integrates well with the existing architecture.",
            variables: [
                TemplateVariable(key: "featureDescription", displayName: "Feature Description", defaultValue: ""),
                TemplateVariable(key: "requirements", displayName: "Requirements", defaultValue: ""),
            ],
            tags: ["feature", "new", "implement"],
            isBuiltIn: true, createdAt: now, updatedAt: now
        ),
        PromptTemplate(
            id: "builtin:feature-api-endpoint",
            name: "Add API Endpoint",
            description: "Create a new API endpoint with validation and error handling.",
            category: .feature,
            content: "Create a new {{httpMethod}} API endpoint at {{endpointPath}}.\n\nPurpose: {{purpose}}\n\nPlease include input validation, proper error responses, and follow the existing API patterns in the project.",
            variables: [
                TemplateVariable(key: "httpMethod", displayName: "HTTP Method", defaultValue: "GET"),
                TemplateVariable(key: "endpointPath", displayName: "Endpoint Path", defaultValue: "/api/"),
                TemplateVariable(key: "purpose", displayName: "Purpose", defaultValue: ""),
            ],
            tags: ["api", "endpoint", "rest"],
            isBuiltIn: true, createdAt: now, updatedAt: now
        ),
        PromptTemplate(
            id: "builtin:feature-component",
            name: "Add UI Component",
            description: "Create a new reusable UI component.",
            category: .feature,
            content: "Create a new UI component called {{componentName}}.\n\nDescription: {{description}}\n\nIt should be reusable and follow the existing component patterns in the project. Include proper props/parameters and accessibility support.",
            variables: [
                TemplateVariable(key: "componentName", displayName: "Component Name", defaultValue: ""),
                TemplateVariable(key: "description", displayName: "Description", defaultValue: ""),
            ],
            tags: ["ui", "component", "frontend"],
            isBuiltIn: true, createdAt: now, updatedAt: now
        ),
    ]

    // MARK: - Refactor

    static let refactorTemplates: [PromptTemplate] = [
        PromptTemplate(
            id: "builtin:refactor-component",
            name: "Refactor Component",
            description: "Improve code structure and maintainability of a component.",
            category: .refactor,
            content: "Please refactor {{filePath}} to improve its code quality.\n\nSpecific concerns: {{concerns}}\n\nKeep the existing behavior unchanged. Ensure all existing tests still pass after refactoring.",
            variables: [
                TemplateVariable(key: "filePath", displayName: "File Path", defaultValue: ""),
                TemplateVariable(key: "concerns", displayName: "Specific Concerns", defaultValue: "readability, maintainability"),
            ],
            tags: ["refactor", "clean", "quality"],
            isBuiltIn: true, createdAt: now, updatedAt: now
        ),
        PromptTemplate(
            id: "builtin:refactor-performance",
            name: "Improve Performance",
            description: "Optimize code for better performance.",
            category: .refactor,
            content: "The {{area}} is slow or inefficient. Please profile the code, identify bottlenecks, and optimize performance. Explain what changes you made and why they improve performance.",
            variables: [
                TemplateVariable(key: "area", displayName: "Area to Optimize", defaultValue: ""),
            ],
            tags: ["performance", "optimize", "speed"],
            isBuiltIn: true, createdAt: now, updatedAt: now
        ),
    ]

    // MARK: - Review

    static let reviewTemplates: [PromptTemplate] = [
        PromptTemplate(
            id: "builtin:review-code",
            name: "Code Review",
            description: "Perform a thorough code review of recent changes.",
            category: .review,
            content: "Please review the code in {{filePath}}. Check for:\n- Correctness and edge cases\n- Code style and conventions\n- Potential bugs or security issues\n- Performance concerns\n- Test coverage\n\nProvide specific suggestions for improvement.",
            variables: [
                TemplateVariable(key: "filePath", displayName: "File Path", defaultValue: ""),
            ],
            tags: ["review", "quality", "feedback"],
            isBuiltIn: true, createdAt: now, updatedAt: now
        ),
        PromptTemplate(
            id: "builtin:review-security",
            name: "Security Audit",
            description: "Audit code for security vulnerabilities.",
            category: .review,
            content: "Please perform a security audit on {{scope}}. Check for OWASP Top 10 vulnerabilities, injection risks, authentication/authorization issues, data exposure, and any other security concerns. Provide remediation steps for any issues found.",
            variables: [
                TemplateVariable(key: "scope", displayName: "Audit Scope", defaultValue: "the entire project"),
            ],
            tags: ["security", "audit", "owasp"],
            isBuiltIn: true, createdAt: now, updatedAt: now
        ),
    ]

    // MARK: - Lookup

    static func template(byId id: String) -> PromptTemplate? {
        allTemplates.first { $0.id == id }
    }

    static func templates(for category: TemplateCategory) -> [PromptTemplate] {
        allTemplates.filter { $0.category == category }
    }
}
