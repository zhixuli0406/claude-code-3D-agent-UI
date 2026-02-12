# F1 功能實現計劃

## 概述

實現兩個 F1 功能：
1. **F1. Background Music（背景音樂）** — 主題專屬環境音樂、動態音樂強度、音量控制
2. **F1 鍵盤快捷鍵（幫助面板）** — 按下 F1 鍵顯示快捷鍵指南 overlay

---

## 第一部分：F1. Background Music（背景音樂系統）

### 1. 建立 `BackgroundMusicManager.swift`（新文件）
**路徑:** `AgentCommand/AgentCommand/Services/BackgroundMusicManager.swift`

- 使用 `AVAudioPlayer` 播放系統合成的環境音樂（使用 `AVAudioEngine` + `AVAudioUnitSampler` 程式化生成音調）
- 每個主題對應一個獨特的音頻配置（頻率、節奏、音色）
- 支援動態強度切換（idle vs active 工作狀態）
- 音量控制 + 淡入淡出效果
- 遵循 SoundManager 的 isMuted 狀態

**主要 API：**
```swift
class BackgroundMusicManager: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var musicVolume: Float = 0.3
    @Published var intensity: MusicIntensity  // .calm, .active

    func playThemeMusic(_ theme: SceneTheme)
    func stopMusic()
    func setIntensity(_ intensity: MusicIntensity)
    func fadeOut(duration: TimeInterval)
    func fadeIn(duration: TimeInterval)
}
```

**主題音樂配置（使用程式化音頻，不需外部檔案）：**
| 主題 | 風格 | 基礎頻率 | 節奏 |
|------|------|---------|------|
| Command Center | tech/electronic 低頻嗡鳴 | 110Hz | 慢 |
| Floating Islands | 空靈和弦 | 261Hz (C4) | 中等 |
| Dungeon | 陰暗低沉 | 82Hz | 慢 |
| Space Station | sci-fi 合成波 | 146Hz | 中慢 |
| Cyberpunk City | 電子脈衝 | 130Hz | 快 |
| Medieval Castle | 莊嚴管弦 | 196Hz | 中等 |
| Underwater Lab | 水下迴音 | 174Hz | 慢 |
| Japanese Garden | 寧靜五聲音階 | 293Hz (D4) | 慢 |
| Minecraft Overworld | 像素風 8-bit | 220Hz (A3) | 中等 |

### 2. 修改 `AppState.swift`
- 新增 `let backgroundMusicManager = BackgroundMusicManager()`
- 在主題切換時呼叫 `backgroundMusicManager.playThemeMusic(theme)`
- 在 agent 工作狀態變化時更新強度

### 3. 修改 `ContentView.swift`
- 新增背景音樂工具列按鈕（音樂開關 + 音量滑桿）

### 4. 修改 `L10n.swift`
- 新增背景音樂相關本地化鍵

---

## 第二部分：F1 鍵盤快捷鍵（幫助面板）

### 5. 建立 `HelpOverlayView.swift`（新文件）
**路徑:** `AgentCommand/AgentCommand/Views/Overlays/HelpOverlayView.swift`

- 顯示所有可用功能與操作的快速參考指南
- 使用 `.sheet()` 模式（與 AchievementGalleryView 一致）
- 暗色主題背景，符合現有 UI 風格
- 分類展示：互動操作、攝影機、快捷鍵、工具列功能

### 6. 修改 `AppState.swift`
- 新增 `@Published var isHelpOverlayVisible: Bool = false`
- 新增 `func toggleHelpOverlay()`

### 7. 修改 `SceneContainerView.swift`
- 新增 `.onKeyPress` 處理 F1 鍵觸發幫助面板

### 8. 修改 `ContentView.swift`
- 新增 `.sheet(isPresented: $appState.isHelpOverlayVisible)`
- 新增幫助按鈕到工具列

### 9. 修改 `L10n.swift`
- 新增幫助面板相關本地化鍵

---

## 第三部分：文件更新

### 10. 更新 `TODO-features.md`
- F1. Background Music 項目標記為 `[x]`

### 11. 更新 `README.md` 和 `README.zh-TW.md`
- 新增背景音樂功能描述
- 新增 F1 幫助快捷鍵描述
- 新增鍵盤快捷鍵段落

---

## 需修改的文件清單

| 文件 | 操作 | 說明 |
|------|------|------|
| `Services/BackgroundMusicManager.swift` | 新建 | 背景音樂管理器 |
| `Views/Overlays/HelpOverlayView.swift` | 新建 | F1 幫助面板 |
| `App/AppState.swift` | 修改 | 新增 manager、狀態和切換方法 |
| `Views/ContentView.swift` | 修改 | 新增工具列按鈕和 sheet |
| `Views/SceneContainerView.swift` | 修改 | 新增 F1 鍵盤快捷鍵 |
| `Services/L10n.swift` | 修改 | 新增本地化字串 |
| `TODO-features.md` | 修改 | 標記已完成 |
| `README.md` | 修改 | 新增功能說明 |
| `README.zh-TW.md` | 修改 | 新增功能說明 |
