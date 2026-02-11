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
    case theme, loadConfig, language
    case helpChangeTheme, helpLoadConfig

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
    case statusIdle, statusWorking, statusThinking, statusCompleted, statusError, statusRequestingPermission

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
    case themeCyberpunkCity, themeCyberpunkCityDesc
    case themeMedievalCastle, themeMedievalCastleDesc
    case themeUnderwaterLab, themeUnderwaterLabDesc
    case themeJapaneseGarden, themeJapaneseGardenDesc
    case themeMinecraftOverworld, themeMinecraftOverworldDesc

    // TaskPriority
    case priorityLow, priorityMedium, priorityHigh, priorityCritical

    // Prompt input
    case typeTaskPrompt, send, assignedTo, noAgentsAvailable, taskCreated

    // CLI integration
    case workspace, addWorkspace, removeWorkspace, noWorkspace
    case cliOutput, cliRunning, cliCompleted, cliFailed, cliCancelled
    case live, cancel

    // Team
    case taskTeam, teamLead

    // Copy
    case copyAll, copyEntry, copied

    // Dangerous command
    case dangerousCommandDetected, continueExecution, cancelTask

    // AskUserQuestion
    case statusWaitingForAnswer
    case askUserQuestion, submitAnswer, customAnswer, skipQuestion

    // Plan review
    case statusReviewingPlan
    case planReview, approvePlan, rejectPlan, planActions, planRejectionFeedback

    // Multi-team
    case teamLabel, selectTeam, allTeams
    case newTeamAutoCreated, noAgentsYet

    // Sound
    case sound, helpToggleSound

    // Achievements & Stats
    case achievements, helpAchievements
    case achievementGallery, achievementUnlocked
    case agentStats, noStatsYet
    case level, nextUnlock

    // B3: Stats Dashboard
    case statsDashboard, helpStatsDashboard
    case totalCompleted, successRateLabel, avgTime, totalXPLabel
    case dailyTasks, dailyXP, noChartData
    case activeHoursTitle, activeHoursDesc

    // B4: Cosmetic Shop
    case cosmeticShop, helpCosmeticShop
    case coins, totalEarned, owned
    case purchase, equip, unequip, equipped
    case insufficientFunds, alreadyOwned, notAvailable
    case selectAgent
    case seasonalEvent, seasonalNotActive

    // B6: Mini-map & Exploration
    case miniMap, helpMiniMap
    case explorationProgress
    case easterEggFound, loreDiscovered
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
        .language: "語言",
        .helpChangeTheme: "變更場景主題",
        .helpLoadConfig: "載入範例設定",

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
        .statusRequestingPermission: "請求許可",

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
        .themeCyberpunkCity: "賽博龐克城市",
        .themeCyberpunkCityDesc: "霓虹燈照亮的街道，配備全息廣告牌與雨水浸潤的巷弄。",
        .themeMedievalCastle: "中世紀城堡",
        .themeMedievalCastleDesc: "宏偉的王座大廳，配備石牆、旗幟與騎士代理。",
        .themeUnderwaterLab: "水下實驗室",
        .themeUnderwaterLabDesc: "潛水艇研究基地，配備氣泡、魚群與生物發光效果。",
        .themeJapaneseGarden: "日式庭園",
        .themeJapaneseGardenDesc: "寧靜的禪園，配備櫻花、石燈籠與錦鯉池。",
        .themeMinecraftOverworld: "像素世界",
        .themeMinecraftOverworldDesc: "經典體素地形，配備草方塊、樹木與像素化天空。",

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
        .cancel: "取消",

        // Team
        .taskTeam: "任務團隊",
        .teamLead: "主導",

        // Copy
        .copyAll: "全部複製",
        .copyEntry: "複製",
        .copied: "已複製",

        // Dangerous command
        .dangerousCommandDetected: "偵測到危險指令",
        .continueExecution: "繼續執行",
        .cancelTask: "取消任務",

        // AskUserQuestion
        .statusWaitingForAnswer: "等待回答",
        .askUserQuestion: "代理提問",
        .submitAnswer: "提交回答",
        .customAnswer: "自訂回答",
        .skipQuestion: "跳過",

        // Plan review
        .statusReviewingPlan: "審核計畫",
        .planReview: "計畫審核",
        .approvePlan: "批准計畫",
        .rejectPlan: "拒絕",
        .planActions: "計畫行動",
        .planRejectionFeedback: "拒絕原因（選填）",

        // Multi-team
        .teamLabel: "團隊",
        .selectTeam: "選擇團隊",
        .allTeams: "所有團隊",
        .newTeamAutoCreated: "新團隊將自動建立",
        .noAgentsYet: "尚無代理團隊",

        // Sound
        .sound: "音效",
        .helpToggleSound: "開啟/關閉音效",

        // Achievements & Stats
        .achievements: "成就",
        .helpAchievements: "查看成就展覽",
        .achievementGallery: "成就展覽",
        .achievementUnlocked: "成就解鎖！",
        .agentStats: "代理統計",
        .noStatsYet: "尚無統計資料。完成任務以獲取經驗值！",
        .level: "等級",
        .nextUnlock: "下次解鎖",

        // B3: Stats Dashboard
        .statsDashboard: "統計儀表板",
        .helpStatsDashboard: "查看代理統計儀表板",
        .totalCompleted: "已完成",
        .successRateLabel: "成功率",
        .avgTime: "平均時間",
        .totalXPLabel: "總經驗值",
        .dailyTasks: "每日任務",
        .dailyXP: "每日經驗值",
        .noChartData: "尚無圖表資料。完成任務以生成統計圖表。",
        .activeHoursTitle: "活躍時段熱力圖",
        .activeHoursDesc: "顯示您在一天中哪些時段最活躍",

        // B4: Cosmetic Shop
        .cosmeticShop: "外觀商店",
        .helpCosmeticShop: "購買與裝備外觀物品",
        .coins: "金幣",
        .totalEarned: "總計獲得",
        .owned: "已擁有",
        .purchase: "購買",
        .equip: "裝備",
        .unequip: "卸下",
        .equipped: "已裝備",
        .insufficientFunds: "金幣不足！完成任務以獲取更多金幣。",
        .alreadyOwned: "您已擁有此物品。",
        .notAvailable: "此物品目前不可用。",
        .selectAgent: "選擇代理",
        .seasonalEvent: "季節活動",
        .seasonalNotActive: "目前無季節活動。在節日期間再來查看！",

        // B6: Mini-map & Exploration
        .miniMap: "小地圖",
        .helpMiniMap: "顯示/隱藏小地圖",
        .explorationProgress: "探索進度",
        .easterEggFound: "發現彩蛋！",
        .loreDiscovered: "發現傳說！",
    ]

    // MARK: - English

    private static let en: [L10nKey: String] = [
        // Toolbar
        .theme: "Theme",
        .loadConfig: "Load Config",
        .language: "Language",
        .helpChangeTheme: "Change scene theme",
        .helpLoadConfig: "Load sample configuration",

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
        .statusRequestingPermission: "Requesting Permission",

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
        .themeCyberpunkCity: "Cyberpunk City",
        .themeCyberpunkCityDesc: "Neon-lit streets with holographic billboards and rain-soaked alleys.",
        .themeMedievalCastle: "Medieval Castle",
        .themeMedievalCastleDesc: "A grand throne room with stone walls, banners, and knight agents.",
        .themeUnderwaterLab: "Underwater Lab",
        .themeUnderwaterLabDesc: "A submarine research base with bubbles, fish, and bioluminescent glow.",
        .themeJapaneseGarden: "Japanese Garden",
        .themeJapaneseGardenDesc: "A serene zen garden with cherry blossoms, stone lanterns, and koi ponds.",
        .themeMinecraftOverworld: "Minecraft Overworld",
        .themeMinecraftOverworldDesc: "A classic voxel terrain with grass blocks, trees, and pixelated skies.",

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
        .cancel: "Cancel",

        // Team
        .taskTeam: "Task Team",
        .teamLead: "LEAD",

        // Copy
        .copyAll: "Copy All",
        .copyEntry: "Copy",
        .copied: "Copied",

        // Dangerous command
        .dangerousCommandDetected: "Dangerous Command Detected",
        .continueExecution: "Continue",
        .cancelTask: "Cancel Task",

        // AskUserQuestion
        .statusWaitingForAnswer: "Waiting for Answer",
        .askUserQuestion: "Agent Question",
        .submitAnswer: "Submit",
        .customAnswer: "Custom Answer",
        .skipQuestion: "Skip",

        // Plan review
        .statusReviewingPlan: "Reviewing Plan",
        .planReview: "Plan Review",
        .approvePlan: "Approve Plan",
        .rejectPlan: "Reject",
        .planActions: "Planned Actions",
        .planRejectionFeedback: "Rejection reason (optional)",

        // Multi-team
        .teamLabel: "Team",
        .selectTeam: "Select Team",
        .allTeams: "All Teams",
        .newTeamAutoCreated: "New team will be created",
        .noAgentsYet: "No agent teams yet",

        // Sound
        .sound: "Sound",
        .helpToggleSound: "Toggle sound effects",

        // Achievements & Stats
        .achievements: "Achievements",
        .helpAchievements: "View achievement gallery",
        .achievementGallery: "Achievement Gallery",
        .achievementUnlocked: "Achievement Unlocked!",
        .agentStats: "Agent Stats",
        .noStatsYet: "No stats yet. Complete tasks to earn XP!",
        .level: "Level",
        .nextUnlock: "Next Unlock",

        // B3: Stats Dashboard
        .statsDashboard: "Stats Dashboard",
        .helpStatsDashboard: "View agent stats dashboard",
        .totalCompleted: "Completed",
        .successRateLabel: "Success Rate",
        .avgTime: "Avg Time",
        .totalXPLabel: "Total XP",
        .dailyTasks: "Daily Tasks",
        .dailyXP: "Daily XP",
        .noChartData: "No chart data yet. Complete tasks to generate charts.",
        .activeHoursTitle: "Active Hours Heatmap",
        .activeHoursDesc: "Shows when you're most active throughout the day",

        // B4: Cosmetic Shop
        .cosmeticShop: "Cosmetic Shop",
        .helpCosmeticShop: "Purchase and equip cosmetic items",
        .coins: "Coins",
        .totalEarned: "Total Earned",
        .owned: "Owned",
        .purchase: "Purchase",
        .equip: "Equip",
        .unequip: "Unequip",
        .equipped: "Equipped",
        .insufficientFunds: "Not enough coins! Earn more by completing tasks.",
        .alreadyOwned: "You already own this item.",
        .notAvailable: "This item is not currently available.",
        .selectAgent: "Select Agent",
        .seasonalEvent: "Seasonal Event",
        .seasonalNotActive: "No seasonal events active. Check back during holidays!",

        // B6: Mini-map & Exploration
        .miniMap: "Mini-Map",
        .helpMiniMap: "Toggle mini-map",
        .explorationProgress: "Exploration",
        .easterEggFound: "Easter Egg Found!",
        .loreDiscovered: "Lore Discovered!",
    ]
}
