[English](./README.md) | [繁體中文](./README.zh-TW.md)

# Claude Code 3D Agent UI

一款 macOS 應用程式，將 Claude Code CLI 的代理執行過程轉化為沉浸式的 3D 視覺化環境，結合遊戲化設計、豐富動畫和生產力工具。

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Framework](https://img.shields.io/badge/framework-SwiftUI%20%2B%20SceneKit-green)

---

## 功能特色

### 3D 場景主題

9 款精心設計的互動環境：

| 主題 | 說明 |
|------|------|
| 指揮中心 | 配備全息顯示器的高科技控制室 |
| 浮空島嶼 | 有橋樑相連的空中仙境島嶼 |
| 地下城 | 幽暗神秘的地下密室 |
| 太空站 | 零重力科幻太空站 |
| 賽博龐克城市 | 霓虹燈照耀的街道與全息廣告牌 |
| 中世紀城堡 | 騎士風格代理人的王座大廳 |
| 水下實驗室 | 充滿氣泡和魚群的潛水基地 |
| 日式庭園 | 櫻花飄落的禪意花園 |
| Minecraft 世界 | 經典像素風格地形 |

### 像素角色系統

- 全關節像素代理人，可自訂身體部件
- 超過 15 種裝飾帽子與配件（皇冠、光環、披風、耳機）
- 每個代理人可設定粒子拖尾特效
- 自訂名牌與稱號

### 互動功能

- **點擊互動** — 選取代理人、雙擊追蹤、右鍵選單
- **拖放操作** — 將任務拖曳到代理人上進行指派
- **對話氣泡** — 即時語音／思考氣泡搭配打字動畫
- **攝影機控制** — 自由環繞、聚焦代理人、電影預設、子母畫面、第一人稱視角
- **互動時間軸** — 可捲動的事件歷史，支援篩選與匯出

### 遊戲化系統

- **經驗值與等級** — 代理人累積經驗、升級並解鎖裝飾品
- **成就系統** — 超過 10 種可解鎖成就（初次擊殺、極速惡魔、除蟲大師、夜貓子等）
- **數據儀表板** — 任務完成率、排行榜、歷史圖表、熱力圖
- **裝飾商店** — 使用獲得的金幣購買外觀、帽子、粒子特效
- **連擊系統** — 連續追蹤與倍率加成
- **小地圖** — 戰爭迷霧探索，隱藏彩蛋與劇情物品

### 動畫與特效

- 16 種動畫類型（勝利舞蹈、沮喪、協作、睡眠、傳送、走向桌面等）
- 粒子特效（火花、煙霧、程式碼雨、閃電、環境主題粒子）
- 日夜循環同步真實世界時間
- 天氣效果隨任務成功率變化
- 互動場景物件（可點擊的螢幕、可開啟的門）
- 流暢的主題切換搭配傳送門／扭曲特效

### 生產力與監控

- **任務佇列** — 視覺化浮動卡片，依優先級標色，支援拖曳排序
- **多視窗** — 彈出式 CLI 輸出、可分離面板、浮動監控器、多螢幕支援
- **通知** — macOS 原生通知搭配可自訂音效
- **效能指標** — 即時 Token 使用量、費用估算、任務持續時間追蹤
- **音效** — 完成提示音、錯誤警告、鍵盤聲、升級慶祝音效
- **背景音樂** — 主題專屬程序化環境音樂，動態強度隨工作活動變化

### Git 整合視覺化

- **3D 差異面板** — 在 3D 空間中以浮動程式碼區塊顯示已暫存/未暫存變更，增刪行以顏色區分
- **分支樹狀結構** — 互動式分支視覺化，旋轉樹狀結構搭配當前分支高亮
- **提交歷史時間軸** — 3D 提交歷史搭配代理頭像關聯與提交詳情
- **PR 工作流程** — 建立 Pull Request 搭配 3D 場景中的視覺預覽卡片（需安裝 `gh` CLI）

### 多模型支援

- **模型選擇** — 為每個代理團隊選擇 Claude Opus、Sonnet 或 Haiku 模型
- **視覺指示器** — 3D 角色與代理詳情面板上的顏色編碼模型標章
- **模型比較** — 並排比較不同模型的輸出結果，支援平行執行

### 提示詞模板

- **模板庫** — 瀏覽、搜尋及管理提示詞模板，支援分類篩選
- **內建模板** — 10 個預建模板，涵蓋錯誤修復、功能開發、程式重構與程式碼審查
- **自訂模板** — 建立、編輯及刪除您自己的可重用提示詞模板
- **快速啟動選單** — 直接從提示詞輸入列快速選取模板，附帶最近使用記錄
- **變數替換** — 動態 `{{variable}}` 佔位符，搭配即時預覽與預設值

### CLI 整合

- 啟動並管理 Claude Code CLI 程序
- 非阻塞串流讀取搭配即時輸出解析
- 工具呼叫計數與進度估算
- 支援工作階段恢復
- 工作區管理

### 在地化

- 支援英文與繁體中文，可於執行時切換語言

### 鍵盤快捷鍵

- **F1** — 顯示/隱藏快捷鍵指南
- **Escape** — 退出第一人稱視角模式

---

## 系統需求

- macOS 14（Sonoma）或更新版本
- 已安裝 [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 並加入 `PATH`
- Swift 5.9+

## 安裝與建置腳本

### 快速安裝（一鍵完成）

`install.sh` 會檢查先決條件、建置 Release 執行檔、打包為 `.app` 套件，並複製到 `/Applications`：

```bash
cd AgentCommand
./install.sh
```

腳本會自動執行以下檢查：
1. 確認 Swift 工具鏈可用
2. 確認 macOS 版本為 14（Sonoma）或更新
3. 解析 Swift Package 相依套件
4. 建置 Release 執行檔
5. 打包 `.app` 套件，包含 `Info.plist` 與資源
6. 安裝至 `/Applications/AgentCommand.app`

安裝完成後，啟動應用程式：

```bash
open /Applications/AgentCommand.app
```

### 僅建置（不安裝）

`build-app.sh` 建置專案並在 `dist/` 目錄下產生 `.app` 套件，不會安裝：

```bash
cd AgentCommand

# Release 建置（預設）
./build-app.sh

# Debug 建置
./build-app.sh debug
```

輸出的 `.app` 套件位於 `AgentCommand/dist/AgentCommand.app`。啟動方式：

```bash
open dist/AgentCommand.app
```

### 使用 Swift CLI 手動建置

若您偏好不使用腳本手動建置：

```bash
cd AgentCommand
swift package resolve   # 解析相依套件
swift build             # Debug 建置
swift build -c release  # Release 建置
```

直接執行：

```bash
swift run AgentCommand
```

### 使用 Xcode 開啟

在 Xcode 中開啟 `AgentCommand/Package.swift` 即可建置與執行。

## 專案結構

```
AgentCommand/
├── App/                  # 應用程式入口與全域狀態
├── Models/               # 資料模型（Agent、Achievement、Cosmetic、Skill 等）
├── Services/             # 業務邏輯（CLI 程序、成就、統計、技能等）
├── Views/
│   ├── Components/       # 可重用 UI 元件
│   ├── Overlays/         # 成就展示、裝飾商店、小地圖、指標等
│   ├── Panels/           # 代理人詳情、CLI 輸出、任務列表面板
│   ├── Windows/          # 多視窗管理
│   └── Timeline/         # 時間軸視圖
├── Scene3D/
│   ├── Themes/           # 9 種主題建構器
│   ├── Voxel/            # 像素角色系統（身體、帽子、粒子、名牌）
│   ├── Animation/        # 16 種動畫控制器
│   └── Effects/          # 粒子、對話氣泡、天氣、日夜循環
├── Utilities/            # 輔助工具函式
└── Resources/            # 素材與範例配置
```

## 開發路線圖

完整功能待辦清單請參閱 [TODO-features.md](./TODO-features.md)。即將推出的項目包括：

- 觀戰模式與即時分享
- 模板分享與社群預設

## 授權條款

保留所有權利。
