import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhTW = "zh-TW"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zhTW: return "繁體中文"
        case .en: return "English"
        }
    }
}

enum L10nKey: String {
    // Toolbar
    case theme, loadConfig, pause, start, reset, language
    case helpChangeTheme, helpLoadConfig
    case helpPauseSimulation, helpStartSimulation, helpResetSimulation

    // SceneSelectionView
    case agentCommand, selectYourEnvironment, enter, themeCanBeChangedLater

    // SidePanelView
    case agentCommandTitle, selectAnAgent, clickOnAgentHelpText

    // AgentDetailView
    case subAgents, subAgent, assignedTasks, noTasksAssigned

    // TaskListView
    case allTasks, subtasks

    // AgentHierarchyView
    case agentHierarchy

    // ProgressOverlay
    case running, idle, progress
    case pnd, wrk, don, err

    // MonitorBuilder
    case agentCommandVersion, systemReady

    // AgentStatus
    case statusIdle, statusWorking, statusThinking, statusCompleted, statusError

    // TaskStatus
    case taskPending, taskInProgress, taskCompleted, taskFailed

    // AgentRole
    case roleCommander, roleDeveloper, roleResearcher
    case roleReviewer, roleTester, roleDesigner

    // SceneTheme
    case themeCommandCenter, themeCommandCenterDesc
    case themeFloatingIslands, themeFloatingIslandsDesc
    case themeDungeon, themeDungeonDesc
    case themeSpaceStation, themeSpaceStationDesc

    // TaskPriority
    case priorityLow, priorityMedium, priorityHigh, priorityCritical

    // Prompt input
    case typeTaskPrompt, send, assignedTo, noAgentsAvailable, taskCreated

    // CLI integration
    case executionMode, simulation, liveCLI
    case workspace, addWorkspace, removeWorkspace, noWorkspace
    case cliOutput, cliRunning, cliCompleted, cliFailed, cliCancelled
    case live, sim, cancel
}

struct L10n {
    static func string(for key: L10nKey, language: AppLanguage) -> String {
        translations[language]?[key] ?? key.rawValue
    }

    private static let translations: [AppLanguage: [L10nKey: String]] = [
        .zhTW: zhTW,
        .en: en
    ]

    // MARK: - 繁體中文

    private static let zhTW: [L10nKey: String] = [
        // Toolbar
        .theme: "主題",
        .loadConfig: "載入設定",
        .pause: "暫停",
        .start: "開始",
        .reset: "重置",
        .language: "語言",
        .helpChangeTheme: "變更場景主題",
        .helpLoadConfig: "載入範例設定",
        .helpPauseSimulation: "暫停模擬",
        .helpStartSimulation: "開始模擬",
        .helpResetSimulation: "重置模擬",

        // SceneSelectionView
        .agentCommand: "AGENT COMMAND",
        .selectYourEnvironment: "選擇您的環境",
        .enter: "進入",
        .themeCanBeChangedLater: "主題可稍後從工具列變更",

        // SidePanelView
        .agentCommandTitle: "Agent Command",
        .selectAnAgent: "選擇一個代理",
        .clickOnAgentHelpText: "點擊 3D 角色或從上方層級中選擇",

        // AgentDetailView
        .subAgents: "子代理",
        .subAgent: "子代理",
        .assignedTasks: "已指派任務",
        .noTasksAssigned: "尚未指派任務",

        // TaskListView
        .allTasks: "所有任務",
        .subtasks: "子任務",

        // AgentHierarchyView
        .agentHierarchy: "代理層級",

        // ProgressOverlay
        .running: "運行中",
        .idle: "閒置",
        .progress: "進度",
        .pnd: "待辦",
        .wrk: "工作",
        .don: "完成",
        .err: "錯誤",

        // MonitorBuilder
        .agentCommandVersion: "AGENT COMMAND v1.0",
        .systemReady: "> 系統就緒",

        // AgentStatus
        .statusIdle: "閒置",
        .statusWorking: "工作中",
        .statusThinking: "思考中",
        .statusCompleted: "已完成",
        .statusError: "錯誤",

        // TaskStatus
        .taskPending: "待處理",
        .taskInProgress: "進行中",
        .taskCompleted: "已完成",
        .taskFailed: "失敗",

        // AgentRole
        .roleCommander: "指揮官",
        .roleDeveloper: "開發者",
        .roleResearcher: "研究員",
        .roleReviewer: "審核員",
        .roleTester: "測試員",
        .roleDesigner: "設計師",

        // SceneTheme
        .themeCommandCenter: "指揮中心",
        .themeCommandCenterDesc: "暗色調高科技辦公室，配備螢幕、辦公桌及霓虹燈飾。",
        .themeFloatingIslands: "浮空島嶼",
        .themeFloatingIslandsDesc: "在天空中漂浮的體素島嶼，由橋樑連接，穿梭雲間。",
        .themeDungeon: "地下城",
        .themeDungeonDesc: "地下石造地牢，配備火把照明與寶箱。",
        .themeSpaceStation: "太空站",
        .themeSpaceStationDesc: "金屬軌道站，配備全息顯示器及星空景觀。",

        // TaskPriority
        .priorityLow: "低",
        .priorityMedium: "中",
        .priorityHigh: "高",
        .priorityCritical: "緊急",

        // Prompt
        .typeTaskPrompt: "輸入任務指令...",
        .send: "送出",
        .assignedTo: "指派給",
        .noAgentsAvailable: "無可用代理",
        .taskCreated: "任務已建立",

        // CLI
        .executionMode: "執行模式",
        .simulation: "模擬",
        .liveCLI: "即時 CLI",
        .workspace: "工作區",
        .addWorkspace: "新增工作區...",
        .removeWorkspace: "移除目前工作區",
        .noWorkspace: "無工作區",
        .cliOutput: "CLI 輸出",
        .cliRunning: "CLI 執行中",
        .cliCompleted: "CLI 已完成",
        .cliFailed: "CLI 失敗",
        .cliCancelled: "CLI 已取消",
        .live: "即時",
        .sim: "模擬",
        .cancel: "取消",
    ]

    // MARK: - English

    private static let en: [L10nKey: String] = [
        // Toolbar
        .theme: "Theme",
        .loadConfig: "Load Config",
        .pause: "Pause",
        .start: "Start",
        .reset: "Reset",
        .language: "Language",
        .helpChangeTheme: "Change scene theme",
        .helpLoadConfig: "Load sample configuration",
        .helpPauseSimulation: "Pause simulation",
        .helpStartSimulation: "Start simulation",
        .helpResetSimulation: "Reset simulation",

        // SceneSelectionView
        .agentCommand: "AGENT COMMAND",
        .selectYourEnvironment: "Select Your Environment",
        .enter: "Enter",
        .themeCanBeChangedLater: "Theme can be changed later from the toolbar",

        // SidePanelView
        .agentCommandTitle: "Agent Command",
        .selectAnAgent: "Select an agent",
        .clickOnAgentHelpText: "Click on a 3D character or select from the hierarchy above",

        // AgentDetailView
        .subAgents: "Sub-Agents",
        .subAgent: "Sub-Agent",
        .assignedTasks: "Assigned Tasks",
        .noTasksAssigned: "No tasks assigned",

        // TaskListView
        .allTasks: "All Tasks",
        .subtasks: "Subtasks",

        // AgentHierarchyView
        .agentHierarchy: "Agent Hierarchy",

        // ProgressOverlay
        .running: "RUNNING",
        .idle: "IDLE",
        .progress: "PROGRESS",
        .pnd: "PND",
        .wrk: "WRK",
        .don: "DON",
        .err: "ERR",

        // MonitorBuilder
        .agentCommandVersion: "AGENT COMMAND v1.0",
        .systemReady: "> System Ready",

        // AgentStatus
        .statusIdle: "Idle",
        .statusWorking: "Working",
        .statusThinking: "Thinking",
        .statusCompleted: "Completed",
        .statusError: "Error",

        // TaskStatus
        .taskPending: "Pending",
        .taskInProgress: "In Progress",
        .taskCompleted: "Completed",
        .taskFailed: "Failed",

        // AgentRole
        .roleCommander: "Commander",
        .roleDeveloper: "Developer",
        .roleResearcher: "Researcher",
        .roleReviewer: "Reviewer",
        .roleTester: "Tester",
        .roleDesigner: "Designer",

        // SceneTheme
        .themeCommandCenter: "Command Center",
        .themeCommandCenterDesc: "A dark-themed hi-tech office with monitors, desks, and neon accents.",
        .themeFloatingIslands: "Floating Islands",
        .themeFloatingIslandsDesc: "Voxel islands floating in the sky, connected by bridges among the clouds.",
        .themeDungeon: "Dungeon",
        .themeDungeonDesc: "An underground stone dungeon with torch lighting and treasure chests.",
        .themeSpaceStation: "Space Station",
        .themeSpaceStationDesc: "A metallic orbital station with holographic displays and starfield views.",

        // TaskPriority
        .priorityLow: "Low",
        .priorityMedium: "Medium",
        .priorityHigh: "High",
        .priorityCritical: "Critical",

        // Prompt
        .typeTaskPrompt: "Type a task prompt...",
        .send: "Send",
        .assignedTo: "Assigned to",
        .noAgentsAvailable: "No agents available",
        .taskCreated: "Task created",

        // CLI
        .executionMode: "Execution Mode",
        .simulation: "Simulation",
        .liveCLI: "Live CLI",
        .workspace: "Workspace",
        .addWorkspace: "Add Workspace...",
        .removeWorkspace: "Remove Current",
        .noWorkspace: "No Workspace",
        .cliOutput: "CLI Output",
        .cliRunning: "CLI Running",
        .cliCompleted: "CLI Completed",
        .cliFailed: "CLI Failed",
        .cliCancelled: "CLI Cancelled",
        .live: "LIVE",
        .sim: "SIM",
        .cancel: "Cancel",
    ]
}
