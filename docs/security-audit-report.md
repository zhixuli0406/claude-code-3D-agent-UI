# AgentCommand 安全審計綜合報告

**專案名稱：** AgentCommand (claude-code-3D-agent-UI)
**審計日期：** 2026-02-13
**審計範圍：** 所有 Swift 原始碼（244 個檔案）、Shell 腳本、配置檔案
**審計執行方式：** 靜態程式碼分析（Static Code Analysis）
**報告版本：** v1.0

---

## 執行摘要

本報告彙整針對 AgentCommand 專案進行的完整安全審計結果，涵蓋注入漏洞、認證與授權、資料暴露、OWASP Top 10 及 API 安全等五大面向。

審計共發現 **21 項安全問題**，其中包含 **4 項嚴重（CRITICAL）**、**5 項高風險（HIGH）**、**8 項中等（MEDIUM）** 及 **4 項低風險（LOW）** 漏洞。

最迫切需要修復的問題為：
1. **SQL 注入漏洞** — `RAGDatabaseManager` 及 `AgentMemoryDatabaseManager` 中的 DELETE 查詢使用字串插值
2. **危險權限旗標** — CLI 程序使用 `--dangerously-skip-permissions` 繞過安全檢查
3. **API 金鑰明文儲存** — 敏感憑證存於 UserDefaults 而非 Keychain

### 嚴重程度統計

| 嚴重程度 | 數量 | 佔比 |
|----------|------|------|
| CRITICAL（嚴重） | 4 | 19% |
| HIGH（高） | 5 | 24% |
| MEDIUM（中） | 8 | 38% |
| LOW（低） | 4 | 19% |
| **合計** | **21** | **100%** |

### 漏洞分類統計

| 分類 | 數量 |
|------|------|
| 注入漏洞（Injection） | 5 |
| 認證與授權（Auth） | 3 |
| 資料暴露（Data Exposure） | 5 |
| 密碼學弱點（Cryptographic Failures） | 2 |
| API 安全（API Security） | 3 |
| 輸入驗證（Input Validation） | 3 |

---

## 嚴重程度定義

| 等級 | 說明 | SLA 建議 |
|------|------|----------|
| **CRITICAL** | 可導致遠端程式碼執行（RCE）或完整系統控制權遺失 | 立即修復（72 小時內） |
| **HIGH** | 可導致敏感資料外洩或權限提升 | 7 天內修復 |
| **MEDIUM** | 可能導致資料被不當存取或局部安全繞過 | 30 天內修復 |
| **LOW** | 安全最佳實務未遵循，風險較低 | 下一個開發週期修復 |

---

## 一、注入漏洞（Injection）

### INJ-01 [CRITICAL] SQL 注入 — RAGDatabaseManager.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/RAGDatabaseManager.swift` |
| **行號** | 175–176 |
| **OWASP 分類** | A03:2021 — Injection |
| **CWE** | CWE-89: SQL Injection |

**問題描述：**
`deleteDocument()` 函式使用字串插值直接將 `id` 參數嵌入 SQL DELETE 語句，未經任何消毒或參數化處理。

**問題程式碼：**
```swift
func deleteDocument(id: String) {
    deleteFTSEntry(docId: id)
    execute("DELETE FROM documents WHERE id = '\(id)';")        // 第 175 行
    execute("DELETE FROM relationships WHERE source_id = '\(id)' OR target_id = '\(id)';")  // 第 176 行
}
```

**潛在影響：**
- 攻擊者透過注入 `' OR '1'='1` 可刪除所有記錄
- 透過 UNION SELECT 可讀取任意資料表
- 可能導致整個知識庫被清空或資料外洩

**修復方式：**
```swift
func deleteDocument(id: String) {
    deleteFTSEntry(docId: id)

    var stmt: OpaquePointer?
    // Parameterized DELETE for documents
    if sqlite3_prepare_v2(db, "DELETE FROM documents WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK {
        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
    }
    sqlite3_finalize(stmt)

    // Parameterized DELETE for relationships
    if sqlite3_prepare_v2(db, "DELETE FROM relationships WHERE source_id = ? OR target_id = ?;", -1, &stmt, nil) == SQLITE_OK {
        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
    }
    sqlite3_finalize(stmt)
}
```

---

### INJ-02 [CRITICAL] SQL 注入 — AgentMemoryDatabaseManager.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/AgentMemoryDatabaseManager.swift` |
| **行號** | 152–153 |
| **OWASP 分類** | A03:2021 — Injection |
| **CWE** | CWE-89: SQL Injection |

**問題描述：**
`deleteMemory()` 函式存在與 INJ-01 相同的 SQL 注入漏洞。值得注意的是，該檔案中其他查詢函式已正確使用 `sqlite3_prepare_v2` 與 `sqlite3_bind_text` 參數化查詢，唯獨 DELETE 操作遺漏。

**問題程式碼：**
```swift
func deleteMemory(id: String) {
    deleteFTSEntry(memoryId: id)
    execute("DELETE FROM memories WHERE id = '\(id)';")           // 第 152 行
    execute("DELETE FROM shared_memories WHERE memory_id = '\(id)';")  // 第 153 行
}
```

**潛在影響：**
同 INJ-01 — 可刪除所有記憶資料、跨表查詢、資料外洩。

**修復方式：**
與 INJ-01 相同 — 使用 `sqlite3_prepare_v2` + `sqlite3_bind_text` 參數化查詢。

---

### INJ-03 [HIGH] 命令注入風險 — CLIProcessManager.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/CLIProcessManager.swift` |
| **行號** | 63 |
| **OWASP 分類** | A03:2021 — Injection |
| **CWE** | CWE-78: OS Command Injection |

**問題描述：**
CLI 程序啟動時使用 `--dangerously-skip-permissions` 旗標，這會繞過 Claude CLI 的內建權限檢查系統。使用者提供的 `prompt` 參數直接傳遞給 CLI，未經內容驗證。

**問題程式碼：**
```swift
var args = extraArgs + [
    "-p", prompt,
    "--output-format", "stream-json",
    "--verbose",
    "--dangerously-skip-permissions",  // 第 63 行 — 危險旗標
    "--model", model.cliModelId
]
```

**潛在影響：**
- 惡意提示可能觸發系統命令執行
- 繞過 Claude CLI 設計的安全檢查機制
- 潛在的任意程式碼執行（RCE）

**修復方式：**
1. 移除 `--dangerously-skip-permissions` 旗標
2. 若業務需求必須保留，應實作提示內容過濾與白名單驗證
3. 加入使用者確認步驟（至少對破壞性操作）

---

### INJ-04 [MEDIUM] URL 參數注入 — SkillsMPService.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/SkillsMPService.swift` |
| **行號** | 46–50, 69–73 |
| **OWASP 分類** | A03:2021 — Injection |
| **CWE** | CWE-20: Improper Input Validation |

**問題描述：**
URL 構建使用字串插值，`page`、`limit`、`sortBy` 等參數未經驗證直接嵌入 URL。

**問題程式碼：**
```swift
guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
      let url = URL(string: "\(baseURL)/search?q=\(encoded)&page=\(page)&limit=\(limit)&sort_by=\(sortBy)") else {
    // ...
}
```

**修復方式：**
```swift
var components = URLComponents(string: "\(baseURL)/search")
components?.queryItems = [
    URLQueryItem(name: "q", value: trimmed),
    URLQueryItem(name: "page", value: String(max(1, page))),
    URLQueryItem(name: "limit", value: String(min(max(1, limit), 100))),
    URLQueryItem(name: "sort_by", value: sortBy)
]
guard let url = components?.url else { return }
```

---

### INJ-05 [MEDIUM] 路徑遍歷風險 — CLIProcessManager.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/CLIProcessManager.swift` |
| **行號** | 68 |
| **OWASP 分類** | A01:2021 — Broken Access Control |
| **CWE** | CWE-22: Path Traversal |

**問題描述：**
`workingDirectory` 參數直接從使用者輸入接受，未經路徑正規化（canonicalization）或白名單驗證。攻擊者可使用 `../` 進行目錄遍歷。

**問題程式碼：**
```swift
process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)  // 無驗證
```

**修復方式：**
```swift
let resolvedPath = URL(fileURLWithPath: workingDirectory).standardizedFileURL.path
guard resolvedPath.hasPrefix("/Users/") || resolvedPath.hasPrefix("/tmp/") else {
    throw SecurityError.invalidWorkingDirectory(resolvedPath)
}
process.currentDirectoryURL = URL(fileURLWithPath: resolvedPath)
```

---

## 二、認證與授權（Authentication & Authorization）

### AUTH-01 [CRITICAL] 危險權限繞過 — CLIProcessManager.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/CLIProcessManager.swift` |
| **行號** | 63 |
| **OWASP 分類** | A01:2021 — Broken Access Control |
| **CWE** | CWE-862: Missing Authorization |

**問題描述：**
`--dangerously-skip-permissions` 旗標完全繞過 Claude CLI 的權限檢查機制，等同於以最高權限執行所有操作，無需使用者授權。

**潛在影響：**
- 所有 CLI 操作均在無權限檢查下執行
- 檔案系統讀寫無限制
- 可能執行破壞性系統命令

**修復方式：**
1. **移除此旗標**（首選）
2. 若必須保留，實作應用層級的權限檢查替代方案
3. 加入操作審計日誌記錄所有 CLI 執行

---

### AUTH-02 [MEDIUM] 缺乏存取控制層 — 多個服務檔案

| 項目 | 內容 |
|------|------|
| **檔案** | 多個 Manager 服務（RAGSystemManager, AgentMemorySystemManager 等） |
| **OWASP 分類** | A01:2021 — Broken Access Control |
| **CWE** | CWE-284: Improper Access Control |

**問題描述：**
所有 Manager 服務的公開方法均無存取控制檢查。任何持有 Manager 參考的程式碼都可直接呼叫刪除、修改等破壞性操作。

**修復方式：**
1. 為敏感操作（刪除、批量修改）加入使用者確認對話框
2. 實作操作權限等級分類

---

### AUTH-03 [LOW] 無會話管理機制

| 項目 | 內容 |
|------|------|
| **檔案** | 全域 |
| **OWASP 分類** | A07:2021 — Identification and Authentication Failures |

**問題描述：**
應用程式無會話逾時或自動鎖定機制。API 金鑰一旦設定將永久有效直到手動移除。

**修復方式：**
1. 加入閒置自動清除敏感資料的機制
2. 考慮加入應用程式鎖（Touch ID / 密碼）

---

## 三、資料暴露（Data Exposure）

### DATA-01 [CRITICAL] API 金鑰明文儲存於 UserDefaults — SkillsMPService.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/SkillsMPService.swift` |
| **行號** | 12, 16–26 |
| **OWASP 分類** | A02:2021 — Cryptographic Failures |
| **CWE** | CWE-312: Cleartext Storage of Sensitive Information |

**問題描述：**
SkillsMP API 金鑰以明文形式存於 `UserDefaults`。在 macOS 上，UserDefaults 儲存為 plist 檔案（`~/Library/Preferences/`），任何擁有檔案系統存取權的程式均可讀取。

**問題程式碼：**
```swift
private static let apiKeyStorageKey = "skillsmp_api_key"

var apiKey: String? {
    get { UserDefaults.standard.string(forKey: Self.apiKeyStorageKey) }
    set {
        if let key = newValue, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: Self.apiKeyStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.apiKeyStorageKey)
        }
    }
}
```

**潛在影響：**
- 本地惡意程式可讀取 API 金鑰
- 系統備份中包含明文金鑰
- Time Machine 備份可能保留歷史金鑰

**修復方式：**
```swift
import Security

private func saveToKeychain(key: String, value: String) {
    let data = value.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecAttrService as String: Bundle.main.bundleIdentifier ?? "AgentCommand",
        kSecValueData as String: data
    ]
    SecItemDelete(query as CFDictionary)  // Remove existing
    SecItemAdd(query as CFDictionary, nil)
}

private func loadFromKeychain(key: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecAttrService as String: Bundle.main.bundleIdentifier ?? "AgentCommand",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}
```

---

### DATA-02 [HIGH] Anthropic API 金鑰明文儲存 — IntentClassifier.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/IntentClassifier.swift` |
| **行號** | 423 |
| **OWASP 分類** | A02:2021 — Cryptographic Failures |
| **CWE** | CWE-312: Cleartext Storage of Sensitive Information |

**問題描述：**
Anthropic API 金鑰存於 UserDefaults（`anthropic_api_key`）。雖然環境變數優先級較高，但 UserDefaults 回退方案仍存在明文儲存風險。

**問題程式碼：**
```swift
static func resolveAnthropicAPIKey() -> String? {
    if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
        return envKey
    }
    if let storedKey = UserDefaults.standard.string(forKey: "anthropic_api_key"), !storedKey.isEmpty {
        return storedKey
    }
    return nil
}
```

**修復方式：**
同 DATA-01 — 遷移至 macOS Keychain。

---

### DATA-03 [HIGH] 資料庫未加密 — RAGDatabaseManager.swift / AgentMemoryDatabaseManager.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/RAGDatabaseManager.swift:26`、`AgentCommand/Services/AgentMemoryDatabaseManager.swift:26` |
| **OWASP 分類** | A02:2021 — Cryptographic Failures |
| **CWE** | CWE-311: Missing Encryption of Sensitive Data |

**問題描述：**
兩個 SQLite 資料庫（`knowledge.db`、`agent_memory.db`）使用 `sqlite3_open()` 開啟，未啟用任何加密。資料庫檔案以明文儲存於磁碟。

**問題程式碼：**
```swift
let dbPath = dbDirectory.appendingPathComponent("knowledge.db").path
if sqlite3_open(dbPath, &db) != SQLITE_OK { /* ... */ }
```

**潛在影響：**
- 程式碼知識庫與代理記憶以明文存於磁碟
- 系統備份中包含完整資料庫內容
- 磁碟鑑識可輕易取得所有資料

**修復方式：**
1. 整合 SQLCipher 替代原生 SQLite（提供透明加密）
2. 或使用 macOS Data Protection API（`FileProtectionType.complete`）
3. 最低限度：對敏感欄位進行應用層加密

---

### DATA-04 [MEDIUM] API 金鑰在 HTTP 標頭中傳輸

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/SkillsMPService.swift:91`、`AgentCommand/Services/IntentClassifier.swift:388` |
| **OWASP 分類** | A02:2021 — Cryptographic Failures |

**問題描述：**
API 金鑰透過 HTTP 請求標頭傳送（`Authorization: Bearer` 及 `x-api-key`）。雖然目標 URL 使用 HTTPS，但日誌、代理伺服器或記憶體傾印可能洩露這些值。

**緩解因素：** 已確認使用 HTTPS（`https://skillsmp.com/api/v1/` 及 `https://api.anthropic.com/v1/`）。

**修復方式：**
1. 確保不在日誌中記錄請求標頭
2. 使用後立即清除記憶體中的金鑰字串
3. 啟用 App Transport Security (ATS) 確保 HTTPS 強制執行

---

### DATA-05 [LOW] 敏感資料可能出現在日誌中

| 項目 | 內容 |
|------|------|
| **檔案** | 多個服務檔案 |
| **OWASP 分類** | A09:2021 — Security Logging and Monitoring Failures |
| **CWE** | CWE-532: Insertion of Sensitive Information into Log File |

**問題描述：**
使用 `print()` 進行除錯輸出，可能在生產環境中洩露敏感資訊。建議使用 `os.Logger` 並區分日誌等級。

**修復方式：**
```swift
import os
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AgentCommand", category: "Security")
// Use logger.debug() for non-sensitive info, logger.info() for operational info
// Never log API keys, tokens, or user credentials
```

---

## 四、密碼學弱點（Cryptographic Failures）

### CRYPTO-01 [MEDIUM] 無傳輸層安全驗證

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/SkillsMPService.swift`、`AgentCommand/Services/IntentClassifier.swift` |
| **OWASP 分類** | A02:2021 — Cryptographic Failures |
| **CWE** | CWE-295: Improper Certificate Validation |

**問題描述：**
網路請求使用預設的 `URLSession`，未實作 SSL Pinning（憑證固定）。雖然 macOS ATS 提供基本保護，但針對性攻擊（如企業 MITM Proxy）可能繞過。

**修復方式：**
1. 為關鍵 API 端點實作 SSL Pinning
2. 使用 `URLSessionDelegate` 的 `urlSession(_:didReceive:completionHandler:)` 驗證伺服器憑證

---

### CRYPTO-02 [LOW] 缺乏資料完整性驗證

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/RAGDatabaseManager.swift`、`AgentCommand/Services/AgentMemoryDatabaseManager.swift` |
| **CWE** | CWE-354: Improper Validation of Integrity Check Value |

**問題描述：**
資料庫檔案無完整性檢查機制。若資料庫檔案被外部修改（惡意程式或磁碟損壞），應用程式無法偵測。

**修復方式：**
對資料庫檔案加入雜湊驗證（SHA-256），在每次啟動時驗證。

---

## 五、API 安全（API Security）

### API-01 [HIGH] 無 API 速率限制

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/SkillsMPService.swift`、`AgentCommand/Services/IntentClassifier.swift` |
| **OWASP 分類** | A04:2021 — Insecure Design |
| **CWE** | CWE-770: Allocation of Resources Without Limits |

**問題描述：**
外部 API 呼叫（SkillsMP、Anthropic）無客戶端速率限制。惡意或錯誤的使用模式可能導致：
- API 帳戶被封鎖
- 非預期的高額費用（尤其 Anthropic API）
- 對外部服務造成 DoS

**修復方式：**
```swift
actor RateLimiter {
    private var requestTimestamps: [Date] = []
    private let maxRequestsPerMinute: Int

    init(maxPerMinute: Int = 60) {
        self.maxRequestsPerMinute = maxPerMinute
    }

    func shouldAllow() -> Bool {
        let now = Date()
        requestTimestamps = requestTimestamps.filter { now.timeIntervalSince($0) < 60 }
        guard requestTimestamps.count < maxRequestsPerMinute else { return false }
        requestTimestamps.append(now)
        return true
    }
}
```

---

### API-02 [MEDIUM] 錯誤處理洩露資訊

| 項目 | 內容 |
|------|------|
| **檔案** | 多個服務檔案 |
| **OWASP 分類** | A09:2021 — Security Logging and Monitoring Failures |
| **CWE** | CWE-209: Generation of Error Message Containing Sensitive Information |

**問題描述：**
錯誤訊息直接顯示給使用者，可能包含內部路徑、API 端點或其他實作細節。

**修復方式：**
1. 對使用者顯示通用錯誤訊息
2. 詳細錯誤資訊僅記錄於安全日誌

---

### API-03 [LOW] 無請求逾時保護

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/IntentClassifier.swift:391` |
| **CWE** | CWE-400: Uncontrolled Resource Consumption |

**問題描述：**
部分網路請求設有逾時（10 秒、15 秒），但非所有請求路徑都有一致的逾時策略。

**修復方式：**
為所有 `URLRequest` 統一設定合理的逾時值（建議 15–30 秒）。

---

## 六、輸入驗證（Input Validation）

### VAL-01 [MEDIUM] 使用者輸入未消毒 — PromptInputBar.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Views/Components/PromptInputBar.swift` |
| **OWASP 分類** | A03:2021 — Injection |
| **CWE** | CWE-20: Improper Input Validation |

**問題描述：**
使用者在提示輸入欄位輸入的文字直接傳遞至後端處理，僅做 `trimmingCharacters(in: .whitespacesAndNewlines)` 處理。

**修復方式：**
1. 加入輸入長度限制
2. 過濾或轉義特殊控制字元
3. 實作內容安全策略

---

### VAL-02 [MEDIUM] Git 命令注入風險 — GitIntegrationManager.swift

| 項目 | 內容 |
|------|------|
| **檔案** | `AgentCommand/Services/GitIntegrationManager.swift` |
| **OWASP 分類** | A03:2021 — Injection |
| **CWE** | CWE-78: OS Command Injection |

**問題描述：**
Git 相關操作透過 `Process()` 執行 shell 命令，若檔案路徑或分支名稱包含惡意字元，可能導致命令注入。

**修復方式：**
1. 使用 `Process.arguments` 陣列傳遞參數（而非字串拼接）
2. 對所有路徑和分支名稱進行正規化和白名單驗證

---

### VAL-03 [LOW] 缺乏輸入大小限制

| 項目 | 內容 |
|------|------|
| **檔案** | 多個輸入元件 |
| **CWE** | CWE-770: Allocation of Resources Without Limits |

**問題描述：**
文字輸入欄位未設定最大長度限制，超大輸入可能導致記憶體問題或效能下降。

**修復方式：**
為所有文字輸入設定合理的最大字元數限制。

---

## 修復優先級路線圖

### 第一階段：立即修復（72 小時內） — CRITICAL

| 編號 | 問題 | 工作量預估 | 影響 |
|------|------|-----------|------|
| INJ-01 | RAGDatabaseManager SQL 注入 | 1–2 小時 | 阻止資料庫被完全控制 |
| INJ-02 | AgentMemoryDatabaseManager SQL 注入 | 1–2 小時 | 同上 |
| DATA-01 | SkillsMP API 金鑰遷移至 Keychain | 2–4 小時 | 保護 API 憑證 |
| AUTH-01 | 移除 `--dangerously-skip-permissions` | 1 小時 | 恢復權限檢查機制 |

### 第二階段：短期修復（7 天內） — HIGH

| 編號 | 問題 | 工作量預估 | 影響 |
|------|------|-----------|------|
| INJ-03 | CLI 命令注入防護 | 4–8 小時 | 防止 RCE |
| DATA-02 | Anthropic API 金鑰遷移至 Keychain | 2–4 小時 | 保護 API 憑證 |
| DATA-03 | 資料庫加密（SQLCipher） | 8–16 小時 | 保護靜態資料 |
| API-01 | 實作 API 速率限制 | 4–8 小時 | 防止 API 濫用 |

### 第三階段：中期修復（30 天內） — MEDIUM

| 編號 | 問題 | 工作量預估 | 影響 |
|------|------|-----------|------|
| INJ-04 | URL 參數注入修復 | 1–2 小時 | 強化輸入驗證 |
| INJ-05 | 路徑遍歷防護 | 2–4 小時 | 防止未授權存取 |
| AUTH-02 | 加入存取控制層 | 8–16 小時 | 強化權限管理 |
| CRYPTO-01 | SSL Pinning 實作 | 4–8 小時 | 防止 MITM |
| DATA-04 | HTTP 標頭安全強化 | 2–4 小時 | 減少洩露面 |
| VAL-01 | 提示輸入消毒 | 2–4 小時 | 防止注入 |
| VAL-02 | Git 命令注入防護 | 4–8 小時 | 防止 RCE |
| API-02 | 錯誤處理強化 | 4–8 小時 | 防止資訊洩露 |

### 第四階段：長期改善（下一開發週期） — LOW

| 編號 | 問題 | 工作量預估 | 影響 |
|------|------|-----------|------|
| AUTH-03 | 會話管理機制 | 8–16 小時 | 強化使用者安全 |
| DATA-05 | 結構化日誌系統 | 4–8 小時 | 安全監控基礎 |
| CRYPTO-02 | 資料完整性驗證 | 4–8 小時 | 防止資料竄改 |
| VAL-03 | 輸入大小限制 | 2–4 小時 | 防止資源耗盡 |
| API-03 | 統一逾時策略 | 1–2 小時 | 提升穩定性 |

---

## 安全改善建議

### 短期建議

1. **建立安全編碼規範文件** — 記錄 SQL 查詢、API 金鑰管理、輸入驗證的標準做法
2. **導入靜態分析工具** — 如 SwiftLint 安全規則或 SonarQube，自動偵測常見安全模式
3. **程式碼審查安全清單** — PR 審查時加入安全檢查項目

### 中期建議

4. **建立統一的安全服務層** — 集中管理 Keychain 操作、輸入驗證、安全日誌
5. **實作安全測試** — 針對 SQL 注入、命令注入等漏洞撰寫自動化測試
6. **定期安全審計** — 每季度執行一次安全審計，追蹤修復進度

### 長期建議

7. **導入威脅模型分析** — 對關鍵功能進行 STRIDE 威脅分析
8. **建立安全事件回應計畫** — 定義 API 金鑰洩露等安全事件的處理流程
9. **安全意識培訓** — 定期對開發團隊進行 OWASP Top 10 等安全培訓

---

## 正面發現

審計同時發現以下安全良好實踐：

1. **HTTPS 強制使用** — 所有外部 API 端點均使用 HTTPS
2. **無硬編碼密鑰** — 未發現原始碼中嵌入的 API 金鑰或密碼
3. **部分參數化查詢** — 部分資料庫操作已正確使用參數化查詢（`sqlite3_bind_text`）
4. **環境變數優先** — API 金鑰優先從環境變數讀取
5. **Process.arguments 陣列** — 大部分 CLI 操作使用陣列傳遞參數而非字串拼接

---

## 結論

AgentCommand 專案存在若干需要立即關注的安全問題，其中 SQL 注入和 API 金鑰明文儲存為最高優先修復項目。這些修復工作量相對較小（各約 2–4 小時），但對整體安全態勢的改善效果顯著。

建議開發團隊按照上述路線圖優先處理第一階段（CRITICAL）問題，並逐步推進後續階段的安全改善工作。

---

*報告由靜態安全分析產生，建議搭配動態測試（DAST）與滲透測試以獲得更完整的安全評估。*
