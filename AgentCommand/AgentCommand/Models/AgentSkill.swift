import Foundation

// MARK: - Skill Categories (Real Agent Skill Domains)

enum SkillCategory: String, Codable, CaseIterable {
    case fileProcessing
    case codeExecution
    case dataAnalysis
    case webInteraction
    case contentCreation
    case systemIntegration
    case custom

    var displayName: String {
        switch self {
        case .fileProcessing: return "File Processing"
        case .codeExecution: return "Code Execution"
        case .dataAnalysis: return "Data Analysis"
        case .webInteraction: return "Web Interaction"
        case .contentCreation: return "Content Creation"
        case .systemIntegration: return "System Integration"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .fileProcessing: return "doc.on.doc.fill"
        case .codeExecution: return "terminal.fill"
        case .dataAnalysis: return "chart.bar.fill"
        case .webInteraction: return "globe"
        case .contentCreation: return "pencil.and.outline"
        case .systemIntegration: return "gearshape.2.fill"
        case .custom: return "puzzlepiece.extension.fill"
        }
    }

    var themeColor: String {
        switch self {
        case .fileProcessing: return "#FF9800"
        case .codeExecution: return "#4CAF50"
        case .dataAnalysis: return "#2196F3"
        case .webInteraction: return "#00BCD4"
        case .contentCreation: return "#E91E63"
        case .systemIntegration: return "#9C27B0"
        case .custom: return "#607D8B"
        }
    }
}

// MARK: - Skill Source

enum SkillSource: String, Codable, CaseIterable {
    case preBuilt
    case custom
    case community

    var displayName: String {
        switch self {
        case .preBuilt: return "Pre-built"
        case .custom: return "Custom"
        case .community: return "Community"
        }
    }
}

// MARK: - Skill Resource (Layer 3 - Bundled Files)

struct SkillResource: Codable, Hashable {
    let fileName: String
    let fileType: String
    let fileSizeBytes: Int64
    let description: String

    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeBytes)
    }

    var typeIcon: String {
        switch fileType.lowercased() {
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "md": return "doc.text.fill"
        case "json": return "curlybraces"
        case "pptx": return "rectangle.stack.fill"
        case "xlsx": return "tablecells.fill"
        case "docx": return "doc.richtext.fill"
        case "pdf": return "doc.fill"
        case "sh": return "terminal.fill"
        case "js", "ts": return "curlybraces.square.fill"
        default: return "doc"
        }
    }
}

// MARK: - Agent Skill (Based on SKILL.md Specification)

/// Represents a Claude Agent Skill following the three-tier loading architecture:
/// - Layer 1: Metadata (name, description) - always loaded
/// - Layer 2: Instructions (SKILL.md body) - loaded when triggered
/// - Layer 3: Resources (bundled scripts, templates) - loaded on demand
struct AgentSkill: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let category: SkillCategory
    let icon: String
    let version: String
    let author: String
    let source: SkillSource

    // Layer 2: Instructions
    var instructionsPreview: String?
    var instructionsFull: String?

    // Layer 3: Resources
    var resources: [SkillResource]

    // Metadata
    let createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var compatiblePlatforms: [String]
}

// MARK: - Skill Installation (Replaces AgentSkillAssignment)

/// Tracks which skills are installed and activated for a specific agent
struct SkillInstallation: Codable, Hashable {
    let skillId: String
    var isActive: Bool
    let installedAt: Date
    var lastUsedAt: Date?
    var usageCount: Int
}

// MARK: - Pre-built Skill Catalog

struct PreBuiltSkillCatalog {
    private static let now = Date()

    static let allSkills: [AgentSkill] = fileProcessingSkills + codeExecutionSkills + dataAnalysisSkills + webInteractionSkills + contentCreationSkills + systemIntegrationSkills

    // MARK: - File Processing

    static let fileProcessingSkills: [AgentSkill] = [
        AgentSkill(
            id: "ms-office:powerpoint", name: "PowerPoint",
            description: "Create and modify PowerPoint presentations with charts, images, and professional formatting. Generates .pptx files with custom layouts and themes.",
            category: .fileProcessing, icon: "rectangle.stack.fill",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Use python-pptx to create professional PowerPoint presentations. Supports slide layouts, charts, images, tables, and custom themes...",
            instructionsFull: """
            # PowerPoint Skill

            ## Quick Start
            Create presentations using python-pptx:
            ```python
            from pptx import Presentation
            prs = Presentation()
            slide = prs.slides.add_slide(prs.slide_layouts[0])
            slide.shapes.title.text = "Hello World"
            prs.save("output.pptx")
            ```

            ## Capabilities
            - Create slides with multiple layouts
            - Add charts (bar, line, pie)
            - Insert and resize images
            - Format text with fonts and colors
            - Apply themes and templates
            """,
            resources: [
                SkillResource(fileName: "create_presentation.py", fileType: "py", fileSizeBytes: 8200, description: "Main presentation creation script"),
                SkillResource(fileName: "base_template.pptx", fileType: "pptx", fileSizeBytes: 52400, description: "Default slide template"),
            ],
            createdAt: now, updatedAt: now,
            tags: ["powerpoint", "pptx", "presentation", "slides", "office"],
            compatiblePlatforms: ["api", "claude-ai"]
        ),
        AgentSkill(
            id: "ms-office:excel", name: "Excel",
            description: "Create spreadsheets, analyze data, and generate reports with charts. Manipulate .xlsx files with formulas, pivot tables, and visualizations.",
            category: .fileProcessing, icon: "tablecells.fill",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Use openpyxl to create and manipulate Excel spreadsheets. Supports formulas, charts, conditional formatting, and data analysis...",
            instructionsFull: nil,
            resources: [
                SkillResource(fileName: "create_spreadsheet.py", fileType: "py", fileSizeBytes: 6800, description: "Spreadsheet creation and manipulation script"),
            ],
            createdAt: now, updatedAt: now,
            tags: ["excel", "xlsx", "spreadsheet", "data", "charts", "office"],
            compatiblePlatforms: ["api", "claude-ai"]
        ),
        AgentSkill(
            id: "ms-office:word", name: "Word",
            description: "Create and edit Word documents with rich formatting, tables, headers, and styles. Generate professional .docx files.",
            category: .fileProcessing, icon: "doc.richtext.fill",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Use python-docx to create formatted Word documents. Supports paragraphs, tables, headers, footers, images, and custom styles...",
            instructionsFull: nil,
            resources: [
                SkillResource(fileName: "create_document.py", fileType: "py", fileSizeBytes: 5400, description: "Document creation script"),
            ],
            createdAt: now, updatedAt: now,
            tags: ["word", "docx", "document", "formatting", "office"],
            compatiblePlatforms: ["api", "claude-ai"]
        ),
        AgentSkill(
            id: "ms-office:pdf", name: "PDF",
            description: "Generate formatted PDF documents and reports. Extract text and tables from existing PDFs, fill forms, and merge documents.",
            category: .fileProcessing, icon: "doc.fill",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Use pdfplumber for extraction and reportlab for generation. Supports text extraction, table parsing, form filling, and PDF creation...",
            instructionsFull: """
            # PDF Processing

            ## Quick Start
            Extract text from PDFs:
            ```python
            import pdfplumber
            with pdfplumber.open("document.pdf") as pdf:
                text = pdf.pages[0].extract_text()
            ```

            ## Capabilities
            - Extract text and tables from PDF files
            - Generate formatted PDF reports
            - Fill PDF forms programmatically
            - Merge and split PDF documents
            """,
            resources: [
                SkillResource(fileName: "extract_pdf.py", fileType: "py", fileSizeBytes: 4200, description: "PDF text and table extraction"),
                SkillResource(fileName: "fill_form.py", fileType: "py", fileSizeBytes: 3800, description: "PDF form filling utility"),
                SkillResource(fileName: "FORMS.md", fileType: "md", fileSizeBytes: 2100, description: "Form filling guide"),
            ],
            createdAt: now, updatedAt: now,
            tags: ["pdf", "document", "extract", "forms", "report"],
            compatiblePlatforms: ["api", "claude-ai"]
        ),
    ]

    // MARK: - Code Execution

    static let codeExecutionSkills: [AgentSkill] = [
        AgentSkill(
            id: "code:python-repl", name: "Python REPL",
            description: "Execute Python code in a sandboxed environment with access to scientific computing, data manipulation, and visualization libraries.",
            category: .codeExecution, icon: "chevron.left.forwardslash.chevron.right",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Execute Python code with access to numpy, pandas, matplotlib, scipy, and other scientific libraries...",
            instructionsFull: nil,
            resources: [],
            createdAt: now, updatedAt: now,
            tags: ["python", "repl", "code", "execution", "scientific"],
            compatiblePlatforms: ["api", "claude-code", "claude-ai"]
        ),
        AgentSkill(
            id: "code:shell-script", name: "Shell Script",
            description: "Execute bash/shell commands for file manipulation, process management, system administration, and automation tasks.",
            category: .codeExecution, icon: "terminal.fill",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Execute shell commands in a bash environment. Supports file operations, piping, environment variables, and process control...",
            instructionsFull: nil,
            resources: [],
            createdAt: now, updatedAt: now,
            tags: ["bash", "shell", "terminal", "automation", "scripting"],
            compatiblePlatforms: ["api", "claude-code", "claude-ai", "agent-sdk"]
        ),
        AgentSkill(
            id: "code:node-runtime", name: "Node.js Runtime",
            description: "Execute JavaScript and TypeScript code in a Node.js environment with access to npm packages for web development and tooling.",
            category: .codeExecution, icon: "curlybraces.square.fill",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Execute JavaScript/TypeScript with Node.js. Supports ES modules, npm packages, async/await, and file system operations...",
            instructionsFull: nil,
            resources: [],
            createdAt: now, updatedAt: now,
            tags: ["javascript", "typescript", "node", "npm", "web"],
            compatiblePlatforms: ["api", "claude-code"]
        ),
    ]

    // MARK: - Data Analysis

    static let dataAnalysisSkills: [AgentSkill] = [
        AgentSkill(
            id: "data:csv-analyzer", name: "CSV Analyzer",
            description: "Parse, analyze, and transform CSV/TSV data files. Generate statistical summaries, detect patterns, and clean messy datasets.",
            category: .dataAnalysis, icon: "tablecells",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Use pandas to load, analyze, and transform CSV files. Supports statistical analysis, data cleaning, and format conversion...",
            instructionsFull: nil,
            resources: [
                SkillResource(fileName: "analyze_csv.py", fileType: "py", fileSizeBytes: 5600, description: "CSV analysis and transformation script"),
            ],
            createdAt: now, updatedAt: now,
            tags: ["csv", "data", "analysis", "pandas", "statistics"],
            compatiblePlatforms: ["api", "claude-ai"]
        ),
        AgentSkill(
            id: "data:chart-generator", name: "Chart Generator",
            description: "Create data visualizations including bar charts, line graphs, scatter plots, heatmaps, and interactive dashboards.",
            category: .dataAnalysis, icon: "chart.xyaxis.line",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Use matplotlib and seaborn to generate publication-quality charts. Supports customizable themes, annotations, and export formats...",
            instructionsFull: nil,
            resources: [
                SkillResource(fileName: "create_chart.py", fileType: "py", fileSizeBytes: 7200, description: "Chart generation with matplotlib/seaborn"),
            ],
            createdAt: now, updatedAt: now,
            tags: ["chart", "visualization", "graph", "matplotlib", "plot"],
            compatiblePlatforms: ["api", "claude-ai"]
        ),
    ]

    // MARK: - Web Interaction

    static let webInteractionSkills: [AgentSkill] = [
        AgentSkill(
            id: "web:search", name: "Web Search",
            description: "Search the web for up-to-date information, research topics, and find relevant documentation and resources.",
            category: .webInteraction, icon: "magnifyingglass",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Perform web searches to find current information. Best for factual queries, documentation lookup, and research tasks...",
            instructionsFull: nil,
            resources: [],
            createdAt: now, updatedAt: now,
            tags: ["search", "web", "research", "information"],
            compatiblePlatforms: ["claude-code", "claude-ai"]
        ),
        AgentSkill(
            id: "web:api-client", name: "API Client",
            description: "Make HTTP requests to REST APIs, parse JSON/XML responses, handle authentication, and chain API calls for complex workflows.",
            category: .webInteraction, icon: "network",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Use requests library to interact with REST APIs. Supports GET/POST/PUT/DELETE, authentication, pagination, and error handling...",
            instructionsFull: nil,
            resources: [
                SkillResource(fileName: "api_client.py", fileType: "py", fileSizeBytes: 4800, description: "HTTP client with retry and auth support"),
            ],
            createdAt: now, updatedAt: now,
            tags: ["api", "http", "rest", "json", "requests"],
            compatiblePlatforms: ["claude-code"]
        ),
    ]

    // MARK: - Content Creation

    static let contentCreationSkills: [AgentSkill] = [
        AgentSkill(
            id: "content:technical-writer", name: "Technical Writer",
            description: "Generate structured technical documentation, API references, architecture docs, and README files with proper formatting.",
            category: .contentCreation, icon: "doc.text.fill",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Create well-structured technical documents following industry best practices. Supports Markdown, reStructuredText, and API doc formats...",
            instructionsFull: nil,
            resources: [
                SkillResource(fileName: "TEMPLATES.md", fileType: "md", fileSizeBytes: 3200, description: "Documentation templates collection"),
            ],
            createdAt: now, updatedAt: now,
            tags: ["documentation", "technical", "writing", "markdown", "api-docs"],
            compatiblePlatforms: ["api", "claude-code", "claude-ai", "agent-sdk"]
        ),
        AgentSkill(
            id: "content:translator", name: "Translator",
            description: "Translate text between languages while preserving tone, technical accuracy, and cultural nuances. Supports 50+ languages.",
            category: .contentCreation, icon: "character.bubble.fill",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Provide high-quality translations preserving meaning, tone, and formatting. Handles technical terminology and cultural adaptation...",
            instructionsFull: nil,
            resources: [],
            createdAt: now, updatedAt: now,
            tags: ["translation", "language", "localization", "i18n"],
            compatiblePlatforms: ["api", "claude-code", "claude-ai", "agent-sdk"]
        ),
    ]

    // MARK: - System Integration

    static let systemIntegrationSkills: [AgentSkill] = [
        AgentSkill(
            id: "system:mcp-connector", name: "MCP Connector",
            description: "Connect to Model Context Protocol servers for extended tool access. Integrate with databases, file systems, and external services.",
            category: .systemIntegration, icon: "cable.connector",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Configure and connect to MCP servers to extend Claude's capabilities. Supports stdio and SSE transports, tool discovery, and resource access...",
            instructionsFull: nil,
            resources: [
                SkillResource(fileName: "mcp_config.json", fileType: "json", fileSizeBytes: 1200, description: "Sample MCP server configuration"),
            ],
            createdAt: now, updatedAt: now,
            tags: ["mcp", "integration", "tools", "protocol", "server"],
            compatiblePlatforms: ["claude-code", "agent-sdk"]
        ),
        AgentSkill(
            id: "system:git-operations", name: "Git Operations",
            description: "Perform version control operations including commits, branches, merges, rebases, and pull request management.",
            category: .systemIntegration, icon: "arrow.triangle.branch",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Execute git commands for version control. Supports branching strategies, conflict resolution, interactive rebase, and GitHub integration...",
            instructionsFull: nil,
            resources: [],
            createdAt: now, updatedAt: now,
            tags: ["git", "version-control", "github", "branch", "merge"],
            compatiblePlatforms: ["claude-code", "agent-sdk"]
        ),
        AgentSkill(
            id: "system:docker-manager", name: "Docker Manager",
            description: "Build, run, and manage Docker containers and images. Create Dockerfiles, compose stacks, and manage container networks.",
            category: .systemIntegration, icon: "shippingbox.fill",
            version: "1.0.0", author: "Anthropic", source: .preBuilt,
            instructionsPreview: "Manage Docker containers and images. Supports Dockerfile creation, multi-stage builds, docker-compose, and container orchestration...",
            instructionsFull: nil,
            resources: [
                SkillResource(fileName: "Dockerfile.template", fileType: "dockerfile", fileSizeBytes: 980, description: "Multi-stage Dockerfile template"),
            ],
            createdAt: now, updatedAt: now,
            tags: ["docker", "container", "devops", "deployment", "compose"],
            compatiblePlatforms: ["claude-code"]
        ),
    ]

    // MARK: - Lookup

    static func skill(byId id: String) -> AgentSkill? {
        allSkills.first { $0.id == id }
    }

    static func skills(for category: SkillCategory) -> [AgentSkill] {
        allSkills.filter { $0.category == category }
    }
}
