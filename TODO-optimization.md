# AgentCommand 優化項目清單

> Last updated: 2026-02-14
> Scope: **僅限優化現有功能**，不新增任何功能
> 專案規模: 316 Swift 檔案 / ~88,000 行程式碼 | 零外部依賴 | macOS 14+

---

## P0 — 安全性修復（必須立即處理）

### 安全漏洞

- [ ] **移除 `--dangerously-skip-permissions` 硬編碼**
  - 📍 `Services/CLIProcessManager.swift:63`
  - 問題: CLI 進程啟動時硬編碼繞過所有權限檢查，使 `DangerousCommandClassifier` 形同虛設
  - 影響: 任何 LLM 生成的危險命令（`rm -rf`、`DROP TABLE`）均可無阻攔執行
  - 修復: 改為可配置選項，預設關閉
  - 複雜度: ⭐ 低

- [ ] **修復 SQL 注入漏洞（字串插值查詢）**
  - 📍 `Services/RAGDatabaseManager.swift:175-176`
  - 📍 `Services/AgentMemoryDatabaseManager.swift:152-153`
  - 問題: 使用字串插值構造 SQL（`"DELETE FROM documents WHERE id = '\(id)'"`）
  - 影響: 若 ID 值含惡意內容可破壞或洩露資料庫
  - 修復: 改用 `sqlite3_bind_text` 參數化查詢
  - 複雜度: ⭐ 低

- [ ] **API Key 明文存儲改善**
  - 📍 `App/AppState.swift` — `@AppStorage("openai_api_key")`
  - 問題: API Key 存放於 UserDefaults（明文 plist），任何同機程式可讀取
  - 修復: 遷移至 macOS Keychain（`Security.framework`）
  - 複雜度: ⭐⭐ 中

---

## P1 — 性能瓶頸修復（高影響）

### 記憶體與渲染

- [ ] **拆分 AppState 巨型物件**
  - 📍 `App/AppState.swift`（2,582 行）
  - 問題: 單一 `@Observable` 物件包含所有應用狀態，任一屬性變更觸發全域 UI 重繪
  - 修復: 拆分為多個領域物件（`SessionState`、`UIState`、`AgentState`、`SettingsState`）
  - 預期收益: 大幅減少不必要的 SwiftUI 重繪，改善 UI 流暢度
  - 複雜度: ⭐⭐⭐ 高

- [ ] **ContentView `.sheet` 綁定爆炸優化**
  - 📍 `Views/ContentView.swift`（770 行）
  - 問題: 單一 View 管理過多 `.sheet` / `.overlay` 綁定，增加編譯時間和渲染負擔
  - 修復: 提取子視圖，使用路由器模式管理面板切換
  - 複雜度: ⭐⭐ 中

- [ ] **SceneKit 渲染效能優化**
  - 📍 `Views/Scene3DView.swift` 及相關場景檔案
  - 問題: 3D 場景在多 Agent 時幀率下降
  - 修復: 實施 LOD（Level of Detail）策略、減少遠距物件的多邊形數量、使用幾何體實例化
  - 複雜度: ⭐⭐ 中

### 資料庫效能

- [ ] **SQLite 缺少索引**
  - 📍 `Services/RAGDatabaseManager.swift`
  - 📍 `Services/AgentMemoryDatabaseManager.swift`
  - 問題: 查詢未建立索引，隨資料增長效能線性下降
  - 修復: 為常用查詢欄位（`document_id`、`memory_id`、`agent_id`、`timestamp`）添加 `CREATE INDEX`
  - 預期收益: 查詢效能提升 10-100x
  - 複雜度: ⭐ 低

- [ ] **啟用 SQLite WAL 模式**
  - 📍 `Services/RAGDatabaseManager.swift`
  - 📍 `Services/AgentMemoryDatabaseManager.swift`
  - 問題: 預設 journal 模式下讀寫互斥
  - 修復: 啟動時執行 `PRAGMA journal_mode=WAL;`
  - 預期收益: 並行讀寫效能提升，減少鎖等待
  - 複雜度: ⭐ 低

- [ ] **N+1 查詢問題修復**
  - 📍 `Services/RAGDatabaseManager.swift` — 迴圈內逐筆查詢關聯資料
  - 問題: 列表頁面逐筆查詢造成大量 DB 來回
  - 修復: 改用 `JOIN` 或批次查詢
  - 複雜度: ⭐⭐ 中

### API 調用優化

- [ ] **快取 `fetchAllDocuments` 結果**
  - 📍 `Services/RAGDatabaseManager.swift`
  - 問題: 每次呼叫都重新查詢完整文件列表
  - 修復: 加入記憶體快取層，設定 TTL 或事件驅動失效
  - 預期收益: 減少 80%+ 的重複資料庫查詢
  - 複雜度: ⭐ 低

- [ ] **批量 `touchMemory` 操作**
  - 📍 `Services/AgentMemoryDatabaseManager.swift`
  - 問題: 更新記憶存取時間逐筆執行 UPDATE
  - 修復: 合併為單次批量 UPDATE 語句
  - 複雜度: ⭐ 低

- [ ] **向量快取設定上限**
  - 📍 `Services/RAGDatabaseManager.swift`
  - 問題: 向量嵌入快取無上限，記憶體可能無限增長
  - 修復: 實施 LRU 淘汰策略，設定最大快取條目數
  - 複雜度: ⭐ 低

- [ ] **RAG 索引改為並行處理**
  - 📍 `Services/RAGDatabaseManager.swift`
  - 問題: 大量檔案索引時串行處理，速度慢
  - 修復: 使用 `TaskGroup` 並行索引，設定合理的並行數上限
  - 複雜度: ⭐⭐ 中

---

## P2 — 代碼品質改善（中影響）

### 代碼重複消除

- [ ] **提取百分比計算為 `Double` extension**
  - 📍 `Models/APIUsageAnalyticsModels.swift`、`AnalyticsDashboardModels.swift`、`PromptOptimizationModels.swift`、`ReportExportModels.swift`、`SessionHistoryAnalyticsModels.swift`、`TeamPerformanceModels.swift`
  - 問題: `var xxxPercentage: Int { Int(value * 100) }` 跨 7 個 Model 重複 19+ 次
  - 修復: 建立 `Double` extension `var asPercentage: Int`
  - 複雜度: ⭐ 低

- [ ] **提取 `formattedCost` 為 Protocol extension**
  - 📍 同上 Model 系列（8 處定義）
  - 問題: 完全相同的 `formattedCost` 計算屬性在 7+ 個 Model 中獨立定義
  - 修復: 定義 `CostFormattable` protocol 並提供 default implementation
  - 複雜度: ⭐ 低

- [ ] **建立 `PanelOverlayContainer` 基礎組件**
  - 📍 `Views/Overlays/*.swift`（70 個檔案）
  - 問題: 所有 Overlay View 共享相同的 header / background / shadow / dismiss 結構
  - 修復: 建立統一的容器組件，各面板只需提供內容
  - 預期收益: 減少數千行樣板代碼，統一外觀
  - 複雜度: ⭐⭐ 中

### 架構改善

- [ ] **Service 層統一錯誤處理**
  - 📍 `Services/*.swift`
  - 問題: 各 Service 各自處理錯誤，格式和行為不一致
  - 修復: 定義統一的 `ServiceError` 列舉和錯誤處理管道
  - 複雜度: ⭐⭐ 中

- [ ] **減少計算屬性重複執行**
  - 📍 `App/AppState.swift` 及 Model 檔案
  - 問題: 多個昂貴的計算屬性在 SwiftUI 重繪時反覆執行
  - 修復: 對昂貴計算使用快取或明確的更新觸發機制
  - 複雜度: ⭐⭐ 中

---

## P3 — 工程實踐改善（低影響 / 長期收益）

### 建構與工具鏈

- [ ] **升級 swift-tools-version 至 6.0**
  - 📍 `Package.swift`（目前 5.9）
  - 問題: Swift 6 的嚴格並行性檢查（Strict Concurrency）可提前發現數據競爭
  - 修復: 更新版本號，逐步修復 Sendable 警告
  - 複雜度: ⭐⭐⭐ 高（可能觸發大量並行警告）

- [ ] **建立 CI/CD Pipeline**
  - 📍 缺少 `.github/workflows/` 目錄
  - 問題: 無自動化建構/測試流程，代碼品質無門禁
  - 修復: 建立 GitHub Actions workflow（build + test + lint）
  - 複雜度: ⭐⭐ 中

- [ ] **整合 SwiftLint**
  - 📍 專案根目錄（缺少 `.swiftlint.yml`）
  - 問題: 無統一代碼風格檢查
  - 修復: 加入 SwiftLint 設定並整合至建構流程
  - 複雜度: ⭐ 低

### 測試覆蓋

- [ ] **提升核心 Service 單元測試覆蓋率**
  - 📍 `Tests/` 目錄
  - 問題: 關鍵業務邏輯（CLIProcessManager、RAGDatabaseManager）缺乏充分測試
  - 修復: 為核心 Service 補充單元測試，目標 > 70% 覆蓋率
  - 複雜度: ⭐⭐⭐ 高

- [ ] **加入 SQL 注入防護測試**
  - 📍 `Tests/`
  - 問題: 即使修復了 SQL 注入，無測試保障日後不會回退
  - 修復: 加入包含特殊字元的測試案例（`'; DROP TABLE --`）
  - 複雜度: ⭐ 低

### 文件與可維護性

- [ ] **大型檔案拆分計畫**
  - 📍 `App/AppState.swift`（2,582 行）
  - 📍 `Views/ContentView.swift`（770 行）
  - 📍 `Services/RAGDatabaseManager.swift`（646 行）
  - 問題: 單一檔案過大，難以維護和 code review
  - 修復: 按職責拆分為多個檔案，使用 `extension` 分組
  - 複雜度: ⭐⭐ 中

- [ ] **補充關鍵路徑的內聯文件**
  - 📍 `Services/CLIProcessManager.swift`（CLI 進程生命週期）
  - 📍 `Services/RAGDatabaseManager.swift`（索引與查詢流程）
  - 問題: 複雜邏輯缺少說明，新人上手困難
  - 修復: 為核心方法添加 `///` 文件註釋
  - 複雜度: ⭐ 低

---

## 快速勝利清單（Quick Wins）

以下項目 **實施難度低、收益高**，建議優先處理：

| # | 項目 | 預估時間 | 影響 |
|---|------|---------|------|
| 1 | 移除 `--dangerously-skip-permissions` 硬編碼 | 15 分鐘 | 🔴 安全 |
| 2 | SQL 參數化查詢修復（4 處） | 30 分鐘 | 🔴 安全 |
| 3 | SQLite 添加索引 | 20 分鐘 | 🟡 性能 |
| 4 | 啟用 WAL 模式 | 5 分鐘 | 🟡 性能 |
| 5 | 快取 `fetchAllDocuments` | 30 分鐘 | 🟡 性能 |
| 6 | 批量 `touchMemory` | 20 分鐘 | 🟡 性能 |
| 7 | 向量快取 LRU 上限 | 30 分鐘 | 🟡 性能 |
| 8 | 提取百分比計算 extension | 20 分鐘 | 🟢 品質 |
| 9 | 提取 `formattedCost` protocol | 20 分鐘 | 🟢 品質 |
| 10 | 整合 SwiftLint | 30 分鐘 | 🟢 品質 |

---

## 統計摘要

| 優先級 | 數量 | 狀態 |
|--------|------|------|
| P0 安全性修復 | 3 項 | ⬜ 未開始 |
| P1 性能瓶頸 | 8 項 | ⬜ 未開始 |
| P2 代碼品質 | 5 項 | ⬜ 未開始 |
| P3 工程實踐 | 7 項 | ⬜ 未開始 |
| **合計** | **23 項** | **⬜ 0% 完成** |
