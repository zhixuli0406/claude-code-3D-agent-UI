# AgentCommand 優化執行清單

> **專案**: AgentCommand (claude-code-3D-agent-UI)
> **更新日期**: 2026-02-14
> **專案規模**: 316 Swift 檔案 / ~88,000 行程式碼 | 零外部依賴 | macOS 14+
> **資料來源**: 安全審計報告、性能瓶頸分析、代碼品質掃描
> **範圍**: 僅限優化現有功能，不新增任何功能

---

## 優化摘要

本清單整合了 **37 項優化建議**，涵蓋安全、性能、代碼品質、依賴管理與架構五大類別。
所有項目按優先級（P0→P3）和複雜度（低/中/高）分類，並附具體檔案位置和改進方案。

| 類別 | 項目數 | P0 | P1 | P2 | P3 |
|------|--------|----|----|----|----|
| 安全 (Security) | 21 | 4 | 3 | 8 | 6 |
| 性能 (Performance) | 5 | 0 | 1 | 3 | 1 |
| 代碼品質 (Code Quality) | 4 | 0 | 1 | 2 | 1 |
| 依賴管理 (Dependencies) | 3 | 0 | 1 | 1 | 1 |
| 架構改善 (Architecture) | 4 | 0 | 1 | 2 | 1 |
| **合計** | **37** | **4** | **7** | **16** | **10** |

**總估算工時**: 140–277 小時

### 優先級定義

| 級別 | 意義 | 時限 |
|------|------|------|
| **P0** | 嚴重安全漏洞，可被直接利用 | 72 小時內修復 |
| **P1** | 高影響問題，顯著影響安全或性能 | 7 天內修復 |
| **P2** | 中影響問題，改善品質與防禦深度 | 30 天內修復 |
| **P3** | 低影響改善，長期技術健康 | 下個週期處理 |

### 複雜度定義

| 複雜度 | 預估工時 | 符號 |
|--------|---------|------|
| 低 | 1–4h | ⭐ |
| 中 | 4–8h | ⭐⭐ |
| 高 | 8–16h | ⭐⭐⭐ |

---

## Quick Wins — 快速勝利清單

以下項目 **實施難度低、收益高**，建議優先處理：

| # | 項目 | 預估時間 | 類別 |
|---|------|---------|------|
| 1 | 移除 `--dangerously-skip-permissions` 硬編碼 | 15 分鐘 | 🔴 安全 |
| 2 | SQL 參數化查詢修復（2 處） | 30 分鐘 | 🔴 安全 |
| 3 | SQLite 添加索引 | 20 分鐘 | 🟡 性能 |
| 4 | 啟用 SQLite WAL 模式 | 5 分鐘 | 🟡 性能 |
| 5 | 快取 `fetchAllDocuments` 結果 | 30 分鐘 | 🟡 性能 |
| 6 | 批量 `touchMemory` 操作 | 20 分鐘 | 🟡 性能 |
| 7 | 向量快取 LRU 上限 | 30 分鐘 | 🟡 性能 |
| 8 | 提取百分比計算 `Double` extension | 20 分鐘 | 🟢 品質 |
| 9 | 提取 `formattedCost` protocol extension | 20 分鐘 | 🟢 品質 |
| 10 | 統一 API 請求逾時策略 | 15 分鐘 | 🟢 品質 |

---

## 1. 安全 (Security)

### 1.1 注入漏洞修復

- [ ] **[P0] INJ-01: RAGDatabaseManager SQL 注入**
  - **檔案**: `AgentCommand/Services/RAGDatabaseManager.swift:175-176`
  - **複雜度**: ⭐ 低 (1–2h) | **CWE**: CWE-89
  - **問題**: `deleteDocument()` 使用字串插值 `'\(id)'` 直接嵌入 SQL DELETE 語句，未使用參數化查詢
  - **修復**: 改用 `sqlite3_prepare_v2` + `sqlite3_bind_text` 參數化查詢
  - **預期收益**: 消除資料庫被完全控制的風險（可刪除所有記錄、跨表查詢、資料外洩）

- [ ] **[P0] INJ-02: AgentMemoryDatabaseManager SQL 注入**
  - **檔案**: `AgentCommand/Services/AgentMemoryDatabaseManager.swift:152-153`
  - **複雜度**: ⭐ 低 (1–2h) | **CWE**: CWE-89
  - **問題**: `deleteMemory()` 同樣存在 SQL 注入漏洞（同檔案其他查詢已正確使用參數化）
  - **修復**: 同 INJ-01，使用參數化查詢
  - **預期收益**: 保護 Agent 記憶資料庫不被注入攻擊清空或外洩

- [ ] **[P2] INJ-04: URL 參數注入**
  - **檔案**: `AgentCommand/Services/SkillsMPService.swift:46-50, 69-73`
  - **複雜度**: ⭐ 低 (1–2h) | **CWE**: CWE-20
  - **問題**: URL 構建使用字串插值，`page`/`limit`/`sortBy` 參數未驗證直接嵌入
  - **修復**: 改用 `URLComponents` + `URLQueryItem` 構建查詢參數，並加入數值範圍驗證
  - **預期收益**: 防止 URL 參數竄改，強化輸入驗證

- [ ] **[P2] INJ-05: 路徑遍歷風險**
  - **檔案**: `AgentCommand/Services/CLIProcessManager.swift:68`
  - **複雜度**: ⭐ 低 (2–4h) | **CWE**: CWE-22
  - **問題**: `workingDirectory` 直接從使用者輸入接受，未經路徑正規化或白名單驗證
  - **修復**: 使用 `URL.standardizedFileURL.path` 正規化，加入路徑白名單檢查
  - **預期收益**: 防止 `../` 目錄遍歷攻擊存取未授權目錄

### 1.2 認證與授權

- [ ] **[P0] AUTH-01: 移除 `--dangerously-skip-permissions` 硬編碼**
  - **檔案**: `AgentCommand/Services/CLIProcessManager.swift:63`
  - **複雜度**: ⭐ 低 (1h) | **CWE**: CWE-862
  - **問題**: CLI 進程啟動時硬編碼此旗標，繞過所有權限檢查，使 `DangerousCommandClassifier` 形同虛設
  - **影響**: 任何 LLM 生成的危險命令（`rm -rf`、`DROP TABLE`）均可無阻攔執行
  - **修復**: 移除此旗標；若業務必須保留，改為可配置選項（預設關閉），加入操作審計日誌
  - **預期收益**: 恢復 Claude CLI 的內建安全機制，阻止危險命令無阻攔執行

- [ ] **[P2] AUTH-02: 加入服務層存取控制**
  - **檔案**: 多個 Manager 服務（RAGSystemManager, AgentMemorySystemManager 等）
  - **複雜度**: ⭐⭐⭐ 高 (8–16h) | **CWE**: CWE-284
  - **問題**: 所有 Manager 公開方法無存取控制，任何持有參考的程式碼均可直接呼叫刪除/修改操作
  - **修復**: 為敏感操作加入使用者確認對話框，實作操作權限等級分類
  - **預期收益**: 防止意外或惡意的破壞性操作

- [ ] **[P3] AUTH-03: 實作會話管理機制**
  - **檔案**: 全域
  - **複雜度**: ⭐⭐⭐ 高 (8–16h)
  - **問題**: 無會話逾時或自動鎖定機制，API 金鑰一旦設定永久有效
  - **修復**: 加入閒置自動清除敏感資料機制，考慮 Touch ID / 密碼鎖
  - **預期收益**: 防止離席時的未授權存取

### 1.3 資料保護

- [ ] **[P0] DATA-01: SkillsMP API 金鑰遷移至 Keychain**
  - **檔案**: `AgentCommand/Services/SkillsMPService.swift:12, 16-26`
  - **複雜度**: ⭐ 低 (2–4h) | **CWE**: CWE-312
  - **問題**: API 金鑰以明文存於 `UserDefaults`（plist 檔案），任何本地程式均可讀取
  - **修復**: 使用 macOS Keychain (`Security` framework) 的 `SecItemAdd`/`SecItemCopyMatching` 替代
  - **預期收益**: 保護 API 憑證免受本地惡意程式讀取，排除 Time Machine 備份洩露風險

- [ ] **[P1] DATA-02: Anthropic API 金鑰遷移至 Keychain**
  - **檔案**: `AgentCommand/Services/IntentClassifier.swift:423`
  - **複雜度**: ⭐ 低 (2–4h) | **CWE**: CWE-312
  - **問題**: `anthropic_api_key` 存於 UserDefaults 作為環境變數的回退方案
  - **修復**: 同 DATA-01，遷移至 Keychain
  - **預期收益**: 統一金鑰儲存策略，消除明文儲存風險

- [ ] **[P1] DATA-03: 資料庫加密**
  - **檔案**: `AgentCommand/Services/RAGDatabaseManager.swift:26`, `AgentCommand/Services/AgentMemoryDatabaseManager.swift:26`
  - **複雜度**: ⭐⭐⭐ 高 (8–16h) | **CWE**: CWE-311
  - **問題**: `knowledge.db` 和 `agent_memory.db` 使用 `sqlite3_open()` 開啟，未加密
  - **修復**: 整合 SQLCipher 提供透明加密，或使用 macOS Data Protection API
  - **預期收益**: 保護靜態資料（知識庫 + Agent 記憶），防止磁碟鑑識和備份外洩
  - **相依**: 需先評估 SQLCipher 依賴引入 (PKG-01)

- [ ] **[P2] DATA-04: HTTP 標頭安全強化**
  - **檔案**: `AgentCommand/Services/SkillsMPService.swift:91`, `AgentCommand/Services/IntentClassifier.swift:388`
  - **複雜度**: ⭐ 低 (2–4h)
  - **問題**: API 金鑰透過 HTTP 標頭傳輸，日誌或代理伺服器可能洩露
  - **修復**: 確保不記錄請求標頭，使用後清除記憶體中的金鑰，啟用 ATS
  - **預期收益**: 減少金鑰在傳輸和記憶體中的暴露面

- [ ] **[P3] DATA-05: 導入結構化日誌系統**
  - **檔案**: 多個服務檔案
  - **複雜度**: ⭐⭐ 中 (4–8h) | **CWE**: CWE-532
  - **問題**: 使用 `print()` 除錯輸出，可能在生產環境洩露敏感資訊
  - **修復**: 改用 `os.Logger` 區分日誌等級，絕不記錄 API 金鑰/token/憑證
  - **預期收益**: 建立安全監控基礎，防止日誌洩露敏感資料

### 1.4 密碼學與傳輸安全

- [ ] **[P2] CRYPTO-01: 實作 SSL Pinning**
  - **檔案**: `AgentCommand/Services/SkillsMPService.swift`, `AgentCommand/Services/IntentClassifier.swift`
  - **複雜度**: ⭐⭐ 中 (4–8h) | **CWE**: CWE-295
  - **問題**: 網路請求使用預設 `URLSession`，未實作憑證固定
  - **修復**: 使用 `URLSessionDelegate` 驗證伺服器憑證，為關鍵端點實作 SSL Pinning
  - **預期收益**: 防止企業 MITM Proxy 等中間人攻擊

- [ ] **[P3] CRYPTO-02: 資料庫完整性驗證**
  - **檔案**: `AgentCommand/Services/RAGDatabaseManager.swift`, `AgentCommand/Services/AgentMemoryDatabaseManager.swift`
  - **複雜度**: ⭐⭐ 中 (4–8h) | **CWE**: CWE-354
  - **問題**: 資料庫檔案無完整性檢查，外部修改無法偵測
  - **修復**: 加入 SHA-256 雜湊驗證，每次啟動時檢查
  - **預期收益**: 偵測資料竄改或磁碟損壞

### 1.5 API 安全

- [ ] **[P1] API-01: 實作客戶端 API 速率限制**
  - **檔案**: `AgentCommand/Services/SkillsMPService.swift`, `AgentCommand/Services/IntentClassifier.swift`
  - **複雜度**: ⭐⭐ 中 (4–8h) | **CWE**: CWE-770
  - **問題**: 外部 API 呼叫無速率限制，可能導致帳戶封鎖或非預期高額費用
  - **修復**: 實作 `RateLimiter` actor，使用滑動視窗演算法限制每分鐘請求數
  - **預期收益**: 防止 API 濫用，控制 Anthropic API 成本，避免帳戶被封

- [ ] **[P2] API-02: 錯誤處理資訊洩露修復**
  - **檔案**: 多個服務檔案
  - **複雜度**: ⭐⭐ 中 (4–8h) | **CWE**: CWE-209
  - **問題**: 錯誤訊息直接顯示給使用者，可能包含內部路徑或 API 端點
  - **修復**: 對使用者顯示通用錯誤訊息，詳細資訊僅記錄於安全日誌
  - **預期收益**: 防止實作細節洩露
  - **相依**: 建議先完成統一錯誤類型體系 (ARCH-03)

- [ ] **[P3] API-03: 統一請求逾時策略**
  - **檔案**: `AgentCommand/Services/IntentClassifier.swift:391` 及其他
  - **複雜度**: ⭐ 低 (1–2h) | **CWE**: CWE-400
  - **問題**: 非所有請求路徑都有一致的逾時策略
  - **修復**: 為所有 `URLRequest` 統一設定 15–30 秒逾時
  - **預期收益**: 防止資源無限占用，提升穩定性

### 1.6 輸入驗證

- [ ] **[P2] VAL-01: 使用者提示輸入消毒**
  - **檔案**: `AgentCommand/Views/Components/PromptInputBar.swift`
  - **複雜度**: ⭐ 低 (2–4h) | **CWE**: CWE-20
  - **問題**: 使用者輸入僅做 `trimmingCharacters` 處理，直接傳遞至後端
  - **修復**: 加入輸入長度限制、過濾控制字元、實作內容安全策略
  - **預期收益**: 防止提示注入攻擊

- [ ] **[P2] VAL-02: Git 命令注入防護**
  - **檔案**: `AgentCommand/Services/GitIntegrationManager.swift`
  - **複雜度**: ⭐⭐ 中 (4–8h) | **CWE**: CWE-78
  - **問題**: Git 操作透過 `Process()` 執行，檔案路徑或分支名可能含惡意字元
  - **修復**: 確保使用 `Process.arguments` 陣列傳遞，對路徑和分支名正規化 + 白名單驗證
  - **預期收益**: 防止透過 Git 操作執行任意命令

- [ ] **[P3] VAL-03: 輸入大小限制**
  - **檔案**: 多個輸入元件
  - **複雜度**: ⭐ 低 (2–4h) | **CWE**: CWE-770
  - **問題**: 文字輸入欄位未設最大長度限制
  - **修復**: 為所有文字輸入設定合理的最大字元數
  - **預期收益**: 防止超大輸入導致記憶體問題或效能下降

---

## 2. 性能 (Performance)

### 2.1 大型檔案拆分與渲染

- [ ] **[P1] PERF-01: AppState 拆分重構**
  - **檔案**: `AgentCommand/AgentCommand/App/AppState.swift` (2,582 行)
  - **複雜度**: ⭐⭐⭐ 高 (8–16h)
  - **問題**: 單一 `@Observable` 物件包含所有應用狀態，任一屬性變更觸發全域 UI 重繪
  - **修復**: 按功能領域拆分為多個子狀態物件（`SessionState`、`UIState`、`AgentState`、`SettingsState`），或使用 Extension 分檔（`AppState+Session.swift` 等）
  - **預期收益**: 大幅減少不必要的 SwiftUI 重繪，改善 UI 流暢度、編譯速度和可維護性

- [ ] **[P2] PERF-02: CommandCenterScene 模組化**
  - **檔案**: `AgentCommand/AgentCommand/Scene3D/CommandCenterScene.swift` (1,468 行)
  - **複雜度**: ⭐⭐⭐ 高 (8–16h)
  - **問題**: 3D 場景邏輯過度集中，難以獨立測試和維護
  - **修復**: 將場景元件（燈光、相機、節點管理、動畫）拆分為獨立子系統
  - **預期收益**: 提升 3D 場景代碼的可測試性和重用性

- [ ] **[P2] PERF-03: PromptOptimizationPanel 拆分**
  - **檔案**: `AgentCommand/AgentCommand/Views/Overlays/PromptOptimizationPanel.swift` (1,373 行)
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: UI 面板邏輯過長，SwiftUI 預覽和增量編譯效能受影響
  - **修復**: 拆分為子視圖元件（分析結果區、歷史記錄區、A/B 測試區、設定區）
  - **預期收益**: 改善 SwiftUI 預覽效能、降低視圖複雜度

- [ ] **[P2] PERF-04: ContentView `.sheet` 綁定優化**
  - **檔案**: `AgentCommand/AgentCommand/Views/ContentView.swift` (770 行)
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 單一 View 管理過多 `.sheet` / `.overlay` 綁定，增加編譯時間和渲染負擔
  - **修復**: 提取子視圖，使用路由器模式管理面板切換
  - **預期收益**: 降低視圖複雜度，改善編譯速度

- [ ] **[P2] PERF-05: SceneKit 渲染效能優化**
  - **檔案**: `AgentCommand/AgentCommand/Views/Scene3DView.swift` 及相關場景檔案
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 3D 場景在多 Agent 時幀率下降
  - **修復**: 實施 LOD（Level of Detail）策略、減少遠距物件的多邊形數量、使用幾何體實例化
  - **預期收益**: 多 Agent 場景幀率提升

### 2.2 資料庫效能

- [ ] **[P1] DB-01: SQLite 添加索引**
  - **檔案**: `AgentCommand/Services/RAGDatabaseManager.swift`, `AgentCommand/Services/AgentMemoryDatabaseManager.swift`
  - **複雜度**: ⭐ 低 (1–2h)
  - **問題**: 查詢未建立索引，隨資料增長效能線性下降
  - **修復**: 為常用查詢欄位（`document_id`、`memory_id`、`agent_id`、`timestamp`）添加 `CREATE INDEX`
  - **預期收益**: 查詢效能提升 10–100x

- [ ] **[P1] DB-02: 啟用 SQLite WAL 模式**
  - **檔案**: `AgentCommand/Services/RAGDatabaseManager.swift`, `AgentCommand/Services/AgentMemoryDatabaseManager.swift`
  - **複雜度**: ⭐ 低 (<1h)
  - **問題**: 預設 journal 模式下讀寫互斥
  - **修復**: 啟動時執行 `PRAGMA journal_mode=WAL;`
  - **預期收益**: 並行讀寫效能提升，減少鎖等待

- [ ] **[P1] DB-03: N+1 查詢問題修復**
  - **檔案**: `AgentCommand/Services/RAGDatabaseManager.swift` — 迴圈內逐筆查詢關聯資料
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 列表頁面逐筆查詢造成大量 DB 來回
  - **修復**: 改用 `JOIN` 或批次查詢
  - **預期收益**: 列表載入速度顯著提升

### 2.3 快取與記憶體優化

- [ ] **[P1] CACHE-01: 快取 `fetchAllDocuments` 結果**
  - **檔案**: `AgentCommand/Services/RAGDatabaseManager.swift`
  - **複雜度**: ⭐ 低 (1–2h)
  - **問題**: 每次呼叫都重新查詢完整文件列表
  - **修復**: 加入記憶體快取層，設定 TTL 或事件驅動失效
  - **預期收益**: 減少 80%+ 的重複資料庫查詢

- [ ] **[P1] CACHE-02: 批量 `touchMemory` 操作**
  - **檔案**: `AgentCommand/Services/AgentMemoryDatabaseManager.swift`
  - **複雜度**: ⭐ 低 (1–2h)
  - **問題**: 更新記憶存取時間逐筆執行 UPDATE
  - **修復**: 合併為單次批量 UPDATE 語句
  - **預期收益**: 減少 DB 來回次數

- [ ] **[P1] CACHE-03: 向量快取設定上限**
  - **檔案**: `AgentCommand/Services/RAGDatabaseManager.swift`
  - **複雜度**: ⭐ 低 (1–2h)
  - **問題**: 向量嵌入快取無上限，記憶體可能無限增長
  - **修復**: 實施 LRU 淘汰策略，設定最大快取條目數
  - **預期收益**: 防止記憶體無限增長

- [ ] **[P2] CACHE-04: LRU 快取容量調優**
  - **檔案**: `AgentCommand/AgentCommand/Services/PromptOptimizationManager.swift:35-44`
  - **複雜度**: ⭐ 低 (2–4h)
  - **問題**: 快取最大容量 50 項、過期 5 分鐘為硬編碼值，可能不適合所有使用場景
  - **修復**: 改為可配置參數，根據記憶體壓力動態調整
  - **預期收益**: 在記憶體受限時自動減少快取，在資源充足時提升命中率

- [ ] **[P2] CACHE-05: RAG 索引改為並行處理**
  - **檔案**: `AgentCommand/Services/RAGDatabaseManager.swift`
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 大量檔案索引時串行處理，速度慢
  - **修復**: 使用 `TaskGroup` 並行索引，設定合理的並行數上限
  - **預期收益**: 大量檔案索引速度顯著提升

- [ ] **[P3] CACHE-06: Timer 與 Task 生命週期審查**
  - **檔案**: `APIUsageAnalyticsManager.swift:32`, `PerformanceMetricsManager.swift:50`, `ChatBubbleNode.swift:63`
  - **複雜度**: ⭐ 低 (2–4h)
  - **問題**: Timer 在 `deinit` 中正確 invalidate，但需確認所有非同步 Task 在視圖消失時也正確取消
  - **修復**: 審查所有 `Task {}` 呼叫，確保使用 `task.cancel()` 或 `.task` modifier 自動管理
  - **預期收益**: 防止背景任務洩漏，減少不必要的 CPU 和記憶體使用

---

## 3. 代碼品質 (Code Quality)

### 3.1 代碼重複消除

- [ ] **[P2] DRY-01: 提取百分比計算為 `Double` extension**
  - **檔案**: `Models/APIUsageAnalyticsModels.swift`、`AnalyticsDashboardModels.swift`、`PromptOptimizationModels.swift`、`ReportExportModels.swift`、`SessionHistoryAnalyticsModels.swift`、`TeamPerformanceModels.swift`
  - **複雜度**: ⭐ 低 (1–2h)
  - **問題**: `var xxxPercentage: Int { Int(value * 100) }` 跨 7 個 Model 重複 19+ 次
  - **修復**: 建立 `Double` extension `var asPercentage: Int`
  - **預期收益**: 消除 19+ 處重複代碼

- [ ] **[P2] DRY-02: 提取 `formattedCost` 為 Protocol extension**
  - **檔案**: 同上 Model 系列（8 處定義）
  - **複雜度**: ⭐ 低 (1–2h)
  - **問題**: 完全相同的 `formattedCost` 計算屬性在 7+ 個 Model 中獨立定義
  - **修復**: 定義 `CostFormattable` protocol 並提供 default implementation
  - **預期收益**: 統一格式化邏輯，減少維護成本

- [ ] **[P2] DRY-03: 建立 `PanelOverlayContainer` 基礎組件**
  - **檔案**: `AgentCommand/Views/Overlays/*.swift`（70 個檔案）
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 所有 Overlay View 共享相同的 header / background / shadow / dismiss 結構
  - **修復**: 建立統一的容器組件，各面板只需提供內容
  - **預期收益**: 減少數千行樣板代碼，統一外觀

### 3.2 靜態分析與工具鏈

- [ ] **[P1] LINT-01: 導入 SwiftLint**
  - **檔案**: 專案根目錄（新增 `.swiftlint.yml`）
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 專案無靜態分析工具，代碼風格和安全模式無自動化檢查
  - **修復**: 配置 SwiftLint 包含安全規則（force_cast、force_try、force_unwrapping），整合至建置流程
  - **預期收益**: 自動偵測強制展開、大型檔案、複雜度過高等問題；統一代碼風格

- [ ] **[P2] LINT-02: 建立安全編碼規範文件**
  - **檔案**: 新增 `docs/SECURITY-GUIDELINES.md`
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 缺乏書面的 SQL 查詢、API 金鑰管理、輸入驗證標準做法
  - **修復**: 撰寫涵蓋參數化查詢、Keychain 使用、輸入驗證的安全編碼規範
  - **預期收益**: 新程式碼不再重複已知安全錯誤，PR 審查有明確標準

### 3.3 本地化系統

- [ ] **[P3] L10N-01: L10n.swift 自動生成機制**
  - **檔案**: `AgentCommand/AgentCommand/Services/L10n.swift` (2,398 行)
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 2,398 行的本地化字串定義手動維護，容易出現遺漏或不一致
  - **修復**: 使用 SwiftGen 或自訂腳本從 `.strings` 檔案自動生成類型安全的本地化存取碼
  - **預期收益**: 減少手動維護成本，確保類型安全，自動偵測遺漏翻譯

### 3.4 測試改善

- [ ] **[P2] TEST-01: 安全漏洞自動化測試**
  - **檔案**: 新增 `Tests/SecurityTests/`
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 32 個測試檔案覆蓋功能邏輯，但無針對 SQL 注入、命令注入等安全漏洞的測試
  - **修復**: 撰寫針對 INJ-01/02 (SQL 注入)、INJ-05 (路徑遍歷)、VAL-02 (Git 命令注入) 的安全測試，包含 `'; DROP TABLE --` 等惡意輸入
  - **預期收益**: 確保安全修復不被回退，持續驗證安全邊界
  - **相依**: Phase 1 安全修復完成後

- [ ] **[P3] TEST-02: 提升核心 Service 單元測試覆蓋率**
  - **檔案**: `Tests/` 目錄
  - **複雜度**: ⭐⭐⭐ 高 (8–16h)
  - **問題**: 關鍵業務邏輯（CLIProcessManager、RAGDatabaseManager）缺乏充分測試
  - **修復**: 為核心 Service 補充單元測試，目標 > 70% 覆蓋率
  - **預期收益**: 重構和修改時的安全網

---

## 4. 依賴管理與建置 (Dependencies & Build)

### 4.1 CI/CD 建設

- [ ] **[P1] CI-01: 建立 GitHub Actions CI Pipeline**
  - **檔案**: 新增 `.github/workflows/ci.yml`
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 專案完全沒有 CI/CD 配置，所有測試和建置僅靠本地執行
  - **修復**: 配置 GitHub Actions：自動編譯 (Swift 5.9 / macOS 14+)、執行測試、SwiftLint 檢查
  - **預期收益**: 每次 PR 自動驗證，防止回退，團隊協作品質保障

- [ ] **[P2] CI-02: 建立自動化發佈流程**
  - **檔案**: 新增 `.github/workflows/release.yml`
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 缺乏自動化的版本發佈和打包流程
  - **修復**: 配置 Tag-based 自動打包、notarization、DMG 生成
  - **預期收益**: 標準化發佈流程，減少手動操作錯誤

### 4.2 Package 管理

- [ ] **[P3] PKG-01: 評估 SQLCipher 依賴引入**
  - **檔案**: `AgentCommand/Package.swift`
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 資料庫加密 (DATA-03) 需要 SQLCipher，這將是專案首個外部依賴
  - **修復**: 評估 SQLCipher SPM 整合、授權合規性（BSD 授權），以及對「零依賴」理念的取捨
  - **預期收益**: 為資料庫加密提供成熟方案，權衡專案理念與安全需求

- [ ] **[P3] PKG-02: 升級 swift-tools-version 至 6.0**
  - **檔案**: `AgentCommand/Package.swift`（目前 5.9）
  - **複雜度**: ⭐⭐⭐ 高 (8–16h)
  - **問題**: Swift 6 的嚴格並行性檢查（Strict Concurrency）可提前發現數據競爭
  - **修復**: 更新版本號，逐步修復 Sendable 警告
  - **預期收益**: 提前發現並修復潛在的數據競爭問題

---

## 5. 架構改善 (Architecture)

### 5.1 安全基礎設施

- [ ] **[P1] ARCH-01: 建立統一 KeychainService**
  - **檔案**: 新增 `AgentCommand/Services/KeychainService.swift`
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: DATA-01 和 DATA-02 修復需要 Keychain 操作，應建立統一服務避免重複代碼
  - **修復**: 建立泛用 `KeychainService` 封裝 `SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`/`SecItemUpdate`
  - **預期收益**: DATA-01、DATA-02 共用；未來所有敏感資料儲存的統一入口

- [ ] **[P2] ARCH-02: 建立統一 InputValidator**
  - **檔案**: 新增 `AgentCommand/Services/InputValidator.swift`
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: VAL-01/02/03 修復分散在各處，輸入驗證邏輯需要集中管理
  - **修復**: 建立輸入驗證服務，封裝路徑正規化、字串消毒、長度限制、Git 分支名驗證等通用邏輯
  - **預期收益**: 統一驗證標準，減少遺漏，新功能開發時可直接引用

### 5.2 錯誤處理

- [ ] **[P2] ARCH-03: 建立統一錯誤類型體系**
  - **檔案**: 新增 `AgentCommand/Models/AppError.swift`
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: API-02 修復需要區分使用者可見錯誤和內部除錯錯誤
  - **修復**: 定義 `AppError` enum（含 `.userFacing(String)` 和 `.internal(Error, context)` 分類），配合 `os.Logger`
  - **預期收益**: 錯誤不再洩露內部細節，同時保留完整除錯資訊

- [ ] **[P2] ARCH-04: Service 層統一錯誤處理**
  - **檔案**: `AgentCommand/Services/*.swift`
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 各 Service 各自處理錯誤，格式和行為不一致
  - **修復**: 定義統一的 `ServiceError` 列舉和錯誤處理管道，搭配 ARCH-03
  - **預期收益**: 一致的錯誤體驗，簡化除錯流程

### 5.3 並發模型

- [ ] **[P3] ARCH-05: @MainActor 使用範圍審查**
  - **檔案**: 56 個使用 @MainActor 的檔案
  - **複雜度**: ⭐⭐⭐ 高 (8–16h)
  - **問題**: 56 個類別標記 @MainActor，部分純計算邏輯可能不需要主執行緒
  - **修復**: 審查每個 @MainActor 標記，將純資料處理邏輯（如快取計算、資料轉換）移至非主執行緒
  - **預期收益**: 減少主執行緒負擔，提升 UI 響應性

- [ ] **[P2] ARCH-06: 減少計算屬性重複執行**
  - **檔案**: `AgentCommand/App/AppState.swift` 及 Model 檔案
  - **複雜度**: ⭐⭐ 中 (4–8h)
  - **問題**: 多個昂貴的計算屬性在 SwiftUI 重繪時反覆執行
  - **修復**: 對昂貴計算使用快取或明確的更新觸發機制
  - **預期收益**: 減少不必要的重複計算，提升效能

---

## 執行路線圖

### Phase 1: 立即修復 (72 小時) — 安全 CRITICAL

| 項目 | 編號 | 工時 | 依賴 |
|------|------|------|------|
| SQL 注入修復 (RAGDatabase) | INJ-01 | 1–2h | 無 |
| SQL 注入修復 (AgentMemory) | INJ-02 | 1–2h | 無 |
| 移除危險權限旗標 | AUTH-01 | 1h | 無 |
| SkillsMP 金鑰遷移至 Keychain | DATA-01 | 2–4h | ARCH-01 |

**Phase 1 合計**: ~6–9h

### Phase 2: 短期修復 (7 天) — 安全 HIGH + 基礎設施

| 項目 | 編號 | 工時 | 依賴 |
|------|------|------|------|
| 建立統一 KeychainService | ARCH-01 | 4–8h | 無 |
| Anthropic 金鑰遷移至 Keychain | DATA-02 | 2–4h | ARCH-01 |
| 客戶端 API 速率限制 | API-01 | 4–8h | 無 |
| 導入 SwiftLint | LINT-01 | 4–8h | 無 |
| GitHub Actions CI | CI-01 | 4–8h | 無 |
| AppState 拆分重構 | PERF-01 | 8–16h | 無 |
| SQLite 添加索引 | DB-01 | 1–2h | 無 |
| 啟用 WAL 模式 | DB-02 | <1h | 無 |

**Phase 2 合計**: ~28–55h

### Phase 3: 中期修復 (30 天) — 安全 MEDIUM + 品質

| 項目 | 編號 | 工時 | 依賴 |
|------|------|------|------|
| URL 參數注入修復 | INJ-04 | 1–2h | 無 |
| 路徑遍歷防護 | INJ-05 | 2–4h | ARCH-02 |
| 建立統一 InputValidator | ARCH-02 | 4–8h | 無 |
| 使用者提示輸入消毒 | VAL-01 | 2–4h | ARCH-02 |
| Git 命令注入防護 | VAL-02 | 4–8h | ARCH-02 |
| SSL Pinning | CRYPTO-01 | 4–8h | 無 |
| 服務層存取控制 | AUTH-02 | 8–16h | 無 |
| 錯誤處理資訊洩露修復 | API-02 | 4–8h | ARCH-03 |
| 統一錯誤類型體系 | ARCH-03 | 4–8h | 無 |
| 安全自動化測試 | TEST-01 | 4–8h | Phase 1 |
| 安全編碼規範文件 | LINT-02 | 4–8h | 無 |
| 大型檔案拆分 (Scene/Panel) | PERF-02/03 | 12–24h | 無 |
| 資料庫加密 | DATA-03 | 8–16h | PKG-01 |
| HTTP 標頭安全強化 | DATA-04 | 2–4h | 無 |
| 代碼重複消除 | DRY-01/02/03 | 6–12h | 無 |
| Service 層統一錯誤處理 | ARCH-04 | 4–8h | ARCH-03 |
| N+1 查詢修復 | DB-03 | 4–8h | 無 |

**Phase 3 合計**: ~76–152h

### Phase 4: 長期改善 (下個週期) — LOW + 架構

| 項目 | 編號 | 工時 | 依賴 |
|------|------|------|------|
| 會話管理機制 | AUTH-03 | 8–16h | 無 |
| 結構化日誌系統 | DATA-05 | 4–8h | 無 |
| 資料庫完整性驗證 | CRYPTO-02 | 4–8h | DATA-03 |
| 輸入大小限制 | VAL-03 | 2–4h | ARCH-02 |
| 統一請求逾時策略 | API-03 | 1–2h | 無 |
| L10n 自動生成 | L10N-01 | 4–8h | 無 |
| @MainActor 審查 | ARCH-05 | 8–16h | 無 |
| 自動化發佈流程 | CI-02 | 4–8h | CI-01 |
| SQLCipher 依賴評估 | PKG-01 | 4–8h | 無 |
| swift-tools-version 升級 | PKG-02 | 8–16h | 無 |
| LRU 快取調優 | CACHE-04 | 2–4h | 無 |
| Timer/Task 生命週期審查 | CACHE-06 | 2–4h | 無 |
| 核心 Service 測試覆蓋率 | TEST-02 | 8–16h | 無 |

**Phase 4 合計**: ~60–118h

---

## 任務相依關係圖

```
ARCH-01 (KeychainService) ──┬── DATA-01 (SkillsMP Key)
                            └── DATA-02 (Anthropic Key)

ARCH-02 (InputValidator) ───┬── INJ-05 (路徑遍歷)
                            ├── VAL-01 (輸入消毒)
                            ├── VAL-02 (Git 注入)
                            └── VAL-03 (輸入大小)

ARCH-03 (AppError) ─────────┬── API-02 (錯誤洩露)
                            └── ARCH-04 (Service 錯誤)

PKG-01 (SQLCipher 評估) ────── DATA-03 (DB 加密)

DATA-03 (DB 加密) ──────────── CRYPTO-02 (完整性驗證)

CI-01 (CI Pipeline) ────────── CI-02 (自動發佈)

Phase 1 安全修復 ───────────── TEST-01 (安全測試)
```

---

## 進度追蹤

| 階段 | 項目數 | 完成 | 進度 |
|------|--------|------|------|
| Phase 1 (72h) | 4 | 0 | ░░░░░░░░░░ 0% |
| Phase 2 (7天) | 8 | 0 | ░░░░░░░░░░ 0% |
| Phase 3 (30天) | 17 | 0 | ░░░░░░░░░░ 0% |
| Phase 4 (下週期) | 13 | 0 | ░░░░░░░░░░ 0% |
| **總計** | **42** | **0** | **░░░░░░░░░░ 0%** |

**總估算工時**: 170–334 小時
