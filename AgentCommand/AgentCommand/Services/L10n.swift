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
    case theme, language
    case helpChangeTheme

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

    // D1: Task Queue Visualization
    case taskQueue, helpTaskQueue
    case estimatedTime, dragToReorder, noQueuedTasks

    // Skill Store (Agent Skills)
    case skillStore, helpSkillStore
    case installedSkills, activeSkills, totalSkills
    case installSkill, uninstallSkill, activateSkill, deactivateSkill
    case skillInstalled, skillUninstalled, skillActivated, skillDeactivated
    case addCustomSkill, editSkill, removeSkill, skillName, skillDescription
    case selectSkillCategory, selectSkillIcon, confirmDeleteSkill
    case skillInstructions, skillResources, skillVersion, skillAuthor, skillTags
    case skillCompatiblePlatforms, skillUsageCount, skillLastUsed, skillInstalledAt
    case searchSkills, filterAll, filterPreBuilt, filterCustom
    case noSkillsFound, noAgentSelected
    case skillCategoryFileProcessing, skillCategoryCodeExecution
    case skillCategoryDataAnalysis, skillCategoryWebInteraction
    case skillCategoryContentCreation, skillCategorySystemIntegration
    case skillCategoryCustom
    case skillSourcePreBuilt, skillSourceCustom, skillSourceCommunity

    // D2: Multi-Window Support
    case multiWindow, helpMultiWindow
    case popOutCLI, detachAgentPanel, floatingMonitor
    case helpPopOutCLI, helpDetachAgentPanel, helpFloatingMonitor
    case multiMonitor, helpMultiMonitor, moveToScreen
    case alwaysOnTop, monitorOpacity
    case noTaskSelected, selectTaskToViewCLI
    case selectAgentToViewDetails
    case activeAgents, activeTasks, systemOverview

    // D5: Performance Metrics
    case performanceMetrics, helpPerformanceMetrics
    case sessionCost, tokenUsage, tasksRun, avgDuration
    case resourceUsage, recentTasks
    case costPerTask, durationComparison

    // D4: Session History & Replay
    case sessionHistory, helpSessionHistory
    case sessionReplay, replayMode, stopReplay
    case sessionRecording, sessionEnded
    case noSessions, sessionDetails
    case replayControls, playReplay, pauseReplay
    case replaySpeed, replayProgress
    case exportSession, deleteSession, confirmDeleteSession
    case searchSessions, searchPlaceholder, noSearchResults
    case sessionDuration, sessionTheme, sessionTasks, sessionEvents
    case sessionStarted, sessionAgent, sessionCLIOutput

    // SkillsMP Integration
    case browseSkillsMP, skillsMPMarketplace
    case skillsMPSearch, skillsMPAISearch, skillsMPSearchPlaceholder
    case skillsMPAPIKey, skillsMPEnterAPIKey, skillsMPSaveKey, skillsMPGetKey
    case skillsMPNoAPIKey, skillsMPNoAPIKeyDesc
    case skillsMPImport, skillsMPImported, skillsMPOpenInBrowser
    case skillsMPStars, skillsMPUpdatedAt
    case skillsMPNoResults, skillsMPLoading, skillsMPError
    case skillsMPSortByStars, skillsMPSortByDate
    case skillsMPAlreadyImported
    case addManualSkill

    // G3: Git Integration
    case gitIntegration, helpGitIntegration
    case gitDiff, gitBranches, gitCommits, gitPullRequest
    case gitNoRepository, gitRepositoryClean
    case gitStagedChanges, gitUnstagedChanges
    case gitCurrentBranch, gitRemoteBranch
    case gitCreatePR, gitPRTitle, gitPRBody, gitPRPreview
    case gitSourceBranch, gitTargetBranch
    case gitShowInScene, gitHideFromScene
    case gitFilesChanged, gitAdditions, gitDeletions
    case gitCommitHash, gitCommitAuthor, gitCommitDate
    case gitNoBranches, gitNoCommits, gitGhNotFound

    // G3: Git Commit & Push
    case gitCommitAndPush
    case gitStageAll, gitCommit, gitPush
    case gitCommitMessage, gitGenerateMessage, gitGeneratingMessage
    case gitCommitting, gitPushing
    case gitCommitSuccess, gitPushSuccess
    case gitCommitFailed, gitPushFailed
    case gitNothingToCommit, gitNoRemote
    case gitStageAllFiles, gitStagedCount

    // G1: Multi-Model Support
    case modelOpus, modelSonnet, modelHaiku
    case modelOpusDesc, modelSonnetDesc, modelHaikuDesc
    case selectModel, helpSelectModel
    case modelComparison, helpModelComparison
    case modelSelector, typeComparisonPrompt, compare
    case modelComparisonResults

    // E1: Agent Personality System
    case personalityEnergetic, personalityCalm, personalityCurious
    case personalityFocused, personalitySocial, personalityShy
    case moodHappy, moodNeutral, moodStressed, moodExcited, moodTired
    case personality, mood, relationships
    case relationshipStranger, relationshipAcquaintance, relationshipColleague, relationshipPartner
    case topCollaborators

    // G2: Prompt Templates
    case promptTemplates, helpPromptTemplates
    case templateGallery, addTemplate, editTemplate, deleteTemplate
    case templateName, templateDescription, templateContent, templateCategory
    case templateVariables, templatePreview, templateUsageCount
    case templateSaveSuccess, templateDeleteConfirm
    case builtInTemplates, customTemplates, recentTemplates
    case templateCategoryBugFix, templateCategoryFeature
    case templateCategoryRefactor, templateCategoryReview, templateCategoryCustom
    case useTemplate, browseAllTemplates, noTemplatesFound
    case templateVariablePlaceholder, templateTags
    case searchTemplates

    // F1: Help Overlay
    case help, helpShowHelp
    case helpOverlayTitle, helpOKButton
    case helpKeyboardShortcuts, helpMouseInteractions, helpCameraControls, helpFeatures
    case helpKeyF1, helpKeyF1Desc
    case helpKeyEscape, helpKeyEscapeDesc
    case helpClickAgent, helpClickAgentDesc
    case helpDoubleClickAgent, helpDoubleClickAgentDesc
    case helpRightClickAgent, helpRightClickAgentDesc
    case helpDragTask, helpDragTaskDesc
    case helpCameraOrbit, helpCameraOrbitDesc
    case helpCameraZoom, helpCameraZoomDesc
    case helpCameraPresets, helpCameraPresetsDesc
    case helpCameraPiP, helpCameraPiPDesc
    case helpCameraFirstPerson, helpCameraFirstPersonDesc

    // F1: Background Music
    case backgroundMusic, helpBackgroundMusic
    case musicVolume, musicIntensity, musicIntensityCalm, musicIntensityActive

    // H1: RAG System
    case ragKnowledgeBase, helpRAGKnowledgeBase
    case ragIndexing, ragIndexComplete, ragReindex, ragClearIndex
    case ragSearch, ragSearchResults, ragNoResults
    case ragDocuments, ragDatabaseSize, ragLastUpdated
    case ragKnowledgeGraph, ragShowInScene, ragHideFromScene
    case ragAutoIndex, ragNoDocuments
    case ragContextInjected, ragTotalLines
    case ragFileType, ragLineCount, ragFileSize
    case ragRelationships, ragIndexProgress

    // H2: Agent Memory System
    case agentMemory, helpAgentMemory
    case memoryTimeline, memorySearch
    case memoryTotalMemories, memoryTotalAgents
    case memoryDatabaseSize, memoryLastUpdated
    case memoryNoMemories, memoryNoMemoriesDesc
    case memoryCategory, memoryRecent
    case memoryClearAll, memoryConfirmClear
    case memoryAgents, memorySize
    case memoryShared, memoryRecall

    // H3: Task Decomposition
    case taskDecomposition, helpTaskDecompositionStatus
    case tdSubTasks, tdCompleted
    case tdNoDecomposition, tdEnterTaskHint
    // Auto-Decomposition Orchestration
    case autoDecomposition, autoDecompositionToggle
    case orchDecomposing, orchExecuting, orchSynthesizing, orchCompleted, orchFailed
    case orchWaveProgress, orchCancelDecomposition
    case orchExecution, orchSubAgentStatus, orchPhase

    // H4: Prompt Optimization
    case promptOptimization, helpPromptOptimization
    case promptAnalyze, promptAnalyzeInput, promptSuggestions
    case promptQuality, promptClarity, promptSpecificity
    case promptContext, promptActionability, promptTokenEfficiency
    case promptTokenCount, promptEstimatedCost
    case promptHistory, promptPatterns, promptABTest, promptVersions
    case promptNoAnalysis, promptNoHistory, promptNoPatternsYet, promptNoABTests, promptNoVersions
    case promptTotalAnalyzed, promptAvgScore
    case promptShowInScene, promptHideFromScene, promptViewDetails
    case promptRefreshPatterns
    case promptPatternCount, promptPatternSuccessRate, promptPatternAvgTokens
    case promptCreateABTest, promptABTaskDesc
    case promptIssuesDetected, promptRewriteSuggestion, promptRewritePreview, promptApplyRewrite
    case promptFilterByTag, promptFilterByResult, promptSortBy, promptGroupBy
    case promptAllTags, promptSuccessOnly, promptFailedOnly, promptAllResults
    case promptStatistics, promptSuccessRate, promptTotalTokens, promptTotalCost
    case promptCategoryBreakdown, promptLastUsed, promptAvgTokensPerPrompt
    case promptGroupDaily, promptGroupWeekly, promptGroupMonthly
    case promptPromptDetail, promptDuration, promptTags, promptApplySuggestion

    // I1: CI/CD Integration
    case cicdPipeline, helpCICD
    case cicdPipelines, cicdBuildHistory, cicdStages, cicdBuildResult
    case cicdDeployProgress, cicdPRReview, cicdSuccessRate, cicdTotalRuns
    case cicdShowInScene, cicdHideFromScene
    case cicdQueued, cicdInProgress, cicdSuccess, cicdFailure, cicdCancelled
    case cicdRefresh, cicdStartMonitoring, cicdStopMonitoring

    // I2: Test Coverage
    case testCoverage, helpTestCoverage
    case testOverallCoverage, testResults, testPassed, testFailed, testSkipped
    case testTotal, testCoverageTrend, testRunTests, testNoData
    case testShowInScene, testHideFromScene, testUncovered
    case testDuration, testSuiteName

    // I3: Code Quality
    case codeQuality, helpCodeQuality
    case cqErrors, cqWarnings, cqInfo
    case cqComplexity, cqTechDebt, cqRefactorSuggestions
    case cqLintIssues, cqMaintainability, cqAnalyze
    case cqShowInScene, cqHideFromScene
    case cqTotalIssues, cqResolve, cqEstimatedHours

    // I4: Multi-Project Workspace
    case multiProject, helpMultiProject
    case mpProjects, mpAddProject, mpRemoveProject, mpSwitchProject
    case mpActive, mpNoProjects, mpSearch, mpComparison
    case mpTaskCount, mpAgentCount

    // I5: Docker / Dev Environment
    case dockerContainers, helpDocker
    case dockerLogs, dockerResources, dockerRunning, dockerStopped
    case dockerMemory, dockerCPU, dockerNetwork
    case dockerStart, dockerStop, dockerRestart
    case dockerNoContainers, dockerShowInScene, dockerHideFromScene
    case dockerNotAvailable, dockerStartMonitoring, dockerStopMonitoring

    // J1: Code Knowledge Graph
    case codeKnowledgeGraph, helpCodeKnowledgeGraph
    case ckgTotalFiles, ckgDependencies, ckgAvgComplexity, ckgMostConnected
    case ckgAnalyzing, ckgAnalyze
    case ckgFileDependencies, ckgFunctionCalls, ckgArchitectureOverview
    case ckgShowInScene, ckgHideFromScene
    case ckgNoFiles, ckgNoFunctionCalls

    // J2: Collaboration Visualization
    case collabVisualization, helpCollabVisualization
    case collabActivePaths, collabConflicts, collabHandoffs, collabEfficiency
    case collabDataFlow, collabSharedResources, collabTaskHandoffs, collabRadarChart
    case collabActive, collabStartMonitoring, collabStopMonitoring
    case collabShowInScene, collabHideFromScene
    case collabNoPaths, collabNoResources, collabNoHandoffs, collabNoMetrics

    // J3: AR/VR Support
    case arvrSettings, helpARVR
    case arvrPlatform, arvrImmersiveLevel, arvrControls
    case arvrGestureControl, arvrGestureControlDesc
    case arvrHandTracking, arvrHandTrackingDesc
    case arvrSpatialAudio, arvrSpatialAudioDesc
    case arvrPassthrough, arvrPassthroughDesc
    case arvrGestures, arvrVisionOSNotAvailable

    // J4: Data Flow Animation
    case dataFlowAnimation, helpDataFlow
    case dfTokensIn, dfTokensOut, dfToolCalls, dfActiveFlows
    case dfTokenStream, dfIOPipeline, dfToolChain
    case dfShowInScene, dfHideFromScene
    case dfNoFlows, dfNoPipeline, dfNoToolCalls, dfAvgResponseTime

    // L1: Workflow Automation
    case wfWorkflowEngine, helpWorkflow
    case wfWorkflows, wfTemplates, wfHistory
    case wfWorkflowName, wfWorkflowDesc, wfCreateWorkflow
    case wfActiveWorkflows, wfTotalExecutions, wfSuccessRate
    case wfNoWorkflows, wfUseTemplate
    case wfShowInScene, wfHideFromScene

    // L2: Smart Scheduling
    case ssSmartScheduling, helpSmartScheduling
    case ssSchedule, ssOptimizations, ssTimeline
    case ssScheduledTasks, ssCompletedOnTime, ssResourceUtil
    case ssAutoSchedule, ssOptimize
    case ssTaskName, ssAddTask
    case ssBatchTasks, ssPeakHours

    // L3: Anomaly Detection
    case adAnomalyDetection, helpAnomalyDetection
    case adAlerts, adPatterns, adRetryConfig
    case adActiveAlerts, adResolved, adRetrySuccess
    case adMonitoring, adResolve, adResolveAll
    case adNoAlerts, adNoPatterns

    // H5+H1 Unified Knowledge Search
    case unifiedSearch, helpUnifiedSearch
    case unifiedSearchPlaceholder, unifiedSearchMode
    case unifiedSearchModeAll, unifiedSearchModeRAG, unifiedSearchModeSemantic
    case unifiedSearchResultCount, unifiedSearchProcessingTime
    case unifiedSearchNoResults, unifiedSearchNoResultsDesc
    case unifiedSearchKeywordScore, unifiedSearchSemanticScore
    case unifiedSearchEntityScore, unifiedSearchRecencyScore
    case unifiedSearchRelationshipScore, unifiedSearchCombinedScore
    case unifiedSearchSource, unifiedSearchIntent, unifiedSearchConfidence
    case unifiedSearchEntities, unifiedSearchInsertContext
    case unifiedSearchScoreDimensions, unifiedSearchExplanation
    case unifiedSearchRunTest, unifiedSearchTestResults
    case unifiedSearchPerformance, unifiedSearchAccuracy

    // L4: MCP Integration
    case mcpIntegration, helpMCP
    case mcpServers, mcpTools, mcpCallHistory
    case mcpTotalCalls, mcpAvgResponse
    case mcpServerName, mcpServerURL, mcpAddServer
    case mcpConnect, mcpDisconnect
    case mcpNoServers, mcpNoTools
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
        .language: "語言",
        .helpChangeTheme: "變更場景主題",

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

        // D1: Task Queue Visualization
        .taskQueue: "任務佇列",
        .helpTaskQueue: "顯示/隱藏任務佇列",
        .estimatedTime: "預估時間",
        .dragToReorder: "拖曳排序",
        .noQueuedTasks: "佇列無任務",

        // Skill Store (Agent Skills)
        .skillStore: "技能商店",
        .helpSkillStore: "管理代理技能",
        .installedSkills: "已安裝",
        .activeSkills: "啟用中",
        .totalSkills: "技能總數",
        .installSkill: "安裝",
        .uninstallSkill: "解除安裝",
        .activateSkill: "啟用",
        .deactivateSkill: "停用",
        .skillInstalled: "技能已安裝！",
        .skillUninstalled: "技能已解除安裝",
        .skillActivated: "技能已啟用",
        .skillDeactivated: "技能已停用",
        .addCustomSkill: "新增自訂技能",
        .editSkill: "編輯技能",
        .removeSkill: "移除技能",
        .skillName: "技能名稱",
        .skillDescription: "技能描述",
        .selectSkillCategory: "選擇技能分類",
        .selectSkillIcon: "選擇圖標",
        .confirmDeleteSkill: "確定要刪除此技能嗎？",
        .skillInstructions: "技能指令",
        .skillResources: "附帶資源",
        .skillVersion: "版本",
        .skillAuthor: "作者",
        .skillTags: "標籤",
        .skillCompatiblePlatforms: "相容平台",
        .skillUsageCount: "使用次數",
        .skillLastUsed: "最後使用",
        .skillInstalledAt: "安裝日期",
        .searchSkills: "搜尋技能...",
        .filterAll: "全部",
        .filterPreBuilt: "內建",
        .filterCustom: "自訂",
        .noSkillsFound: "找不到符合的技能",
        .noAgentSelected: "請選擇一個代理",
        .skillCategoryFileProcessing: "檔案處理",
        .skillCategoryCodeExecution: "程式執行",
        .skillCategoryDataAnalysis: "資料分析",
        .skillCategoryWebInteraction: "網路互動",
        .skillCategoryContentCreation: "內容建立",
        .skillCategorySystemIntegration: "系統整合",
        .skillCategoryCustom: "自訂技能",
        .skillSourcePreBuilt: "官方內建",
        .skillSourceCustom: "使用者自訂",
        .skillSourceCommunity: "社群",

        // D2: Multi-Window Support
        .multiWindow: "多視窗",
        .helpMultiWindow: "管理多視窗設定",
        .popOutCLI: "彈出 CLI 視窗",
        .detachAgentPanel: "獨立代理面板",
        .floatingMonitor: "浮動監控",
        .helpPopOutCLI: "將 CLI 輸出分離至獨立視窗",
        .helpDetachAgentPanel: "將代理詳細資訊分離至獨立視窗",
        .helpFloatingMonitor: "開啟/關閉浮動監控視窗",
        .multiMonitor: "多螢幕",
        .helpMultiMonitor: "多螢幕佈局設定",
        .moveToScreen: "移至螢幕",
        .alwaysOnTop: "置頂顯示",
        .monitorOpacity: "監控透明度",
        .noTaskSelected: "未選擇任務",
        .selectTaskToViewCLI: "選擇一個任務以檢視 CLI 輸出",
        .selectAgentToViewDetails: "選擇一個代理以檢視詳細資訊",
        .activeAgents: "活躍代理",
        .activeTasks: "活躍任務",
        .systemOverview: "系統總覽",

        // D4: Session History & Replay
        .sessionHistory: "工作歷程",
        .helpSessionHistory: "查看與回放過去的工作歷程",
        .sessionReplay: "歷程回放",
        .replayMode: "回放模式",
        .stopReplay: "停止回放",
        .sessionRecording: "錄製中",
        .sessionEnded: "歷程已結束",
        .noSessions: "尚無工作歷程",
        .sessionDetails: "歷程詳情",
        .replayControls: "回放控制",
        .playReplay: "播放",
        .pauseReplay: "暫停",
        .replaySpeed: "回放速度",
        .replayProgress: "回放進度",
        .exportSession: "匯出歷程",
        .deleteSession: "刪除歷程",
        .confirmDeleteSession: "確定要刪除此工作歷程嗎？",
        .searchSessions: "搜尋歷程",
        .searchPlaceholder: "搜尋任務名稱、事件...",
        .noSearchResults: "找不到符合的歷程",
        .sessionDuration: "歷程時長",
        .sessionTheme: "場景主題",
        .sessionTasks: "任務數",
        .sessionEvents: "事件數",
        .sessionStarted: "開始時間",
        .sessionAgent: "代理",
        .sessionCLIOutput: "CLI 輸出",

        // D5: Performance Metrics
        .performanceMetrics: "效能指標",
        .helpPerformanceMetrics: "顯示/隱藏效能指標面板",
        .sessionCost: "會話費用",
        .tokenUsage: "Token 用量",
        .tasksRun: "已執行任務",
        .avgDuration: "平均時長",
        .resourceUsage: "資源使用",
        .recentTasks: "最近任務",
        .costPerTask: "每任務費用",
        .durationComparison: "時長比較",

        // SkillsMP
        .browseSkillsMP: "瀏覽 SkillsMP",
        .skillsMPMarketplace: "SkillsMP 技能市集",
        .skillsMPSearch: "搜尋",
        .skillsMPAISearch: "AI 搜尋",
        .skillsMPSearchPlaceholder: "搜尋技能...",
        .skillsMPAPIKey: "API 金鑰",
        .skillsMPEnterAPIKey: "輸入 SkillsMP API 金鑰",
        .skillsMPSaveKey: "儲存",
        .skillsMPGetKey: "取得 API 金鑰",
        .skillsMPNoAPIKey: "尚未設定 API 金鑰",
        .skillsMPNoAPIKeyDesc: "請先設定 SkillsMP API 金鑰以搜尋社群技能",
        .skillsMPImport: "匯入",
        .skillsMPImported: "技能已匯入！",
        .skillsMPOpenInBrowser: "在瀏覽器中開啟",
        .skillsMPStars: "星星",
        .skillsMPUpdatedAt: "更新日期",
        .skillsMPNoResults: "找不到相關技能",
        .skillsMPLoading: "搜尋中...",
        .skillsMPError: "搜尋失敗",
        .skillsMPSortByStars: "依星星數排序",
        .skillsMPSortByDate: "依更新日期排序",
        .skillsMPAlreadyImported: "此技能已匯入",
        .addManualSkill: "手動新增自訂技能...",

        // G3: Git Integration
        .gitIntegration: "Git 整合",
        .helpGitIntegration: "Git 倉庫視覺化",
        .gitDiff: "差異",
        .gitBranches: "分支",
        .gitCommits: "提交",
        .gitPullRequest: "Pull Request",
        .gitNoRepository: "目前工作區不是 Git 倉庫",
        .gitRepositoryClean: "工作目錄乾淨，無變更",
        .gitStagedChanges: "已暫存變更",
        .gitUnstagedChanges: "未暫存變更",
        .gitCurrentBranch: "當前分支",
        .gitRemoteBranch: "遠端分支",
        .gitCreatePR: "建立 Pull Request",
        .gitPRTitle: "PR 標題",
        .gitPRBody: "PR 描述",
        .gitPRPreview: "預覽",
        .gitSourceBranch: "來源分支",
        .gitTargetBranch: "目標分支",
        .gitShowInScene: "在 3D 場景中顯示",
        .gitHideFromScene: "從 3D 場景中隱藏",
        .gitFilesChanged: "變更檔案",
        .gitAdditions: "新增行",
        .gitDeletions: "刪除行",
        .gitCommitHash: "提交雜湊",
        .gitCommitAuthor: "作者",
        .gitCommitDate: "日期",
        .gitNoBranches: "無分支資訊",
        .gitNoCommits: "無提交記錄",
        .gitGhNotFound: "未找到 gh CLI，請安裝 GitHub CLI",

        // G3: Git Commit & Push
        .gitCommitAndPush: "提交 & 推送",
        .gitStageAll: "暫存全部",
        .gitCommit: "提交",
        .gitPush: "推送",
        .gitCommitMessage: "提交訊息",
        .gitGenerateMessage: "AI 生成訊息",
        .gitGeneratingMessage: "AI 生成中...",
        .gitCommitting: "提交中...",
        .gitPushing: "推送中...",
        .gitCommitSuccess: "提交成功！",
        .gitPushSuccess: "推送成功！",
        .gitCommitFailed: "提交失敗",
        .gitPushFailed: "推送失敗",
        .gitNothingToCommit: "無變更可提交",
        .gitNoRemote: "未設定遠端倉庫",
        .gitStageAllFiles: "暫存所有變更檔案",
        .gitStagedCount: "已暫存 %d 個檔案",

        // E1: Agent Personality System
        .personalityEnergetic: "活力充沛",
        .personalityCalm: "沉穩冷靜",
        .personalityCurious: "好奇心強",
        .personalityFocused: "專注認真",
        .personalitySocial: "善於社交",
        .personalityShy: "內向害羞",
        .moodHappy: "開心",
        .moodNeutral: "平靜",
        .moodStressed: "壓力大",
        .moodExcited: "興奮",
        .moodTired: "疲倦",
        .personality: "個性",
        .mood: "心情",
        .relationships: "關係",
        .relationshipStranger: "陌生人",
        .relationshipAcquaintance: "認識",
        .relationshipColleague: "同事",
        .relationshipPartner: "夥伴",
        .topCollaborators: "最佳搭檔",

        // G1: Multi-Model Support
        .modelOpus: "Opus",
        .modelSonnet: "Sonnet",
        .modelHaiku: "Haiku",
        .modelOpusDesc: "最強大的模型，適用於複雜任務",
        .modelSonnetDesc: "均衡的模型，兼顧速度與品質",
        .modelHaikuDesc: "最快速的模型，適用於簡單任務",
        .selectModel: "選擇模型",
        .helpSelectModel: "為新團隊選擇 Claude 模型",
        .modelComparison: "模型比較",
        .helpModelComparison: "比較不同模型的輸出結果",
        .modelSelector: "模型選擇器",
        .typeComparisonPrompt: "輸入比較提示詞...",
        .compare: "比較",
        .modelComparisonResults: "比較結果",

        // G2: Prompt Templates
        .promptTemplates: "提示詞模板",
        .helpPromptTemplates: "瀏覽與管理提示詞模板",
        .templateGallery: "模板庫",
        .addTemplate: "新增模板",
        .editTemplate: "編輯模板",
        .deleteTemplate: "刪除模板",
        .templateName: "模板名稱",
        .templateDescription: "模板描述",
        .templateContent: "模板內容",
        .templateCategory: "模板分類",
        .templateVariables: "變數",
        .templatePreview: "預覽",
        .templateUsageCount: "使用次數",
        .templateSaveSuccess: "模板已儲存！",
        .templateDeleteConfirm: "確定要刪除此模板嗎？",
        .builtInTemplates: "內建模板",
        .customTemplates: "自訂模板",
        .recentTemplates: "最近使用",
        .templateCategoryBugFix: "錯誤修復",
        .templateCategoryFeature: "新增功能",
        .templateCategoryRefactor: "程式重構",
        .templateCategoryReview: "程式碼審查",
        .templateCategoryCustom: "自訂",
        .useTemplate: "使用模板",
        .browseAllTemplates: "瀏覽所有模板",
        .noTemplatesFound: "找不到符合的模板",
        .templateVariablePlaceholder: "輸入數值...",
        .templateTags: "標籤",
        .searchTemplates: "搜尋模板...",

        // F1: Help Overlay
        .help: "說明",
        .helpShowHelp: "顯示快捷鍵指南 (F1)",
        .helpOverlayTitle: "快捷鍵指南",
        .helpOKButton: "確定",
        .helpKeyboardShortcuts: "鍵盤快捷鍵",
        .helpMouseInteractions: "滑鼠互動",
        .helpCameraControls: "攝影機控制",
        .helpFeatures: "功能面板",
        .helpKeyF1: "F1",
        .helpKeyF1Desc: "顯示/隱藏此快捷鍵指南",
        .helpKeyEscape: "Escape",
        .helpKeyEscapeDesc: "退出第一人稱視角模式",
        .helpClickAgent: "點擊代理",
        .helpClickAgentDesc: "選擇代理並顯示詳細資訊",
        .helpDoubleClickAgent: "雙擊代理",
        .helpDoubleClickAgentDesc: "追蹤與聚焦該代理",
        .helpRightClickAgent: "右鍵代理",
        .helpRightClickAgentDesc: "開啟上下文選單（查看日誌、放大、取消任務）",
        .helpDragTask: "拖曳任務到代理",
        .helpDragTaskDesc: "將待辦任務拖放到代理上進行指派",
        .helpCameraOrbit: "滑鼠拖曳",
        .helpCameraOrbitDesc: "自由環繞 3D 場景",
        .helpCameraZoom: "雙擊代理",
        .helpCameraZoomDesc: "平滑縮放至該代理",
        .helpCameraPresets: "攝影機預設",
        .helpCameraPresetsDesc: "從工具列選單選擇 Overview、Close-Up 或 Cinematic 視角",
        .helpCameraPiP: "子母畫面",
        .helpCameraPiPDesc: "在左下角顯示第二攝影機視角",
        .helpCameraFirstPerson: "第一人稱視角",
        .helpCameraFirstPersonDesc: "從代理的視角觀看場景",

        // F1: Background Music
        .backgroundMusic: "背景音樂",
        .helpBackgroundMusic: "開啟/關閉背景音樂",
        .musicVolume: "音樂音量",
        .musicIntensity: "音樂強度",
        .musicIntensityCalm: "平靜",
        .musicIntensityActive: "活躍",

        // H1: RAG System
        .ragKnowledgeBase: "知識庫",
        .helpRAGKnowledgeBase: "管理本地知識庫與語義搜尋",
        .ragIndexing: "索引中...",
        .ragIndexComplete: "索引完成",
        .ragReindex: "重新索引",
        .ragClearIndex: "清除索引",
        .ragSearch: "搜尋知識庫",
        .ragSearchResults: "搜尋結果",
        .ragNoResults: "找不到相關結果",
        .ragDocuments: "已索引文件",
        .ragDatabaseSize: "資料庫大小",
        .ragLastUpdated: "最後更新",
        .ragKnowledgeGraph: "知識圖譜",
        .ragShowInScene: "在 3D 場景中顯示",
        .ragHideFromScene: "從 3D 場景中隱藏",
        .ragAutoIndex: "自動索引",
        .ragNoDocuments: "尚無已索引文件",
        .ragContextInjected: "已注入上下文",
        .ragTotalLines: "總行數",
        .ragFileType: "檔案類型",
        .ragLineCount: "行數",
        .ragFileSize: "檔案大小",
        .ragRelationships: "依賴關係",
        .ragIndexProgress: "索引進度",

        // H5+H1 Unified Knowledge Search
        .unifiedSearch: "統一知識搜尋",
        .helpUnifiedSearch: "整合 RAG 與語義搜尋的統一知識庫介面",
        .unifiedSearchPlaceholder: "搜尋知識庫...",
        .unifiedSearchMode: "搜尋模式",
        .unifiedSearchModeAll: "全部",
        .unifiedSearchModeRAG: "RAG 關鍵字",
        .unifiedSearchModeSemantic: "語義搜尋",
        .unifiedSearchResultCount: "搜尋結果",
        .unifiedSearchProcessingTime: "處理時間",
        .unifiedSearchNoResults: "無搜尋結果",
        .unifiedSearchNoResultsDesc: "嘗試不同的關鍵字或切換搜尋模式",
        .unifiedSearchKeywordScore: "關鍵字分數",
        .unifiedSearchSemanticScore: "語義相關性",
        .unifiedSearchEntityScore: "實體匹配",
        .unifiedSearchRecencyScore: "新鮮度",
        .unifiedSearchRelationshipScore: "關聯度",
        .unifiedSearchCombinedScore: "綜合分數",
        .unifiedSearchSource: "來源",
        .unifiedSearchIntent: "意圖",
        .unifiedSearchConfidence: "信心度",
        .unifiedSearchEntities: "辨識實體",
        .unifiedSearchInsertContext: "插入上下文",
        .unifiedSearchScoreDimensions: "分數維度",
        .unifiedSearchExplanation: "排名說明",
        .unifiedSearchRunTest: "執行測試",
        .unifiedSearchTestResults: "測試結果",
        .unifiedSearchPerformance: "效能指標",
        .unifiedSearchAccuracy: "準確度",

        // H2: Agent Memory System
        .agentMemory: "代理記憶",
        .helpAgentMemory: "管理 AI 代理記憶系統",
        .memoryTimeline: "記憶時間軸",
        .memorySearch: "搜尋記憶...",
        .memoryTotalMemories: "總記憶數",
        .memoryTotalAgents: "代理數",
        .memoryDatabaseSize: "資料庫大小",
        .memoryLastUpdated: "最後更新",
        .memoryNoMemories: "尚無記憶",
        .memoryNoMemoriesDesc: "當代理完成任務後，記憶將自動記錄。",
        .memoryCategory: "分類",
        .memoryRecent: "最近記憶",
        .memoryClearAll: "清除全部",
        .memoryConfirmClear: "確定要清除所有代理記憶嗎？",
        .memoryAgents: "代理",
        .memorySize: "大小",
        .memoryShared: "已分享",
        .memoryRecall: "回憶",

        // H3: Task Decomposition
        .taskDecomposition: "任務分解",
        .helpTaskDecompositionStatus: "顯示/隱藏任務分解狀態面板",
        .tdSubTasks: "子任務",
        .tdCompleted: "已完成",
        .tdNoDecomposition: "尚無任務分解",
        .tdEnterTaskHint: "輸入複雜任務以觸發自動分解",
        // Auto-Decomposition Orchestration
        .autoDecomposition: "自動分解",
        .autoDecompositionToggle: "自動分解模式",
        .orchDecomposing: "分解指令中...",
        .orchExecuting: "執行中",
        .orchSynthesizing: "彙整結果中...",
        .orchCompleted: "已完成",
        .orchFailed: "失敗",
        .orchWaveProgress: "Wave 進度",
        .orchCancelDecomposition: "取消分解執行",
        .orchExecution: "執行",
        .orchSubAgentStatus: "子代理狀態",
        .orchPhase: "階段",

        // H4: Prompt Optimization
        .promptOptimization: "提示詞優化",
        .helpPromptOptimization: "分析與優化提示詞品質",
        .promptAnalyze: "分析",
        .promptAnalyzeInput: "輸入提示詞進行品質分析",
        .promptSuggestions: "優化建議",
        .promptQuality: "品質",
        .promptClarity: "清晰度",
        .promptSpecificity: "具體性",
        .promptContext: "上下文",
        .promptActionability: "可操作性",
        .promptTokenEfficiency: "Token效率",
        .promptTokenCount: "Token 數量",
        .promptEstimatedCost: "預估費用",
        .promptHistory: "歷史",
        .promptPatterns: "模式分析",
        .promptABTest: "A/B 測試",
        .promptVersions: "版本",
        .promptNoAnalysis: "尚未分析提示詞",
        .promptNoHistory: "尚無提示詞歷史",
        .promptNoPatternsYet: "完成更多任務以偵測模式",
        .promptNoABTests: "尚無 A/B 測試",
        .promptNoVersions: "尚無版本記錄",
        .promptTotalAnalyzed: "已分析",
        .promptAvgScore: "平均分數",
        .promptShowInScene: "在 3D 場景中顯示",
        .promptHideFromScene: "從 3D 場景中隱藏",
        .promptViewDetails: "詳細分析",
        .promptRefreshPatterns: "重新偵測",
        .promptPatternCount: "使用次數",
        .promptPatternSuccessRate: "成功率",
        .promptPatternAvgTokens: "平均Token",
        .promptCreateABTest: "建立 A/B 測試",
        .promptABTaskDesc: "任務描述...",
        .promptIssuesDetected: "問題偵測",
        .promptRewriteSuggestion: "改寫建議",
        .promptRewritePreview: "改寫預覽",
        .promptApplyRewrite: "套用改寫",
        .promptFilterByTag: "依標籤篩選",
        .promptFilterByResult: "依結果篩選",
        .promptSortBy: "排序方式",
        .promptGroupBy: "分組方式",
        .promptAllTags: "所有標籤",
        .promptSuccessOnly: "僅成功",
        .promptFailedOnly: "僅失敗",
        .promptAllResults: "所有結果",
        .promptStatistics: "統計概覽",
        .promptSuccessRate: "成功率",
        .promptTotalTokens: "總 Token",
        .promptTotalCost: "總費用",
        .promptCategoryBreakdown: "類別統計",
        .promptLastUsed: "最後使用",
        .promptAvgTokensPerPrompt: "平均Token/次",
        .promptGroupDaily: "每日",
        .promptGroupWeekly: "每週",
        .promptGroupMonthly: "每月",
        .promptPromptDetail: "提示詞詳情",
        .promptDuration: "耗時",
        .promptTags: "標籤",
        .promptApplySuggestion: "套用建議",

        // I1: CI/CD Integration
        .cicdPipeline: "CI/CD 管線",
        .helpCICD: "CI/CD 管線視覺化與監控",
        .cicdPipelines: "管線",
        .cicdBuildHistory: "構建歷史",
        .cicdStages: "階段",
        .cicdBuildResult: "構建結果",
        .cicdDeployProgress: "部署進度",
        .cicdPRReview: "PR 審核",
        .cicdSuccessRate: "成功率",
        .cicdTotalRuns: "總執行數",
        .cicdShowInScene: "在 3D 場景中顯示",
        .cicdHideFromScene: "從 3D 場景中隱藏",
        .cicdQueued: "等待中",
        .cicdInProgress: "進行中",
        .cicdSuccess: "成功",
        .cicdFailure: "失敗",
        .cicdCancelled: "已取消",
        .cicdRefresh: "重新整理",
        .cicdStartMonitoring: "開始監控",
        .cicdStopMonitoring: "停止監控",

        // I2: Test Coverage
        .testCoverage: "測試覆蓋率",
        .helpTestCoverage: "測試覆蓋率視覺化與分析",
        .testOverallCoverage: "整體覆蓋率",
        .testResults: "測試結果",
        .testPassed: "通過",
        .testFailed: "失敗",
        .testSkipped: "跳過",
        .testTotal: "總計",
        .testCoverageTrend: "覆蓋率趨勢",
        .testRunTests: "執行測試",
        .testNoData: "尚無測試資料",
        .testShowInScene: "在 3D 場景中顯示",
        .testHideFromScene: "從 3D 場景中隱藏",
        .testUncovered: "未覆蓋區域",
        .testDuration: "測試時長",
        .testSuiteName: "測試套件",

        // I3: Code Quality
        .codeQuality: "程式碼品質",
        .helpCodeQuality: "程式碼品質分析與技術債追蹤",
        .cqErrors: "錯誤",
        .cqWarnings: "警告",
        .cqInfo: "資訊",
        .cqComplexity: "複雜度",
        .cqTechDebt: "技術債",
        .cqRefactorSuggestions: "重構建議",
        .cqLintIssues: "Lint 問題",
        .cqMaintainability: "可維護性",
        .cqAnalyze: "分析專案",
        .cqShowInScene: "在 3D 場景中顯示",
        .cqHideFromScene: "從 3D 場景中隱藏",
        .cqTotalIssues: "總問題數",
        .cqResolve: "解決",
        .cqEstimatedHours: "預估工時",

        // I4: Multi-Project Workspace
        .multiProject: "多專案工作區",
        .helpMultiProject: "同時監控多個專案",
        .mpProjects: "專案",
        .mpAddProject: "新增專案",
        .mpRemoveProject: "移除專案",
        .mpSwitchProject: "切換專案",
        .mpActive: "活躍",
        .mpNoProjects: "尚無專案",
        .mpSearch: "搜尋任務",
        .mpComparison: "專案比較",
        .mpTaskCount: "任務數",
        .mpAgentCount: "代理數",

        // I5: Docker / Dev Environment
        .dockerContainers: "Docker 容器",
        .helpDocker: "Docker 容器監控與管理",
        .dockerLogs: "容器日誌",
        .dockerResources: "資源監控",
        .dockerRunning: "執行中",
        .dockerStopped: "已停止",
        .dockerMemory: "記憶體",
        .dockerCPU: "CPU",
        .dockerNetwork: "網路",
        .dockerStart: "啟動",
        .dockerStop: "停止",
        .dockerRestart: "重啟",
        .dockerNoContainers: "無 Docker 容器",
        .dockerShowInScene: "在 3D 場景中顯示",
        .dockerHideFromScene: "從 3D 場景中隱藏",
        .dockerNotAvailable: "Docker 未安裝或未啟動",
        .dockerStartMonitoring: "開始監控",
        .dockerStopMonitoring: "停止監控",

        // J1: Code Knowledge Graph
        .codeKnowledgeGraph: "程式碼知識圖譜",
        .helpCodeKnowledgeGraph: "檔案依賴關係與架構視覺化",
        .ckgTotalFiles: "檔案數",
        .ckgDependencies: "依賴數",
        .ckgAvgComplexity: "平均複雜度",
        .ckgMostConnected: "最多連線",
        .ckgAnalyzing: "分析中...",
        .ckgAnalyze: "分析專案",
        .ckgFileDependencies: "檔案依賴",
        .ckgFunctionCalls: "函數呼叫",
        .ckgArchitectureOverview: "架構概覽",
        .ckgShowInScene: "在 3D 場景中顯示",
        .ckgHideFromScene: "從 3D 場景中隱藏",
        .ckgNoFiles: "尚無檔案節點",
        .ckgNoFunctionCalls: "尚無函數呼叫鏈",

        // J2: Collaboration Visualization
        .collabVisualization: "協作視覺化",
        .helpCollabVisualization: "多 Agent 協作路徑與效率視覺化",
        .collabActivePaths: "活躍路徑",
        .collabConflicts: "衝突",
        .collabHandoffs: "交接",
        .collabEfficiency: "效率",
        .collabDataFlow: "資料流動",
        .collabSharedResources: "共享資源",
        .collabTaskHandoffs: "任務交接",
        .collabRadarChart: "效率雷達圖",
        .collabActive: "活躍中",
        .collabStartMonitoring: "開始監控",
        .collabStopMonitoring: "停止監控",
        .collabShowInScene: "在 3D 場景中顯示",
        .collabHideFromScene: "從 3D 場景中隱藏",
        .collabNoPaths: "尚無協作路徑",
        .collabNoResources: "尚無共享資源",
        .collabNoHandoffs: "尚無任務交接",
        .collabNoMetrics: "尚無效率指標",

        // J3: AR/VR Support
        .arvrSettings: "AR/VR 設定",
        .helpARVR: "AR/VR 沉浸式體驗設定",
        .arvrPlatform: "平台",
        .arvrImmersiveLevel: "沉浸等級",
        .arvrControls: "控制設定",
        .arvrGestureControl: "手勢控制",
        .arvrGestureControlDesc: "以手勢與 3D Agent 互動",
        .arvrHandTracking: "手部追蹤",
        .arvrHandTrackingDesc: "精確追蹤手部動作",
        .arvrSpatialAudio: "空間音效",
        .arvrSpatialAudioDesc: "根據 3D 位置調整音效方向",
        .arvrPassthrough: "穿透模式",
        .arvrPassthroughDesc: "顯示真實環境與虛擬物件疊加",
        .arvrGestures: "手勢類型",
        .arvrVisionOSNotAvailable: "此裝置不支援 visionOS 功能。需要 Apple Vision Pro。",

        // J4: Data Flow Animation
        .dataFlowAnimation: "資料流動畫",
        .helpDataFlow: "Token 串流與工具呼叫鏈視覺化",
        .dfTokensIn: "Token 輸入",
        .dfTokensOut: "Token 輸出",
        .dfToolCalls: "工具呼叫",
        .dfActiveFlows: "活躍流",
        .dfTokenStream: "Token 串流",
        .dfIOPipeline: "I/O 管道",
        .dfToolChain: "工具鏈",
        .dfShowInScene: "在 3D 場景中顯示",
        .dfHideFromScene: "從 3D 場景中隱藏",
        .dfNoFlows: "尚無資料流",
        .dfNoPipeline: "尚無管道資料",
        .dfNoToolCalls: "尚無工具呼叫",
        .dfAvgResponseTime: "平均回應",

        // L1: Workflow Automation
        .wfWorkflowEngine: "工作流引擎",
        .helpWorkflow: "自動化工作流編輯與管理",
        .wfWorkflows: "工作流",
        .wfTemplates: "模板",
        .wfHistory: "執行歷史",
        .wfWorkflowName: "工作流名稱",
        .wfWorkflowDesc: "描述",
        .wfCreateWorkflow: "建立工作流",
        .wfActiveWorkflows: "活躍工作流",
        .wfTotalExecutions: "總執行數",
        .wfSuccessRate: "成功率",
        .wfNoWorkflows: "尚無工作流",
        .wfUseTemplate: "使用模板",
        .wfShowInScene: "在 3D 場景中顯示",
        .wfHideFromScene: "從 3D 場景中隱藏",

        // L2: Smart Scheduling
        .ssSmartScheduling: "智慧排程",
        .helpSmartScheduling: "智慧任務排程與資源預測",
        .ssSchedule: "排程",
        .ssOptimizations: "優化",
        .ssTimeline: "時間軸",
        .ssScheduledTasks: "已排程任務",
        .ssCompletedOnTime: "準時完成",
        .ssResourceUtil: "資源利用率",
        .ssAutoSchedule: "自動排程",
        .ssOptimize: "優化排程",
        .ssTaskName: "任務名稱",
        .ssAddTask: "新增任務",
        .ssBatchTasks: "批次任務",
        .ssPeakHours: "尖峰時段",

        // L3: Anomaly Detection
        .adAnomalyDetection: "異常偵測",
        .helpAnomalyDetection: "異常偵測與自我修復系統",
        .adAlerts: "警報",
        .adPatterns: "錯誤模式",
        .adRetryConfig: "重試設定",
        .adActiveAlerts: "活躍警報",
        .adResolved: "已解決",
        .adRetrySuccess: "重試成功率",
        .adMonitoring: "監控中",
        .adResolve: "解決",
        .adResolveAll: "全部解決",
        .adNoAlerts: "無警報",
        .adNoPatterns: "尚無錯誤模式",

        // L4: MCP Integration
        .mcpIntegration: "MCP 整合",
        .helpMCP: "Model Context Protocol 伺服器管理",
        .mcpServers: "伺服器",
        .mcpTools: "工具",
        .mcpCallHistory: "呼叫歷史",
        .mcpTotalCalls: "總呼叫數",
        .mcpAvgResponse: "平均回應",
        .mcpServerName: "伺服器名稱",
        .mcpServerURL: "伺服器 URL",
        .mcpAddServer: "新增伺服器",
        .mcpConnect: "連線",
        .mcpDisconnect: "中斷連線",
        .mcpNoServers: "尚無 MCP 伺服器",
        .mcpNoTools: "尚無工具",
    ]

    // MARK: - English

    private static let en: [L10nKey: String] = [
        // Toolbar
        .theme: "Theme",
        .language: "Language",
        .helpChangeTheme: "Change scene theme",

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

        // D1: Task Queue Visualization
        .taskQueue: "Task Queue",
        .helpTaskQueue: "Toggle task queue",
        .estimatedTime: "Est. Time",
        .dragToReorder: "Drag to reorder",
        .noQueuedTasks: "No queued tasks",

        // Skill Store (Agent Skills)
        .skillStore: "Skill Store",
        .helpSkillStore: "Manage agent skills",
        .installedSkills: "Installed",
        .activeSkills: "Active",
        .totalSkills: "Total Skills",
        .installSkill: "Install",
        .uninstallSkill: "Uninstall",
        .activateSkill: "Activate",
        .deactivateSkill: "Deactivate",
        .skillInstalled: "Skill Installed!",
        .skillUninstalled: "Skill Uninstalled",
        .skillActivated: "Skill Activated",
        .skillDeactivated: "Skill Deactivated",
        .addCustomSkill: "Add Custom Skill",
        .editSkill: "Edit Skill",
        .removeSkill: "Remove Skill",
        .skillName: "Skill Name",
        .skillDescription: "Skill Description",
        .selectSkillCategory: "Select Category",
        .selectSkillIcon: "Select Icon",
        .confirmDeleteSkill: "Are you sure you want to delete this skill?",
        .skillInstructions: "Instructions",
        .skillResources: "Resources",
        .skillVersion: "Version",
        .skillAuthor: "Author",
        .skillTags: "Tags",
        .skillCompatiblePlatforms: "Platforms",
        .skillUsageCount: "Usage Count",
        .skillLastUsed: "Last Used",
        .skillInstalledAt: "Installed",
        .searchSkills: "Search skills...",
        .filterAll: "All",
        .filterPreBuilt: "Pre-built",
        .filterCustom: "Custom",
        .noSkillsFound: "No matching skills found",
        .noAgentSelected: "Select an agent",
        .skillCategoryFileProcessing: "File Processing",
        .skillCategoryCodeExecution: "Code Execution",
        .skillCategoryDataAnalysis: "Data Analysis",
        .skillCategoryWebInteraction: "Web Interaction",
        .skillCategoryContentCreation: "Content Creation",
        .skillCategorySystemIntegration: "System Integration",
        .skillCategoryCustom: "Custom Skills",
        .skillSourcePreBuilt: "Pre-built",
        .skillSourceCustom: "Custom",
        .skillSourceCommunity: "Community",

        // D2: Multi-Window Support
        .multiWindow: "Multi-Window",
        .helpMultiWindow: "Manage multi-window settings",
        .popOutCLI: "Pop Out CLI",
        .detachAgentPanel: "Detach Agent Panel",
        .floatingMonitor: "Floating Monitor",
        .helpPopOutCLI: "Pop out CLI output to separate window",
        .helpDetachAgentPanel: "Detach agent details to separate window",
        .helpFloatingMonitor: "Toggle floating monitor window",
        .multiMonitor: "Multi-Monitor",
        .helpMultiMonitor: "Multi-monitor layout settings",
        .moveToScreen: "Move to Screen",
        .alwaysOnTop: "Always on Top",
        .monitorOpacity: "Monitor Opacity",
        .noTaskSelected: "No Task Selected",
        .selectTaskToViewCLI: "Select a task to view CLI output",
        .selectAgentToViewDetails: "Select an agent to view details",
        .activeAgents: "Active Agents",
        .activeTasks: "Active Tasks",
        .systemOverview: "System Overview",

        // D4: Session History & Replay
        .sessionHistory: "Session History",
        .helpSessionHistory: "View and replay past sessions",
        .sessionReplay: "Session Replay",
        .replayMode: "Replay Mode",
        .stopReplay: "Stop Replay",
        .sessionRecording: "Recording",
        .sessionEnded: "Session Ended",
        .noSessions: "No sessions yet",
        .sessionDetails: "Session Details",
        .replayControls: "Replay Controls",
        .playReplay: "Play",
        .pauseReplay: "Pause",
        .replaySpeed: "Speed",
        .replayProgress: "Progress",
        .exportSession: "Export Session",
        .deleteSession: "Delete Session",
        .confirmDeleteSession: "Are you sure you want to delete this session?",
        .searchSessions: "Search Sessions",
        .searchPlaceholder: "Search task names, events...",
        .noSearchResults: "No matching sessions found",
        .sessionDuration: "Duration",
        .sessionTheme: "Theme",
        .sessionTasks: "Tasks",
        .sessionEvents: "Events",
        .sessionStarted: "Started",
        .sessionAgent: "Agent",
        .sessionCLIOutput: "CLI Output",

        // D5: Performance Metrics
        .performanceMetrics: "Performance",
        .helpPerformanceMetrics: "Toggle performance metrics panel",
        .sessionCost: "Session Cost",
        .tokenUsage: "Tokens",
        .tasksRun: "Tasks Run",
        .avgDuration: "Avg Duration",
        .resourceUsage: "Resources",
        .recentTasks: "Recent",
        .costPerTask: "Cost/Task",
        .durationComparison: "Duration Comparison",

        // SkillsMP
        .browseSkillsMP: "Browse SkillsMP",
        .skillsMPMarketplace: "SkillsMP Marketplace",
        .skillsMPSearch: "Search",
        .skillsMPAISearch: "AI Search",
        .skillsMPSearchPlaceholder: "Search skills...",
        .skillsMPAPIKey: "API Key",
        .skillsMPEnterAPIKey: "Enter SkillsMP API Key",
        .skillsMPSaveKey: "Save",
        .skillsMPGetKey: "Get API Key",
        .skillsMPNoAPIKey: "No API Key configured",
        .skillsMPNoAPIKeyDesc: "Set up your SkillsMP API key to browse community skills",
        .skillsMPImport: "Import",
        .skillsMPImported: "Skill Imported!",
        .skillsMPOpenInBrowser: "Open in Browser",
        .skillsMPStars: "Stars",
        .skillsMPUpdatedAt: "Updated",
        .skillsMPNoResults: "No matching skills found",
        .skillsMPLoading: "Searching...",
        .skillsMPError: "Search failed",
        .skillsMPSortByStars: "Sort by Stars",
        .skillsMPSortByDate: "Sort by Date",
        .skillsMPAlreadyImported: "Skill already imported",
        .addManualSkill: "Add custom skill manually...",

        // G3: Git Integration
        .gitIntegration: "Git Integration",
        .helpGitIntegration: "Git repository visualization",
        .gitDiff: "Diff",
        .gitBranches: "Branches",
        .gitCommits: "Commits",
        .gitPullRequest: "Pull Request",
        .gitNoRepository: "Current workspace is not a Git repository",
        .gitRepositoryClean: "Working directory clean, no changes",
        .gitStagedChanges: "Staged Changes",
        .gitUnstagedChanges: "Unstaged Changes",
        .gitCurrentBranch: "Current Branch",
        .gitRemoteBranch: "Remote Branch",
        .gitCreatePR: "Create Pull Request",
        .gitPRTitle: "PR Title",
        .gitPRBody: "PR Description",
        .gitPRPreview: "Preview",
        .gitSourceBranch: "Source Branch",
        .gitTargetBranch: "Target Branch",
        .gitShowInScene: "Show in 3D Scene",
        .gitHideFromScene: "Hide from 3D Scene",
        .gitFilesChanged: "Files Changed",
        .gitAdditions: "Additions",
        .gitDeletions: "Deletions",
        .gitCommitHash: "Commit Hash",
        .gitCommitAuthor: "Author",
        .gitCommitDate: "Date",
        .gitNoBranches: "No branch information",
        .gitNoCommits: "No commit history",
        .gitGhNotFound: "gh CLI not found. Install GitHub CLI",

        // G3: Git Commit & Push
        .gitCommitAndPush: "Commit & Push",
        .gitStageAll: "Stage All",
        .gitCommit: "Commit",
        .gitPush: "Push",
        .gitCommitMessage: "Commit Message",
        .gitGenerateMessage: "AI Generate Message",
        .gitGeneratingMessage: "AI Generating...",
        .gitCommitting: "Committing...",
        .gitPushing: "Pushing...",
        .gitCommitSuccess: "Commit successful!",
        .gitPushSuccess: "Push successful!",
        .gitCommitFailed: "Commit failed",
        .gitPushFailed: "Push failed",
        .gitNothingToCommit: "Nothing to commit",
        .gitNoRemote: "No remote configured",
        .gitStageAllFiles: "Stage all changed files",
        .gitStagedCount: "%d files staged",

        // E1: Agent Personality System
        .personalityEnergetic: "Energetic",
        .personalityCalm: "Calm",
        .personalityCurious: "Curious",
        .personalityFocused: "Focused",
        .personalitySocial: "Social",
        .personalityShy: "Shy",
        .moodHappy: "Happy",
        .moodNeutral: "Neutral",
        .moodStressed: "Stressed",
        .moodExcited: "Excited",
        .moodTired: "Tired",
        .personality: "Personality",
        .mood: "Mood",
        .relationships: "Relationships",
        .relationshipStranger: "Stranger",
        .relationshipAcquaintance: "Acquaintance",
        .relationshipColleague: "Colleague",
        .relationshipPartner: "Partner",
        .topCollaborators: "Top Collaborators",

        // G1: Multi-Model Support
        .modelOpus: "Opus",
        .modelSonnet: "Sonnet",
        .modelHaiku: "Haiku",
        .modelOpusDesc: "Most powerful model for complex tasks",
        .modelSonnetDesc: "Balanced model for speed and quality",
        .modelHaikuDesc: "Fastest model for simple tasks",
        .selectModel: "Select Model",
        .helpSelectModel: "Choose Claude model for new teams",
        .modelComparison: "Model Comparison",
        .helpModelComparison: "Compare outputs from different models",
        .modelSelector: "Model Selector",
        .typeComparisonPrompt: "Type comparison prompt...",
        .compare: "Compare",
        .modelComparisonResults: "Comparison Results",

        // G2: Prompt Templates
        .promptTemplates: "Prompt Templates",
        .helpPromptTemplates: "Browse and manage prompt templates",
        .templateGallery: "Template Gallery",
        .addTemplate: "Add Template",
        .editTemplate: "Edit Template",
        .deleteTemplate: "Delete Template",
        .templateName: "Template Name",
        .templateDescription: "Description",
        .templateContent: "Template Content",
        .templateCategory: "Category",
        .templateVariables: "Variables",
        .templatePreview: "Preview",
        .templateUsageCount: "Usage Count",
        .templateSaveSuccess: "Template Saved!",
        .templateDeleteConfirm: "Are you sure you want to delete this template?",
        .builtInTemplates: "Built-in",
        .customTemplates: "Custom",
        .recentTemplates: "Recent",
        .templateCategoryBugFix: "Bug Fix",
        .templateCategoryFeature: "Feature",
        .templateCategoryRefactor: "Refactor",
        .templateCategoryReview: "Review",
        .templateCategoryCustom: "Custom",
        .useTemplate: "Use Template",
        .browseAllTemplates: "Browse All Templates",
        .noTemplatesFound: "No matching templates found",
        .templateVariablePlaceholder: "Enter value...",
        .templateTags: "Tags",
        .searchTemplates: "Search templates...",

        // F1: Help Overlay
        .help: "Help",
        .helpShowHelp: "Show keyboard shortcuts guide (F1)",
        .helpOverlayTitle: "Keyboard Shortcuts Guide",
        .helpOKButton: "OK",
        .helpKeyboardShortcuts: "Keyboard Shortcuts",
        .helpMouseInteractions: "Mouse Interactions",
        .helpCameraControls: "Camera Controls",
        .helpFeatures: "Feature Panels",
        .helpKeyF1: "F1",
        .helpKeyF1Desc: "Show/hide this shortcuts guide",
        .helpKeyEscape: "Escape",
        .helpKeyEscapeDesc: "Exit first-person view mode",
        .helpClickAgent: "Click Agent",
        .helpClickAgentDesc: "Select agent and show details",
        .helpDoubleClickAgent: "Double-Click Agent",
        .helpDoubleClickAgentDesc: "Track and focus on agent",
        .helpRightClickAgent: "Right-Click Agent",
        .helpRightClickAgentDesc: "Open context menu (view logs, zoom, cancel task)",
        .helpDragTask: "Drag Task to Agent",
        .helpDragTaskDesc: "Drag pending task onto agent to assign",
        .helpCameraOrbit: "Mouse Drag",
        .helpCameraOrbitDesc: "Free orbit around 3D scene",
        .helpCameraZoom: "Double-Click Agent",
        .helpCameraZoomDesc: "Smooth zoom to agent",
        .helpCameraPresets: "Camera Presets",
        .helpCameraPresetsDesc: "Choose Overview, Close-Up, or Cinematic from toolbar menu",
        .helpCameraPiP: "Picture-in-Picture",
        .helpCameraPiPDesc: "Show second camera view in bottom-left corner",
        .helpCameraFirstPerson: "First-Person View",
        .helpCameraFirstPersonDesc: "View scene from agent's perspective",

        // F1: Background Music
        .backgroundMusic: "Background Music",
        .helpBackgroundMusic: "Toggle background music",
        .musicVolume: "Music Volume",
        .musicIntensity: "Music Intensity",
        .musicIntensityCalm: "Calm",
        .musicIntensityActive: "Active",

        // H1: RAG System
        .ragKnowledgeBase: "Knowledge Base",
        .helpRAGKnowledgeBase: "Manage local knowledge base and semantic search",
        .ragIndexing: "Indexing...",
        .ragIndexComplete: "Index Complete",
        .ragReindex: "Re-index",
        .ragClearIndex: "Clear Index",
        .ragSearch: "Search Knowledge Base",
        .ragSearchResults: "Search Results",
        .ragNoResults: "No matching results found",
        .ragDocuments: "Indexed Documents",
        .ragDatabaseSize: "Database Size",
        .ragLastUpdated: "Last Updated",
        .ragKnowledgeGraph: "Knowledge Graph",
        .ragShowInScene: "Show in 3D Scene",
        .ragHideFromScene: "Hide from 3D Scene",
        .ragAutoIndex: "Auto Index",
        .ragNoDocuments: "No indexed documents",
        .ragContextInjected: "Context Injected",
        .ragTotalLines: "Total Lines",
        .ragFileType: "File Type",
        .ragLineCount: "Lines",
        .ragFileSize: "File Size",
        .ragRelationships: "Dependencies",
        .ragIndexProgress: "Index Progress",

        // H5+H1 Unified Knowledge Search
        .unifiedSearch: "Unified Knowledge Search",
        .helpUnifiedSearch: "Unified RAG and semantic search knowledge base interface",
        .unifiedSearchPlaceholder: "Search knowledge base...",
        .unifiedSearchMode: "Search Mode",
        .unifiedSearchModeAll: "All",
        .unifiedSearchModeRAG: "RAG Keyword",
        .unifiedSearchModeSemantic: "Semantic",
        .unifiedSearchResultCount: "Results",
        .unifiedSearchProcessingTime: "Processing Time",
        .unifiedSearchNoResults: "No results found",
        .unifiedSearchNoResultsDesc: "Try different keywords or switch search mode",
        .unifiedSearchKeywordScore: "Keyword Score",
        .unifiedSearchSemanticScore: "Semantic Relevance",
        .unifiedSearchEntityScore: "Entity Match",
        .unifiedSearchRecencyScore: "Recency",
        .unifiedSearchRelationshipScore: "Relationship",
        .unifiedSearchCombinedScore: "Combined Score",
        .unifiedSearchSource: "Source",
        .unifiedSearchIntent: "Intent",
        .unifiedSearchConfidence: "Confidence",
        .unifiedSearchEntities: "Entities",
        .unifiedSearchInsertContext: "Insert Context",
        .unifiedSearchScoreDimensions: "Score Dimensions",
        .unifiedSearchExplanation: "Ranking Explanation",
        .unifiedSearchRunTest: "Run Test",
        .unifiedSearchTestResults: "Test Results",
        .unifiedSearchPerformance: "Performance",
        .unifiedSearchAccuracy: "Accuracy",

        // H2: Agent Memory System
        .agentMemory: "Agent Memory",
        .helpAgentMemory: "Manage AI agent memory system",
        .memoryTimeline: "Memory Timeline",
        .memorySearch: "Search memories...",
        .memoryTotalMemories: "Total Memories",
        .memoryTotalAgents: "Agents",
        .memoryDatabaseSize: "Database Size",
        .memoryLastUpdated: "Last Updated",
        .memoryNoMemories: "No memories yet",
        .memoryNoMemoriesDesc: "Memories will be recorded automatically when agents complete tasks.",
        .memoryCategory: "Category",
        .memoryRecent: "Recent Memories",
        .memoryClearAll: "Clear All",
        .memoryConfirmClear: "Are you sure you want to clear all agent memories?",
        .memoryAgents: "Agents",
        .memorySize: "Size",
        .memoryShared: "Shared",
        .memoryRecall: "Recall",

        // H3: Task Decomposition
        .taskDecomposition: "Task Decomposition",
        .helpTaskDecompositionStatus: "Toggle task decomposition status panel",
        .tdSubTasks: "Sub-tasks",
        .tdCompleted: "Completed",
        .tdNoDecomposition: "No task decomposition",
        .tdEnterTaskHint: "Enter a complex task to trigger auto-decomposition",
        // Auto-Decomposition Orchestration
        .autoDecomposition: "Auto Decomposition",
        .autoDecompositionToggle: "Auto Decomposition Mode",
        .orchDecomposing: "Decomposing...",
        .orchExecuting: "Executing",
        .orchSynthesizing: "Synthesizing...",
        .orchCompleted: "Completed",
        .orchFailed: "Failed",
        .orchWaveProgress: "Wave Progress",
        .orchCancelDecomposition: "Cancel Decomposition",
        .orchExecution: "Execution",
        .orchSubAgentStatus: "Sub-Agent Status",
        .orchPhase: "Phase",

        // H4: Prompt Optimization
        .promptOptimization: "Prompt Optimization",
        .helpPromptOptimization: "Analyze and optimize prompt quality",
        .promptAnalyze: "Analyze",
        .promptAnalyzeInput: "Enter prompt for quality analysis",
        .promptSuggestions: "Suggestions",
        .promptQuality: "Quality",
        .promptClarity: "Clarity",
        .promptSpecificity: "Specificity",
        .promptContext: "Context",
        .promptActionability: "Actionability",
        .promptTokenEfficiency: "Token Efficiency",
        .promptTokenCount: "Token Count",
        .promptEstimatedCost: "Est. Cost",
        .promptHistory: "History",
        .promptPatterns: "Patterns",
        .promptABTest: "A/B Test",
        .promptVersions: "Versions",
        .promptNoAnalysis: "No prompt analyzed yet",
        .promptNoHistory: "No prompt history",
        .promptNoPatternsYet: "Complete more tasks to detect patterns",
        .promptNoABTests: "No A/B tests yet",
        .promptNoVersions: "No version history",
        .promptTotalAnalyzed: "Analyzed",
        .promptAvgScore: "Avg Score",
        .promptShowInScene: "Show in 3D Scene",
        .promptHideFromScene: "Hide from 3D Scene",
        .promptViewDetails: "View Details",
        .promptRefreshPatterns: "Refresh",
        .promptPatternCount: "Count",
        .promptPatternSuccessRate: "Success Rate",
        .promptPatternAvgTokens: "Avg Tokens",
        .promptCreateABTest: "Create A/B Test",
        .promptABTaskDesc: "Task description...",
        .promptIssuesDetected: "Issues Detected",
        .promptRewriteSuggestion: "Rewrite Suggestion",
        .promptRewritePreview: "Rewrite Preview",
        .promptApplyRewrite: "Apply Rewrite",
        .promptFilterByTag: "Filter by Tag",
        .promptFilterByResult: "Filter by Result",
        .promptSortBy: "Sort by",
        .promptGroupBy: "Group by",
        .promptAllTags: "All Tags",
        .promptSuccessOnly: "Success Only",
        .promptFailedOnly: "Failed Only",
        .promptAllResults: "All Results",
        .promptStatistics: "Statistics",
        .promptSuccessRate: "Success Rate",
        .promptTotalTokens: "Total Tokens",
        .promptTotalCost: "Total Cost",
        .promptCategoryBreakdown: "Category Breakdown",
        .promptLastUsed: "Last Used",
        .promptAvgTokensPerPrompt: "Avg Tokens/Prompt",
        .promptGroupDaily: "Daily",
        .promptGroupWeekly: "Weekly",
        .promptGroupMonthly: "Monthly",
        .promptPromptDetail: "Prompt Detail",
        .promptDuration: "Duration",
        .promptTags: "Tags",
        .promptApplySuggestion: "Apply Suggestion",

        // I1: CI/CD Integration
        .cicdPipeline: "CI/CD Pipeline",
        .helpCICD: "CI/CD pipeline visualization and monitoring",
        .cicdPipelines: "Pipelines",
        .cicdBuildHistory: "Build History",
        .cicdStages: "Stages",
        .cicdBuildResult: "Build Result",
        .cicdDeployProgress: "Deploy Progress",
        .cicdPRReview: "PR Review",
        .cicdSuccessRate: "Success Rate",
        .cicdTotalRuns: "Total Runs",
        .cicdShowInScene: "Show in 3D Scene",
        .cicdHideFromScene: "Hide from 3D Scene",
        .cicdQueued: "Queued",
        .cicdInProgress: "In Progress",
        .cicdSuccess: "Success",
        .cicdFailure: "Failure",
        .cicdCancelled: "Cancelled",
        .cicdRefresh: "Refresh",
        .cicdStartMonitoring: "Start Monitoring",
        .cicdStopMonitoring: "Stop Monitoring",

        // I2: Test Coverage
        .testCoverage: "Test Coverage",
        .helpTestCoverage: "Test coverage visualization and analysis",
        .testOverallCoverage: "Overall Coverage",
        .testResults: "Test Results",
        .testPassed: "Passed",
        .testFailed: "Failed",
        .testSkipped: "Skipped",
        .testTotal: "Total",
        .testCoverageTrend: "Coverage Trend",
        .testRunTests: "Run Tests",
        .testNoData: "No test data",
        .testShowInScene: "Show in 3D Scene",
        .testHideFromScene: "Hide from 3D Scene",
        .testUncovered: "Uncovered",
        .testDuration: "Duration",
        .testSuiteName: "Test Suite",

        // I3: Code Quality
        .codeQuality: "Code Quality",
        .helpCodeQuality: "Code quality analysis and tech debt tracking",
        .cqErrors: "Errors",
        .cqWarnings: "Warnings",
        .cqInfo: "Info",
        .cqComplexity: "Complexity",
        .cqTechDebt: "Tech Debt",
        .cqRefactorSuggestions: "Refactor Suggestions",
        .cqLintIssues: "Lint Issues",
        .cqMaintainability: "Maintainability",
        .cqAnalyze: "Analyze Project",
        .cqShowInScene: "Show in 3D Scene",
        .cqHideFromScene: "Hide from 3D Scene",
        .cqTotalIssues: "Total Issues",
        .cqResolve: "Resolve",
        .cqEstimatedHours: "Est. Hours",

        // I4: Multi-Project Workspace
        .multiProject: "Multi-Project",
        .helpMultiProject: "Monitor multiple projects simultaneously",
        .mpProjects: "Projects",
        .mpAddProject: "Add Project",
        .mpRemoveProject: "Remove Project",
        .mpSwitchProject: "Switch Project",
        .mpActive: "Active",
        .mpNoProjects: "No projects",
        .mpSearch: "Search Tasks",
        .mpComparison: "Comparison",
        .mpTaskCount: "Tasks",
        .mpAgentCount: "Agents",

        // I5: Docker / Dev Environment
        .dockerContainers: "Docker Containers",
        .helpDocker: "Docker container monitoring and management",
        .dockerLogs: "Container Logs",
        .dockerResources: "Resources",
        .dockerRunning: "Running",
        .dockerStopped: "Stopped",
        .dockerMemory: "Memory",
        .dockerCPU: "CPU",
        .dockerNetwork: "Network",
        .dockerStart: "Start",
        .dockerStop: "Stop",
        .dockerRestart: "Restart",
        .dockerNoContainers: "No Docker containers",
        .dockerShowInScene: "Show in 3D Scene",
        .dockerHideFromScene: "Hide from 3D Scene",
        .dockerNotAvailable: "Docker not installed or not running",
        .dockerStartMonitoring: "Start Monitoring",
        .dockerStopMonitoring: "Stop Monitoring",

        // J1: Code Knowledge Graph
        .codeKnowledgeGraph: "Code Knowledge Graph",
        .helpCodeKnowledgeGraph: "File dependency and architecture visualization",
        .ckgTotalFiles: "Files",
        .ckgDependencies: "Dependencies",
        .ckgAvgComplexity: "Avg Complexity",
        .ckgMostConnected: "Most Connected",
        .ckgAnalyzing: "Analyzing...",
        .ckgAnalyze: "Analyze Project",
        .ckgFileDependencies: "File Dependencies",
        .ckgFunctionCalls: "Function Calls",
        .ckgArchitectureOverview: "Architecture Overview",
        .ckgShowInScene: "Show in 3D Scene",
        .ckgHideFromScene: "Hide from 3D Scene",
        .ckgNoFiles: "No file nodes",
        .ckgNoFunctionCalls: "No function call chains",

        // J2: Collaboration Visualization
        .collabVisualization: "Collaboration Viz",
        .helpCollabVisualization: "Multi-agent collaboration paths and efficiency visualization",
        .collabActivePaths: "Active Paths",
        .collabConflicts: "Conflicts",
        .collabHandoffs: "Handoffs",
        .collabEfficiency: "Efficiency",
        .collabDataFlow: "Data Flow",
        .collabSharedResources: "Shared Resources",
        .collabTaskHandoffs: "Task Handoffs",
        .collabRadarChart: "Efficiency Radar",
        .collabActive: "Active",
        .collabStartMonitoring: "Start Monitoring",
        .collabStopMonitoring: "Stop Monitoring",
        .collabShowInScene: "Show in 3D Scene",
        .collabHideFromScene: "Hide from 3D Scene",
        .collabNoPaths: "No collaboration paths",
        .collabNoResources: "No shared resources",
        .collabNoHandoffs: "No task handoffs",
        .collabNoMetrics: "No efficiency metrics",

        // J3: AR/VR Support
        .arvrSettings: "AR/VR Settings",
        .helpARVR: "AR/VR immersive experience settings",
        .arvrPlatform: "Platform",
        .arvrImmersiveLevel: "Immersive Level",
        .arvrControls: "Controls",
        .arvrGestureControl: "Gesture Control",
        .arvrGestureControlDesc: "Interact with 3D agents using gestures",
        .arvrHandTracking: "Hand Tracking",
        .arvrHandTrackingDesc: "Precise hand motion tracking",
        .arvrSpatialAudio: "Spatial Audio",
        .arvrSpatialAudioDesc: "Directional audio based on 3D position",
        .arvrPassthrough: "Passthrough",
        .arvrPassthroughDesc: "Show real environment with virtual objects overlay",
        .arvrGestures: "Gesture Types",
        .arvrVisionOSNotAvailable: "visionOS features not available on this device. Requires Apple Vision Pro.",

        // J4: Data Flow Animation
        .dataFlowAnimation: "Data Flow Animation",
        .helpDataFlow: "Token stream and tool call chain visualization",
        .dfTokensIn: "Tokens In",
        .dfTokensOut: "Tokens Out",
        .dfToolCalls: "Tool Calls",
        .dfActiveFlows: "Active Flows",
        .dfTokenStream: "Token Stream",
        .dfIOPipeline: "I/O Pipeline",
        .dfToolChain: "Tool Chain",
        .dfShowInScene: "Show in 3D Scene",
        .dfHideFromScene: "Hide from 3D Scene",
        .dfNoFlows: "No data flows",
        .dfNoPipeline: "No pipeline data",
        .dfNoToolCalls: "No tool calls",
        .dfAvgResponseTime: "Avg Response",

        // L1: Workflow Automation
        .wfWorkflowEngine: "Workflow Engine",
        .helpWorkflow: "Workflow automation editor and management",
        .wfWorkflows: "Workflows",
        .wfTemplates: "Templates",
        .wfHistory: "History",
        .wfWorkflowName: "Workflow Name",
        .wfWorkflowDesc: "Description",
        .wfCreateWorkflow: "Create Workflow",
        .wfActiveWorkflows: "Active Workflows",
        .wfTotalExecutions: "Total Executions",
        .wfSuccessRate: "Success Rate",
        .wfNoWorkflows: "No workflows",
        .wfUseTemplate: "Use Template",
        .wfShowInScene: "Show in 3D Scene",
        .wfHideFromScene: "Hide from 3D Scene",

        // L2: Smart Scheduling
        .ssSmartScheduling: "Smart Scheduling",
        .helpSmartScheduling: "Smart task scheduling and resource prediction",
        .ssSchedule: "Schedule",
        .ssOptimizations: "Optimizations",
        .ssTimeline: "Timeline",
        .ssScheduledTasks: "Scheduled Tasks",
        .ssCompletedOnTime: "On Time",
        .ssResourceUtil: "Resource Util",
        .ssAutoSchedule: "Auto Schedule",
        .ssOptimize: "Optimize",
        .ssTaskName: "Task Name",
        .ssAddTask: "Add Task",
        .ssBatchTasks: "Batch Tasks",
        .ssPeakHours: "Peak Hours",

        // L3: Anomaly Detection
        .adAnomalyDetection: "Anomaly Detection",
        .helpAnomalyDetection: "Anomaly detection and self-healing system",
        .adAlerts: "Alerts",
        .adPatterns: "Error Patterns",
        .adRetryConfig: "Retry Config",
        .adActiveAlerts: "Active Alerts",
        .adResolved: "Resolved",
        .adRetrySuccess: "Retry Success",
        .adMonitoring: "Monitoring",
        .adResolve: "Resolve",
        .adResolveAll: "Resolve All",
        .adNoAlerts: "No alerts",
        .adNoPatterns: "No error patterns",

        // L4: MCP Integration
        .mcpIntegration: "MCP Integration",
        .helpMCP: "Model Context Protocol server management",
        .mcpServers: "Servers",
        .mcpTools: "Tools",
        .mcpCallHistory: "Call History",
        .mcpTotalCalls: "Total Calls",
        .mcpAvgResponse: "Avg Response",
        .mcpServerName: "Server Name",
        .mcpServerURL: "Server URL",
        .mcpAddServer: "Add Server",
        .mcpConnect: "Connect",
        .mcpDisconnect: "Disconnect",
        .mcpNoServers: "No MCP servers",
        .mcpNoTools: "No tools",
    ]
}
