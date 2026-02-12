# Claude Code 3D Agent UI — Flutter 版本遷移工項

> 原始專案：macOS SwiftUI + SceneKit 應用（13,351 行 Swift 代碼）
> 目標：Flutter 跨平台應用（macOS / Windows / Linux / iOS / Android / Web）
> 文件日期：2026-02-12

---

## 一、專案總覽

### 1.1 原始專案架構

| 面向         | 原始技術                      | Flutter 對應方案                       |
|-------------|------------------------------|---------------------------------------|
| 語言         | Swift 5.9+                   | Dart 3.x                             |
| UI 框架      | SwiftUI                      | Flutter Widget                        |
| 3D 引擎      | SceneKit                     | Fluorite (fluorite.game) — Flutter 首個主機級 3D 引擎 |
| 狀態管理     | ObservableObject + @Published | Riverpod 2.x / Bloc                  |
| 音訊         | AVAudioEngine                | audioplayers / just_audio             |
| 進程管理     | Foundation Process           | dart:io Process                       |
| 本地儲存     | UserDefaults                 | shared_preferences / Hive             |
| 多窗口       | SwiftUI WindowGroup          | desktop_multi_window                  |
| 通知         | macOS UNUserNotification     | flutter_local_notifications           |
| 本地化       | 手動 L10n.swift               | flutter_localizations (ARB)           |

### 1.2 原始專案規模

- **Swift 檔案：** 151 個
- **代碼行數：** ~13,351 行
- **Models：** 26 個資料模型
- **Services：** 25 個業務邏輯服務
- **Views：** 46 個視圖
- **3D 模組：** 11 個核心 + 9 主題 + 14 動畫 + 6 特效
- **預估 Flutter 行數：** ~18,000-22,000 行（含 3D 部分增加）

---

## 二、技術選型建議

### 2.1 3D 引擎選項評估

| 方案                  | 優點                                | 缺點                                    | 推薦度 |
|----------------------|-------------------------------------|----------------------------------------|-------|
| **Fluorite (fluorite.game)** | Flutter 首個主機級引擎、ECS 架構、Filament 渲染器、Vulkan 支援、物理精確光照、Hot Reload、Multi-View | 較新的引擎生態 | ★★★★ |
| **flame_3d**         | Flutter 生態原生、輕量                | 功能有限、無原生 SceneKit 等級能力         | ★★☆  |
| **three_dart**       | Three.js 移植、功能全面               | 社群較小、效能需驗證                      | ★★☆  |
| **flutter_3d_controller** | 載入 glTF/OBJ 模型、簡單易用     | 僅展示模型、無程式化建構能力               | ★☆☆  |
| **Flutter + Unity (via flutter_unity_widget)** | Unity 成熟 3D 引擎 | 包體積大、授權費用、複雜度高 | ★★☆  |
| **自建 OpenGL/Vulkan 渲染層** | 完全控制、最佳效能            | 開發成本極高                             | ★☆☆  |
| **three.js WebView (Web 層)** | 成熟 3D 生態、社群大          | 效能受限、雙向通訊開銷                    | ★★☆  |
| **Flame Engine (2D 替代)** | Flutter 原生、穩定、效能好      | 需放棄 3D 改為 2.5D/等距視角              | ★★☆  |

**推薦方案：**
- **首選：** `Fluorite` (https://fluorite.game/) — Flutter 首個主機級 3D 遊戲引擎，基於 Google Filament 渲染器，支援 ECS 架構、Vulkan 現代圖形 API、物理精確光照、自訂 Shader、Hot Reload、Multi-View，能力超越原始 SceneKit
- **備選：** `Flame Engine` — 如接受 2.5D 等距視角，開發效率高、跨平台穩定

### 2.2 狀態管理選型

| 方案          | 優點                          | 推薦度 |
|--------------|-------------------------------|-------|
| **Riverpod** | 編譯安全、支援 code-gen、社群活躍 | ★★★  |
| **Bloc**     | 嚴格架構、適合大型專案           | ★★★  |
| **GetX**     | 輕量快速                       | ★★☆  |
| **Provider** | 簡單、官方推薦                  | ★★☆  |

**推薦方案：** `Riverpod 2.x` + `flutter_riverpod` — 適合本專案的複雜狀態（15+ 服務管理器）

### 2.3 完整依賴清單建議

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 狀態管理
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0

  # 3D 渲染
  fluorite:                     # Fluorite 3D 引擎 (https://fluorite.game/)
                                # ECS 架構 + Filament 渲染器 + Vulkan

  # 音訊
  just_audio: ^0.9.36
  audio_session: ^0.1.18

  # 本地儲存
  hive: ^4.0.0
  hive_flutter: ^2.0.0
  shared_preferences: ^2.2.2

  # 多窗口 (Desktop)
  desktop_multi_window: ^0.2.0

  # 通知
  flutter_local_notifications: ^17.0.0

  # 本地化
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0

  # 進程管理 (Desktop)
  process_run: ^1.0.0

  # UI 輔助
  flutter_animate: ^4.5.0      # 動畫
  google_fonts: ^6.1.0

  # Git 整合
  # 透過 dart:io Process 呼叫 git CLI

dev_dependencies:
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.0
  hive_generator: ^2.0.0
```

---

## 三、模組遷移工項（共 12 個階段）

### 階段 P0：專案基礎建設（預估 3 天）

| 工項編號 | 工項名稱 | 說明 | 預估工時 |
|---------|---------|------|---------|
| P0-01 | Flutter 專案初始化 | 建立 Flutter 專案、設定目錄結構、配置平台 | 2h |
| P0-02 | 依賴套件安裝 | 安裝所有 pub 依賴、驗證版本相容性 | 1h |
| P0-03 | 目錄結構規劃 | 按功能模組劃分目錄（見下方結構） | 1h |
| P0-04 | 主題與顏色系統 | 建立 AppTheme、ColorPalette、全域樣式常數 | 3h |
| P0-05 | 本地化基礎設施 | 設定 ARB 檔案、flutter_localizations、英文/繁中 | 4h |
| P0-06 | 路由與導航 | 設定 GoRouter 或自訂導航（場景選擇 ↔ 主頁面） | 2h |
| P0-07 | 基礎 Riverpod 架構 | 建立 ProviderScope、核心 Provider 結構 | 3h |
| P0-08 | 平台適配層 | 建立 Platform Channel 抽象（Desktop vs Mobile） | 2h |

**目錄結構：**
```
lib/
├── main.dart
├── app/
│   ├── app.dart                    # MaterialApp / CupertinoApp
│   ├── router.dart                 # 路由配置
│   └── theme.dart                  # 全域主題
│
├── models/                         # 資料模型（26 個）
│   ├── agent.dart
│   ├── agent_task.dart
│   ├── agent_status.dart
│   ├── agent_role.dart
│   ├── agent_personality.dart
│   ├── agent_stats.dart
│   ├── claude_model.dart
│   ├── scene_theme.dart
│   ├── achievement.dart
│   ├── cosmetic_item.dart
│   ├── prompt_template.dart
│   ├── timeline_event.dart
│   ├── git_models.dart
│   ├── session_record.dart
│   ├── exploration_item.dart
│   ├── scene_configuration.dart
│   ├── workspace_configuration.dart
│   ├── skills_mp_skill.dart
│   ├── user_question.dart
│   └── plan_review_data.dart
│
├── providers/                      # Riverpod Providers
│   ├── app_state_provider.dart
│   ├── agent_provider.dart
│   ├── task_provider.dart
│   ├── theme_provider.dart
│   ├── audio_provider.dart
│   ├── git_provider.dart
│   └── ...
│
├── services/                       # 業務邏輯服務（25 個）
│   ├── cli_process_manager.dart
│   ├── agent_coordinator.dart
│   ├── agent_factory.dart
│   ├── sound_manager.dart
│   ├── background_music_manager.dart
│   ├── localization_manager.dart
│   ├── window_manager.dart
│   ├── timeline_manager.dart
│   ├── coin_manager.dart
│   ├── skill_manager.dart
│   ├── exploration_manager.dart
│   ├── notification_manager.dart
│   ├── git_integration_manager.dart
│   ├── performance_metrics_manager.dart
│   ├── session_history_manager.dart
│   ├── prompt_template_manager.dart
│   ├── configuration_loader.dart
│   ├── workspace_manager.dart
│   ├── dangerous_command_classifier.dart
│   └── skills_mp_service.dart
│
├── views/                          # UI 視圖
│   ├── content_view.dart
│   ├── scene_selection_view.dart
│   ├── components/
│   │   ├── prompt_input_bar.dart
│   │   ├── model_selector_button.dart
│   │   ├── workspace_picker.dart
│   │   ├── status_indicator.dart
│   │   └── task_progress_bar.dart
│   ├── overlays/                   # 覆蓋 / Sheet 視圖（27 個）
│   │   ├── achievement_gallery_view.dart
│   │   ├── cosmetic_shop_view.dart
│   │   ├── agent_stats_dashboard_view.dart
│   │   ├── mini_map_overlay.dart
│   │   ├── task_queue_overlay.dart
│   │   ├── performance_metrics_overlay.dart
│   │   ├── streak_overlay.dart
│   │   ├── git_integration_view.dart
│   │   ├── prompt_template_gallery_view.dart
│   │   ├── model_comparison_view.dart
│   │   ├── session_history_view.dart
│   │   ├── skill_book_view.dart
│   │   ├── help_overlay_view.dart
│   │   ├── plan_review_sheet.dart
│   │   ├── ask_user_question_sheet.dart
│   │   └── ...
│   ├── panels/                     # 側邊欄面板
│   │   ├── side_panel_view.dart
│   │   ├── agent_detail_view.dart
│   │   ├── cli_output_view.dart
│   │   ├── task_list_view.dart
│   │   ├── agent_hierarchy_view.dart
│   │   └── task_team_view.dart
│   ├── windows/                    # 多窗口 (Desktop)
│   │   ├── cli_output_window.dart
│   │   ├── agent_detail_window.dart
│   │   └── floating_monitor_view.dart
│   └── timeline/
│       ├── timeline_view.dart
│       ├── timeline_filter_bar.dart
│       └── timeline_event_dot.dart
│
├── scene_3d/                       # 3D 渲染模組
│   ├── scene_manager.dart          # 主場景管理
│   ├── scene_view_widget.dart      # FluoriteView Widget 包裝
│   ├── scene_coordinator.dart      # 交互協調
│   ├── themes/                     # 9 個主題構建器
│   │   ├── scene_theme_builder.dart
│   │   ├── theme_builder_factory.dart
│   │   ├── command_center_theme.dart
│   │   ├── floating_islands_theme.dart
│   │   ├── dungeon_theme.dart
│   │   ├── space_station_theme.dart
│   │   ├── cyberpunk_city_theme.dart
│   │   ├── medieval_castle_theme.dart
│   │   ├── underwater_lab_theme.dart
│   │   ├── japanese_garden_theme.dart
│   │   └── minecraft_overworld_theme.dart
│   ├── voxel/                      # 體素角色系統
│   │   ├── voxel_character.dart
│   │   ├── voxel_builder.dart
│   │   ├── voxel_template.dart
│   │   ├── voxel_palette.dart
│   │   ├── cosmetic_hat_builder.dart
│   │   ├── cosmetic_particle_trail.dart
│   │   └── name_tag.dart
│   ├── animation/                  # 動畫控制器（16 種）
│   │   ├── agent_animation_controller.dart
│   │   ├── idle_animation.dart
│   │   ├── working_animation.dart
│   │   ├── completed_animation.dart
│   │   ├── error_animation.dart
│   │   ├── walk_to_desk_animation.dart
│   │   ├── teleport_animation.dart
│   │   ├── waving_animation.dart
│   │   ├── sleeping_animation.dart
│   │   ├── thinking_animation.dart
│   │   ├── visit_agent_animation.dart
│   │   ├── collaboration_animation.dart
│   │   ├── disband_animation.dart
│   │   ├── reviewing_plan_animation.dart
│   │   ├── requesting_permission_animation.dart
│   │   └── waiting_for_answer_animation.dart
│   ├── effects/                    # 視覺特效
│   │   ├── particle_effect_builder.dart
│   │   ├── chat_bubble_manager.dart
│   │   ├── chat_bubble_node.dart
│   │   ├── day_night_cycle_controller.dart
│   │   ├── weather_effect_builder.dart
│   │   ├── git_visualization_builder.dart
│   │   └── interactive_object.dart
│   └── environment/                # 環境構建
│       ├── room_builder.dart
│       ├── desk_builder.dart
│       ├── monitor_builder.dart
│       ├── lighting_setup.dart
│       └── multi_team_layout_calculator.dart
│
├── utils/                          # 工具類
│   ├── color_extensions.dart
│   ├── vector3_extensions.dart
│   └── platform_utils.dart
│
└── l10n/                           # 本地化資源
    ├── app_en.arb
    └── app_zh_TW.arb
```

---

### 階段 P1：資料模型層（預估 3 天）

| 工項編號 | 工項名稱 | 原始檔案 | 說明 | 預估工時 |
|---------|---------|---------|------|---------|
| P1-01 | Agent 模型 | Agent.swift | 代理實體：ID、名稱、角色、狀態、外觀、位置、技能 | 2h |
| P1-02 | AgentTask 模型 | AgentTask.swift | 任務：ID、標題、狀態、進度、優先級、團隊指派 | 1.5h |
| P1-03 | 列舉型別 | AgentStatus/Role/Personality | AgentStatus、AgentRole、AgentPersonality、ClaudeModel | 2h |
| P1-04 | AgentStats 模型 | AgentStats.swift | 統計：XP、等級、連勝、任務計數、最佳連勝 | 1h |
| P1-05 | SceneTheme 模型 | SceneTheme.swift | 9 個場景主題定義、顏色配置 | 1.5h |
| P1-06 | 遊戲化模型 | Achievement/CosmeticItem | 成就系統、化妝品（帽子、粒子、皮膚、頭銜） | 2h |
| P1-07 | 範本與事件模型 | PromptTemplate/TimelineEvent | 提示詞範本、時間線事件 | 1.5h |
| P1-08 | Git 模型 | GitModels.swift | Git diff、分支、提交、PR 相關資料結構 | 1.5h |
| P1-09 | 其他模型 | Session/Exploration/Config... | SessionRecord、ExplorationItem、WorkspaceConfig 等 | 2h |
| P1-10 | Hive 序列化 | - | 為所有需持久化的模型加入 Hive TypeAdapter | 3h |
| P1-11 | 模型單元測試 | - | 驗證序列化/反序列化、預設值、邊界條件 | 3h |

**技術要點：**
- Dart 使用 `freezed` 套件產生 immutable data class
- 使用 `json_serializable` 處理 JSON 序列化
- 列舉使用 Dart `enum` 搭配 `enhanced enums`

---

### 階段 P2：服務層 — 核心業務邏輯（預估 5 天）

| 工項編號 | 工項名稱 | 原始檔案 | 說明 | 預估工時 |
|---------|---------|---------|------|---------|
| P2-01 | CLIProcessManager | CLIProcessManager.swift | 使用 `dart:io Process` 啟動 Claude CLI、流式讀取 stdout/stderr、解析 JSON 事件 | 6h |
| P2-02 | AgentCoordinator | AgentCoordinator.swift | 代理團隊協調：建立團隊、分配任務、管理子代理 | 3h |
| P2-03 | AgentFactory | AgentFactory.swift | 代理生成工廠：隨機名稱、外觀、角色分配 | 2h |
| P2-04 | TimelineManager | TimelineManager.swift | 時間線事件紀錄、5000 事件上限、篩選、匯出 | 2h |
| P2-05 | CoinManager | CoinManager.swift | 遊戲幣系統：賺取、消費、化妝品持久化 | 2h |
| P2-06 | SkillManager | SkillManager.swift | 技能安裝/啟用/停用、使用統計 | 2h |
| P2-07 | ExplorationManager | ExplorationManager.swift | 迷你地圖霧隱、探索物品發現、獎勵 | 3h |
| P2-08 | GitIntegrationManager | GitIntegrationManager.swift | Git 狀態監控、diff 解析、分支追蹤 | 4h |
| P2-09 | PerformanceMetricsManager | PerformanceMetrics... | 令牌追蹤、成本估算、進程監控 | 2h |
| P2-10 | SessionHistoryManager | SessionHistoryManager.swift | 會話記錄、重放、快照保存/恢復 | 3h |
| P2-11 | PromptTemplateManager | PromptTemplateManager.swift | 範本 CRUD、變數替換 `{{var}}`、持久化 | 2h |
| P2-12 | ConfigurationLoader | ConfigurationLoader.swift | 從 JSON 載入代理/任務/場景配置 | 1.5h |
| P2-13 | WorkspaceManager | WorkspaceManager.swift | 工作目錄管理、目錄切換 | 1.5h |
| P2-14 | DangerousCommandClassifier | DangerousCommand... | 危險命令偵測（rm、rm -rf 等） | 1h |
| P2-15 | SkillsMPService | SkillsMPService.swift | SkillsMP API 呼叫、技能瀏覽與導入 | 2h |
| P2-16 | 服務層單元測試 | - | 核心服務的單元測試（mock CLI、mock Git） | 4h |

**技術要點：**
- `CLIProcessManager` 是最關鍵的服務，需處理非阻塞流讀取
- 使用 `StreamController` 對 CLI 輸出進行事件驅動處理
- Desktop 平台使用 `dart:io`，Web 平台需 WebSocket 代理層
- Git 操作透過 `Process.run('git', [...])` 執行

---

### 階段 P3：服務層 — 音訊與通知（預估 2 天）

| 工項編號 | 工項名稱 | 原始檔案 | 說明 | 預估工時 |
|---------|---------|---------|------|---------|
| P3-01 | SoundManager | SoundManager.swift | 9 種音效播放（完成、錯誤、升級、硬幣等） | 3h |
| P3-02 | BackgroundMusicManager | BackgroundMusicManager.swift | 程式化音樂生成（AVAudioEngine → just_audio + 合成） | 6h |
| P3-03 | NotificationManager | NotificationManager.swift | 跨平台本地通知（任務完成、升級、權限請求） | 2h |
| P3-04 | WindowManager | WindowManager.swift | Desktop 多窗口管理（desktop_multi_window） | 3h |

**技術要點：**
- 背景音樂的程式化合成是最大挑戰
  - 原始使用 AVAudioEngine 的 oscillator + sampler
  - Flutter 方案：`just_audio` + 預生成的音頻片段，或使用 `flutter_midi` 進行 MIDI 合成
  - 備選：將每個主題的音樂預錄成 asset 檔案

---

### 階段 P4：狀態管理層（預估 3 天）

| 工項編號 | 工項名稱 | 原始檔案 | 說明 | 預估工時 |
|---------|---------|---------|------|---------|
| P4-01 | AppState Provider | AppState.swift | 25+ 狀態變數轉為 Riverpod StateNotifier / AsyncNotifier | 4h |
| P4-02 | Agent Provider | - | 代理列表管理、選擇、新增、刪除 | 2h |
| P4-03 | Task Provider | - | 任務管理、狀態更新、進度追蹤 | 2h |
| P4-04 | Theme Provider | - | 主題切換、持久化 | 1h |
| P4-05 | Audio Provider | - | 音效/音樂控制狀態 | 1h |
| P4-06 | Git Provider | - | Git 監控狀態、diff 資料 | 2h |
| P4-07 | Gamification Provider | - | XP、等級、成就、硬幣、連勝 | 2h |
| P4-08 | UI State Provider | - | 面板可見性、覆蓋層控制、相機狀態 | 2h |
| P4-09 | Session Provider | - | 會話歷史、重放狀態 | 1.5h |
| P4-10 | Provider 整合測試 | - | 驗證 Provider 間的依賴與反應性 | 3h |

**技術要點：**
- 原始 AppState 有 25+ 個 @Published 變數，需拆分為多個 Provider
- 使用 `Riverpod` 的 `family` modifier 處理代理/任務的 ID 查詢
- 使用 `AutoDispose` 管理生命週期

---

### 階段 P5：3D 渲染引擎 — 基礎設施（預估 5 天）

| 工項編號 | 工項名稱 | 原始檔案 | 說明 | 預估工時 |
|---------|---------|---------|------|---------|
| P5-01 | 3D Widget 容器 | SceneKitView.swift | 建立 Flutter Widget 包裝 Fluorite 的 `FluoriteView` | 4h |
| P5-02 | 相機系統 | CommandCenterScene (camera) | 透視相機、3 種預設、自由軌道、縮放 | 4h |
| P5-03 | 光照系統 | LightingSetup.swift | 環境光 + 主聚光 + 2 強調光、陰影 | 3h |
| P5-04 | 場景管理器 | CommandCenterScene.swift | 主場景管理：建立/銷毀/更新場景 | 6h |
| P5-05 | 互動系統 | SceneCoordinator.swift + HoverTracking | 射線投射命中測試、點擊選擇、懸停偵測 | 4h |
| P5-06 | 相機動畫 | - | 平滑過渡、縮放到代理、第一人稱模式 | 3h |
| P5-07 | 3D 渲染效能測試 | - | 基準效能測試、FPS 監控 | 2h |

**技術要點：**
- Fluorite 使用 Google Filament 渲染器，支援 Vulkan/Metal/OpenGL 後端
- Flutter 透過 `FluoriteView` Widget 嵌入 3D 場景，支援 Multi-View
- Fluorite 內建觸控互動區域（Touch Interaction），可在 Blender 中定義可點擊區域
- 相機控制使用 Fluorite 的 ECS 架構，透過 Component 管理相機行為
- 支援 Hot Reload，場景變更可在數幀內即時更新

---

### 階段 P6：3D 渲染引擎 — 體素角色（預估 5 天）

| 工項編號 | 工項名稱 | 原始檔案 | 說明 | 預估工時 |
|---------|---------|---------|------|---------|
| P6-01 | VoxelBuilder | VoxelBuilder.swift | 基礎體素塊構建（Box Geometry + Material） | 3h |
| P6-02 | VoxelCharacter | VoxelCharacterNode.swift | 完整角色組合：頭/身體/手臂/腿/配件 | 6h |
| P6-03 | VoxelTemplate | VoxelCharacterTemplate.swift | 角色模板：身體各部分尺寸定義 | 2h |
| P6-04 | VoxelPalette | VoxelPalette.swift | 顏色系統：角色外觀→顏色映射 | 1h |
| P6-05 | 角色徽章系統 | VoxelCharacterNode (badges) | 角色徽章、模型徽章、等級徽章 | 3h |
| P6-06 | NameTag | NameTagNode.swift | 名字標籤：Billboard 約束文字 | 2h |
| P6-07 | 狀態指示器 | VoxelCharacterNode (status) | 浮動球體、顏色編碼、動畫 | 2h |
| P6-08 | 配件系統 | VoxelCharacterNode (accessories) | 眼鏡、耳機、帽子、皇冠、斗篷、光環 | 4h |
| P6-09 | 化妝品帽子 | CosmeticHatBuilder.swift | 聖誕帽、派對帽、騎士頭盔、巫師帽 | 3h |
| P6-10 | 化妝品粒子尾跡 | CosmeticParticleTrail.swift | 火焰、冰晶、愛心、閃電、彩虹 | 4h |
| P6-11 | 角色渲染測試 | - | 所有角色外觀組合的視覺驗證 | 2h |

**技術要點：**
- 使用 Fluorite 的 ECS Entity + Renderable Component 建構體素幾何體
- Filament 提供物理精確材質（PBR），支援自訂 Shader
- 節點層級透過 Entity 階層組合
- Billboard 效果透過 Fluorite 的 Camera-facing Component 實現
- 粒子效果使用 Fluorite 粒子系統或自訂 Shader

---

### 階段 P7：3D 渲染引擎 — 動畫系統（預估 4 天）

| 工項編號 | 工項名稱 | 原始檔案 | 說明 | 預估工時 |
|---------|---------|---------|------|---------|
| P7-01 | AnimationController | AgentAnimationController.swift | 動畫狀態機：根據 AgentStatus 切換動畫 | 3h |
| P7-02 | Idle 動畫 | IdleAnimation.swift | 靜待：手臂輕微擺動 | 1h |
| P7-03 | Working 動畫 | WorkingAnimation.swift | 工作中：頭部搖動、手臂活動 | 1.5h |
| P7-04 | Completed 動畫 | CompletedAnimation.swift | 完成：舉臂、跳躍 + 粒子爆發 | 2h |
| P7-05 | Error 動畫 | ErrorAnimation.swift | 錯誤：後退、手臂下降 + 煙霧 | 1.5h |
| P7-06 | WalkToDesk 動畫 | WalkToDeskAnimation.swift | 行走：腿臂交替、身體搖擺、路徑計算 | 3h |
| P7-07 | Teleport 動畫 | TeleportAnimation.swift | 傳送：旋轉縮放淡出 + 門戶效果 | 3h |
| P7-08 | 個性空閒行為 | SleepingAnimation 等 | 6 種個性行為：伸展、環顧、咖啡、敲腳、揮手、哈欠 | 4h |
| P7-09 | 其他狀態動畫 | Thinking/Reviewing/Requesting... | 思考、審查計劃、請求權限、等待答案 | 3h |
| P7-10 | VisitAgent 動畫 | VisitAgentAnimation.swift | 協作訪問：行走到目標代理再返回 | 2h |
| P7-11 | Disband 動畫 | DisbandAnimation.swift | 團隊解散：淡出 + 縮小 + 交錯 | 2h |
| P7-12 | 動畫系統整合測試 | - | 驗證狀態切換、動畫混合、時序正確 | 2h |

**技術要點：**
- 使用 Fluorite ECS 的 System 驅動每幀動畫更新
- 關節旋轉透過 Transform Component 設定旋轉值
- 行走使用正弦波函數計算步伐
- 傳送效果使用 Tween 插值，結合 Fluorite 的 Hot Reload 快速迭代動畫參數

---

### 階段 P8：3D 渲染引擎 — 環境與主題（預估 6 天）

| 工項編號 | 工項名稱 | 原始檔案 | 說明 | 預估工時 |
|---------|---------|---------|------|---------|
| P8-01 | SceneThemeBuilder 介面 | SceneThemeBuilder.swift | 定義主題構建器抽象介面 | 1h |
| P8-02 | ThemeBuilderFactory | SceneThemeBuilderFactory.swift | 工廠模式：根據主題枚舉創建構建器 | 1h |
| P8-03 | RoomBuilder | RoomBuilder.swift | 基礎房間：地板 + 網格線 | 2h |
| P8-04 | DeskBuilder | DeskBuilder.swift | 工作站：辦公桌幾何體 | 2h |
| P8-05 | MonitorBuilder | MonitorBuilder.swift | 顯示器：螢幕 + 邊框 + 支架 + 動態內容 | 3h |
| P8-06 | MultiTeamLayout | MultiTeamLayoutCalculator.swift | 多團隊佈局計算、連接線、團隊標籤 | 3h |
| P8-07 | CommandCenter 主題 | CommandCenterThemeBuilder.swift | 高科技控制室主題 | 3h |
| P8-08 | FloatingIslands 主題 | FloatingIslandsThemeBuilder.swift | 浮島主題：雲層、橋樑 | 4h |
| P8-09 | Dungeon 主題 | DungeonThemeBuilder.swift | 地下室主題：火焰、寶箱 | 3h |
| P8-10 | SpaceStation 主題 | SpaceStationThemeBuilder.swift | 太空站主題：金屬地板、全息顯示 | 3h |
| P8-11 | CyberpunkCity 主題 | CyberpunkCityThemeBuilder.swift | 賽博朋克主題：霓虹、雨 | 4h |
| P8-12 | MedievalCastle 主題 | MedievalCastleThemeBuilder.swift | 城堡主題：石牆、旗幟 | 3h |
| P8-13 | UnderwaterLab 主題 | UnderwaterLabThemeBuilder.swift | 水下主題：氣泡、生物發光 | 3h |
| P8-14 | JapaneseGarden 主題 | JapaneseGardenThemeBuilder.swift | 日式庭園：櫻花、石燈 | 3h |
| P8-15 | MinecraftOverworld 主題 | MinecraftOverworldThemeBuilder.swift | Minecraft 主題：方塊地形 | 3h |
| P8-16 | 場景轉換效果 | CommandCenterScene (transition) | 傳送全場景過渡動畫 | 3h |
| P8-17 | 主題整合測試 | - | 所有主題切換、視覺驗證 | 2h |

---

### 階段 P9：3D 渲染引擎 — 特效系統（預估 4 天）

| 工項編號 | 工項名稱 | 原始檔案 | 說明 | 預估工時 |
|---------|---------|---------|------|---------|
| P9-01 | ParticleEffectBuilder | ParticleEffectBuilder.swift | 粒子系統基礎：完成閃光、錯誤煙霧、代碼雨 | 4h |
| P9-02 | 環境粒子系統 | ParticleEffectBuilder (ambient) | 7 種主題粒子：螢火蟲、氣泡、星粒、霓虹雨 | 4h |
| P9-03 | ChatBubbleManager | ChatBubbleManager.swift | 聊天氣泡管理：建立、排隊、自動消失 | 3h |
| P9-04 | ChatBubbleNode | ChatBubbleNode.swift | 聊天氣泡渲染：Canvas 繪製、Billboard、打字指示器 | 4h |
| P9-05 | DayNightCycleController | DayNightCycleController.swift | 日夜循環：5 個時段、光照/色溫漸變 | 3h |
| P9-06 | WeatherEffectBuilder | WeatherEffectBuilder.swift | 天氣系統：陽光/多雲/下雨/暴風 | 4h |
| P9-07 | GitVisualizationBuilder | GitVisualizationBuilder.swift | Git 3D 可視化：Diff 面板、分支樹、提交時間線 | 6h |
| P9-08 | InteractiveObject | InteractiveObjectNode.swift | 可互動物件：門、伺服器、白板 | 2h |
| P9-09 | 選擇高亮效果 | CommandCenterScene (selection) | Torus 環、脈衝、旋轉、發光 | 2h |

---

### 階段 P10：UI 視圖層（預估 8 天）

| 工項編號 | 工項名稱 | 原始檔案 | 說明 | 預估工時 |
|---------|---------|---------|------|---------|
| **核心佈局** ||||
| P10-01 | ContentView | ContentView.swift | 主容器：HSplitView（3D 場景 + 側邊欄） | 3h |
| P10-02 | SceneContainerView | SceneContainerView.swift | 3D 場景容器 + 鍵盤快捷鍵 + 覆蓋層 | 3h |
| P10-03 | SceneSelectionView | SceneSelectionView.swift | 主題選擇頁面：9 個主題預覽卡 | 3h |
| **元件** ||||
| P10-04 | PromptInputBar | PromptInputBar.swift | 提示輸入欄：範本快選、模型選擇、提交 | 3h |
| P10-05 | ModelSelectorButton | ModelSelectorButton.swift | Claude 模型選擇按鈕（Opus/Sonnet/Haiku） | 1h |
| P10-06 | WorkspacePicker | WorkspacePicker.swift | 工作目錄選擇器 | 1.5h |
| P10-07 | StatusIndicator | StatusIndicator.swift | 狀態指示器元件 | 1h |
| P10-08 | TaskProgressBar | TaskProgressBar.swift | 任務進度條 | 1h |
| **側邊欄面板** ||||
| P10-09 | SidePanelView | SidePanelView.swift | 側邊欄容器 + Tab 切換 | 2h |
| P10-10 | AgentDetailView | AgentDetailView.swift | 代理詳情：統計、技能、化妝品 | 3h |
| P10-11 | CLIOutputView | CLIOutputView.swift | CLI 輸出面板：即時流、工具圖標、搜尋 | 4h |
| P10-12 | TaskListView | TaskListView.swift | 任務列表：拖放排序、狀態篩選 | 3h |
| P10-13 | AgentHierarchyView | AgentHierarchyView.swift | 代理層級樹狀視圖 | 2h |
| P10-14 | TaskTeamView | TaskTeamView.swift | 任務團隊視圖 | 2h |
| **覆蓋視圖 (Sheet/Dialog)** ||||
| P10-15 | AchievementGalleryView | AchievementGalleryView.swift | 成就庫：已解鎖/未解鎖、獎勵顯示 | 3h |
| P10-16 | CosmeticShopView | CosmeticShopView.swift | 化妝品商店：分類、購買、裝備 | 4h |
| P10-17 | AgentStatsDashboardView | AgentStatsDashboardView.swift | 統計儀表板：圖表、排行榜、熱圖 | 5h |
| P10-18 | MiniMapOverlay | MiniMapOverlay.swift | 迷你地圖覆蓋：霧隱、探索物品 | 3h |
| P10-19 | TaskQueueOverlay | TaskQueueOverlay.swift | 任務隊列：浮動卡片、優先級 | 2h |
| P10-20 | PerformanceMetricsOverlay | PerformanceMetrics... | 性能指標：令牌、成本、圖表 | 3h |
| P10-21 | StreakOverlay | StreakOverlay.swift | 連勝指示覆蓋 | 1h |
| P10-22 | GitIntegrationView | GitIntegrationView.swift | Git 面板：diff、分支、提交 | 4h |
| P10-23 | PromptTemplateGalleryView | PromptTemplateGallery... | 提示詞範本庫：搜尋、預覽、管理 | 3h |
| P10-24 | ModelComparisonView | ModelComparisonView.swift | 多模型比較視圖 | 2h |
| P10-25 | SessionHistoryView | SessionHistoryView.swift | 會話歷史：列表、重放控制 | 3h |
| P10-26 | SkillBookView | SkillBookView.swift | 技能書：安裝、停用 | 2h |
| P10-27 | HelpOverlayView | HelpOverlayView.swift | F1 幫助面板：快捷鍵列表 | 2h |
| P10-28 | PlanReviewSheet | PlanReviewSheet.swift | 計劃審查對話框 | 2h |
| P10-29 | AskUserQuestionSheet | AskUserQuestionSheet.swift | 用戶問題對話框 | 2h |
| P10-30 | SkillsMPBrowseSheet | SkillsMPBrowseSheet.swift | SkillsMP 瀏覽與導入 | 2h |
| **時間線** ||||
| P10-31 | TimelineView | TimelineView.swift | 事件時間線：Canvas 繪製、篩選 | 3h |
| P10-32 | TimelineFilterBar | TimelineFilterBar.swift | 時間線篩選工具列 | 1h |
| **多窗口 (Desktop)** ||||
| P10-33 | CLIOutputWindow | CLIOutputWindowView.swift | 彈出式 CLI 窗口 | 2h |
| P10-34 | AgentDetailWindow | AgentDetailWindowView.swift | 分離代理詳情窗口 | 2h |
| P10-35 | FloatingMonitorView | FloatingMonitorView.swift | 浮動監視器窗口 | 2h |

---

### 階段 P11：整合與互動（預估 4 天）

| 工項編號 | 工項名稱 | 說明 | 預估工時 |
|---------|---------|------|---------|
| P11-01 | 3D ↔ UI 狀態同步 | 代理選擇 → 側邊欄更新、任務狀態 → 3D 動畫 | 4h |
| P11-02 | CLI 輸出 → 3D 動畫驅動 | CLI 事件解析 → 代理狀態更新 → 動畫觸發 | 4h |
| P11-03 | 拖放系統 | 任務從列表拖到 3D 場景中的代理 | 3h |
| P11-04 | 鍵盤快捷鍵 | F1 幫助、Escape 退出、其他快捷鍵 | 2h |
| P11-05 | 工具列整合 | 所有工具列按鈕與對應功能連接 | 2h |
| P11-06 | 成就觸發整合 | 任務完成 → 成就檢查 → 彈出通知 | 2h |
| P11-07 | 遊戲化流程 | 任務完成 → XP/幣 → 升級 → 連勝 → 天氣變化 | 3h |
| P11-08 | 聊天氣泡整合 | CLI 助手文字 → 3D 聊天氣泡顯示 | 2h |
| P11-09 | Git 3D 可視化整合 | Git 狀態更新 → 3D Diff 面板/分支樹更新 | 3h |
| P11-10 | 通知整合 | 事件觸發 → 本地通知發送 | 1h |

---

### 階段 P12：測試與打磨（預估 4 天）

| 工項編號 | 工項名稱 | 說明 | 預估工時 |
|---------|---------|------|---------|
| P12-01 | Widget 測試 | 核心 Widget 的單元測試 | 4h |
| P12-02 | 整合測試 | 端對端流程測試（提交任務→完成→獎勵） | 4h |
| P12-03 | 效能最佳化 | 3D 渲染效能調優、Widget 重建最佳化 | 4h |
| P12-04 | 跨平台驗證 | macOS / Windows / Linux / iOS / Android 測試 | 6h |
| P12-05 | UI/UX 打磨 | 動畫流暢度、視覺一致性、邊界案例 | 4h |
| P12-06 | 記憶體洩漏檢測 | 3D 場景切換、長時間運行的記憶體檢查 | 3h |
| P12-07 | 無障礙性 | 螢幕閱讀器支援、鍵盤導航 | 3h |
| P12-08 | 文件與 README | 使用說明、開發文件、部署指南 | 2h |

---

## 四、風險評估與替代方案

### 4.1 高風險項目

| 風險 | 描述 | 影響 | 緩解方案 |
|------|------|------|---------|
| **3D 效能** | Fluorite 基於 Filament + Vulkan，效能應優於其他 Flutter 3D 方案，但體素數量較大時仍需驗證 | 中 | (1) 使用 LOD（細節層級）降低遠距體素數量 (2) 利用 Fluorite ECS 的 data-oriented 架構最佳化批次渲染 (3) 備選：Flame 2.5D 方案 |
| **程式化音樂** | Dart 生態缺少等級的音頻合成 API | 中 | 預錄音頻檔案替代即時合成 |
| **CLI 進程管理** | Web 平台無法使用 `dart:io Process` | 高 | Web 版本需搭配後端 WebSocket 代理 |
| **多窗口** | `desktop_multi_window` 套件穩定性 | 中 | 備選：使用 Tab 介面替代多窗口 |
| **3D 文字渲染** | 3D 場景中的文字（名字標籤、聊天氣泡）難以跨平台 | 中 | 使用 Fluorite 的 Multi-View 功能，Flutter UI 層疊加文字；或使用 Canvas 繪製紋理貼圖到 3D 平面 |

### 4.2 平台特定限制

| 平台 | 限制 | 解決方案 |
|------|------|---------|
| **Web** | 無 `dart:io`、無本地進程 | 需 WebSocket 代理伺服器 |
| **iOS** | 無 CLI 進程執行 | 需遠端連線到 macOS/Linux 主機 |
| **Android** | 無 CLI 進程執行 | 同上 |
| **Windows** | Claude CLI 可能路徑不同 | 使用 `where` 命令尋找 |
| **Linux** | 通知 API 差異 | 使用 `libnotify` 整合 |

### 4.3 備選 3D 方案：2.5D 等距視角

如果 Fluorite 在特定平台效能不足，可考慮使用 **Flame Engine** 建立 2.5D 等距視角：

**優點：**
- Flutter 原生、效能極好
- 跨平台穩定
- 精靈圖動畫成熟

**缺點：**
- 失去真 3D 旋轉相機
- 視覺效果與原版差異大

**實作方式：**
- 等距投影的 2D Sprite 角色
- 圖層式場景堆疊
- 預渲染的等距主題背景

---

## 五、工時總覽

| 階段 | 名稱 | 工時（人時） | 預估天數 |
|------|------|-----------|---------|
| P0 | 專案基礎建設 | 18h | 3 天 |
| P1 | 資料模型層 | 21.5h | 3 天 |
| P2 | 服務層 — 核心業務邏輯 | 39h | 5 天 |
| P3 | 服務層 — 音訊與通知 | 14h | 2 天 |
| P4 | 狀態管理層 | 20.5h | 3 天 |
| P5 | 3D 引擎 — 基礎設施 | 26h | 5 天 |
| P6 | 3D 引擎 — 體素角色 | 32h | 5 天 |
| P7 | 3D 引擎 — 動畫系統 | 28h | 4 天 |
| P8 | 3D 引擎 — 環境與主題 | 44h | 6 天 |
| P9 | 3D 引擎 — 特效系統 | 32h | 4 天 |
| P10 | UI 視圖層 | 84h | 8 天 |
| P11 | 整合與互動 | 26h | 4 天 |
| P12 | 測試與打磨 | 30h | 4 天 |
| **合計** | | **~415h** | **~57 天** |

> 以單人全職開發計算，約需 **2.5-3 個月**。
> 若 2 人團隊平行開發（前端 + 3D），約需 **1.5-2 個月**。

---

## 六、建議開發順序與里程碑

### 里程碑 M1：可運行骨架（2 週）
- P0（基礎建設）+ P1（資料模型）+ P4（狀態管理）
- 目標：App 可啟動、主題選擇頁面、基礎導航

### 里程碑 M2：3D 場景可見（3 週）
- P5（3D 基礎）+ P6（體素角色）+ P8-07（Command Center 主題）
- 目標：一個主題內可顯示體素角色、相機可操作

### 里程碑 M3：核心互動完成（2 週）
- P2-01（CLI 整合）+ P7（動畫系統）+ P10-01~08（核心 UI）
- 目標：可提交任務、角色播放動畫、CLI 輸出可見

### 里程碑 M4：功能完整（3 週）
- P2（剩餘服務）+ P3（音訊）+ P8（剩餘主題）+ P9（特效）
- 目標：所有 9 個主題、粒子特效、音訊、Git 整合

### 里程碑 M5：UI 完整（2 週）
- P10（剩餘 UI）+ P11（整合）
- 目標：所有覆蓋層、側邊欄、多窗口

### 里程碑 M6：發佈準備（1 週）
- P12（測試與打磨）
- 目標：跨平台驗證、效能最佳化、Bug 修復

---

## 七、關鍵技術決策建議

### 7.1 必須優先驗證（PoC）

在正式開發前，建議先用 1-2 天做以下原型驗證：

1. **Fluorite + Flutter 整合** — 驗證 `FluoriteView` Widget 能否嵌入 3D 場景並達到 60+ FPS（Fluorite 基於 Filament + Vulkan，預期效能優於 three_dart）
2. **體素角色渲染** — 驗證 Fluorite ECS 架構下 100+ 個體素 Entity 組合的效能
3. **CLI Process 串流** — 驗證 Dart `Process.start()` 能否正確串流 Claude CLI 的 JSON 輸出
4. **多窗口** — 驗證 `desktop_multi_window` 在目標平台的穩定性

### 7.2 架構建議

1. **Clean Architecture 分層：**
   ```
   Presentation (Views/Widgets)
       ↓
   Application (Providers/Blocs)
       ↓
   Domain (Models/Interfaces)
       ↓
   Infrastructure (Services/Repositories)
   ```

2. **3D 引擎隔離：** 將 Fluorite 3D 引擎包裝在獨立的 Flutter Package 中，方便未來替換

3. **平台差異抽象：** 使用 `abstract class` + 條件匯入處理 Desktop vs Mobile vs Web 差異

4. **測試策略：**
   - Model 層：100% 單元測試
   - Service 層：核心邏輯單元測試 + Mock
   - View 層：Widget 測試 + Golden 測試
   - 3D 層：手動視覺驗證 + FPS 基準測試

---

## 八、附錄：原始 Swift ↔ Flutter 對照表

| SwiftUI 概念 | Flutter 對應 |
|-------------|-------------|
| `@StateObject` | `StateNotifierProvider` (Riverpod) |
| `@Published` | `state = state.copyWith(...)` |
| `@EnvironmentObject` | `ref.watch(provider)` |
| `@Binding` | `ValueNotifier` / Callback |
| `.sheet()` | `showModalBottomSheet()` / `showDialog()` |
| `.onAppear` | `initState()` / `ref.listen()` |
| `HSplitView` | `Row` + `Expanded` + `VerticalDivider` |
| `NavigationSplitView` | `Scaffold` + `Drawer` / custom split |
| `SCNView` | `FluoriteView` Widget (Fluorite) |
| `SCNAction` | Fluorite ECS System + `AnimationController` |
| `SCNTransaction` | Fluorite ECS frame update |
| `SCNNode` | Fluorite Entity (ECS) |
| `SCNGeometry` | Fluorite Renderable Component + Filament Geometry |
| `SCNMaterial` | Filament PBR Material / Custom Shader |
| `SCNLight` | Filament Light Entity (Point/Spot/Ambient/Directional) |
| `SCNCamera` | Fluorite Camera Entity + Filament Camera |
| `UserDefaults` | `SharedPreferences` / `Hive` |
| `Process` | `dart:io Process` |
| `AVAudioEngine` | `just_audio` / `audioplayers` |
| `UNUserNotification` | `flutter_local_notifications` |

---

> 本文件基於對原始 macOS SwiftUI + SceneKit 專案（13,351 行 Swift 代碼、151 個檔案）的完整分析而撰寫。
