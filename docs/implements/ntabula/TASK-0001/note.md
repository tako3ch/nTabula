# TASK-0001 開発コンテキストノート

**作成日**: 2026-03-16
**対象タスク**: TASK-0001: PersistenceManager Keychain メソッド実装
**要件名**: ntabula

---

## 1. 技術スタック

- **言語**: Swift 6
- **UI フレームワーク**: SwiftUI + AppKit (macOS 14.0+)
- **アーキテクチャ**: @Observable @MainActor (Single Source of Truth)
- **永続化**: UserDefaults (一般設定) + macOS Keychain (機密情報)
- **Keychain API**: Security.framework — SecItemAdd / SecItemCopyMatching / SecItemDelete
- **テスト**: XCTest（nTabulaTests ターゲット、TASK-0009 で構築予定）
- **外部依存**: なし（Security.framework は macOS 標準）

### フレームワーク設定（Xcode）

- `Carbon.framework`: 既に追加済み（HotKeyService 用）
- `Security.framework`: **未追加 → TASK-0001 で追加必要**
- Bundle ID: `jp.umi.design.nTabula`
- Deployment Target: macOS 14.0
- App Sandbox: ON（Keychain アクセス可能）

参照元: `nTabula.xcodeproj/project.pbxproj`, `CLAUDE.md`

---

## 2. 開発ルール

- **Swift 6 Concurrency**: `Sendable` 準拠、actor 使用（NotionService）
- **App Sandbox**: ON のまま動作。Keychain Sharing エンタイトルメント不要（単一アプリ）
- **iCloud 同期**: `kSecAttrSynchronizable` は設定しない（不要）
- **上書き保存方式**: Delete → Add（SecItemUpdate を使わない）
- **マイグレーション**: `loadToken()` 内で UserDefaults → Keychain の自動移行を担当
- **エラーハンドリング**: Keychain エラーは静かに失敗（空文字返却）

参照元: `docs/design/ntabula/architecture.md`, `docs/design/ntabula/persistence-schema.md`, `CLAUDE.md`

---

## 3. 関連実装

### PersistenceManager.swift（既存実装）

現在の `saveToken` / `loadToken` は UserDefaults 平文保存。これを Keychain に差し替える。

```swift
// 現在の実装 (UserDefaults 平文保存) — 置き換え対象
private enum Keys {
    static let notionToken = "nTabula.notionToken"  // ← マイグレーション後に削除
}

func saveToken(_ token: String) {
    defaults.set(token, forKey: Keys.notionToken)
}

func loadToken() -> String {
    defaults.string(forKey: Keys.notionToken) ?? ""
}
```

**実装ファイル**: `Sources/Utilities/PersistenceManager.swift`

### AppState.swift（呼び出し側）

```swift
// 起動時
init() {
    let token = PersistenceManager.shared.loadToken()  // Keychain から読込
    notionService = NotionService(token: token)
    notionToken = token
}

// トークン更新時
func updateNotionToken(_ token: String) {
    notionToken = token
    PersistenceManager.shared.saveToken(token)  // Keychain に保存
    Task { await notionService.updateToken(token) }
}
```

**実装ファイル**: `Sources/App/AppState.swift`

参照元: `Sources/Utilities/PersistenceManager.swift`, `Sources/App/AppState.swift`

---

## 4. 設計文書

### Keychain エントリ仕様

| Keychain 属性 | 値 |
|--------------|-----|
| `kSecClass` | `kSecClassGenericPassword` |
| `kSecAttrService` | `"jp.umi.design.nTabula"` |
| `kSecAttrAccount` | `"NotionToken"` |
| `kSecValueData` | Token を UTF-8 エンコードした `Data` |
| `kSecAttrSynchronizable` | 設定しない（iCloud 同期なし） |

### saveToken 実装設計

```swift
// Keychain 定数 (private)
private let keychainService = "jp.umi.design.nTabula"
private let keychainAccount = "NotionToken"

func saveToken(_ token: String) {
    guard let data = token.data(using: .utf8) else { return }
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: keychainAccount
    ]
    SecItemDelete(query as CFDictionary)  // 既存を削除
    var addQuery = query
    addQuery[kSecValueData as String] = data
    SecItemAdd(addQuery as CFDictionary, nil)
}
```

### loadToken 実装設計（マイグレーション込み）

```swift
func loadToken() -> String {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: keychainAccount,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status == errSecSuccess,
       let data = result as? Data,
       let token = String(data: data, encoding: .utf8) {
        return token
    }

    // UserDefaults マイグレーション
    let legacyToken = defaults.string(forKey: "nTabula.notionToken") ?? ""
    if !legacyToken.isEmpty {
        saveToken(legacyToken)
        defaults.removeObject(forKey: "nTabula.notionToken")
        return legacyToken
    }

    return ""
}
```

参照元: `docs/design/ntabula/persistence-schema.md`, `docs/design/ntabula/architecture.md`, `docs/tasks/ntabula/TASK-0001.md`

---

## 5. テスト関連情報

### テスト環境

- **フレームワーク**: XCTest
- **テストターゲット**: `nTabulaTests`（TASK-0009 で構築予定）
- **テストディレクトリ**: `nTabulaTests/`（現在空）
- **テストファイル予定**: `nTabulaTests/PersistenceManagerTests.swift`

### テストケース一覧（TASK-0001 対象）

| # | テストケース名 | Given | When | Then |
|---|--------------|-------|------|------|
| 1 | saveToken/loadToken 正常系 | PersistenceManager 存在 | saveToken("test-token") | loadToken() == "test-token" |
| 2 | 空トークン | Keychain にトークンなし | loadToken() | "" 返却 |
| 3 | トークン上書き | "old-token" 保存済み | saveToken("new-token") | loadToken() == "new-token" |
| 4 | UserDefaultsマイグレーション | UserDefaults に "migrated-token" | loadToken() | "migrated-token" + UserDefaults削除 + Keychain保存 |

### Keychain テストの注意点

- 実際の Keychain を使用する（モック不可）
- テスト実行後に Keychain のクリーンアップが必要
- `setUp()` でクリーンアップ、`tearDown()` でクリーンアップ
- テスト用と本番用で同じ Keychain エントリを使用するため、テスト後のクリーンアップ必須

参照元: `docs/tasks/ntabula/TASK-0001.md`

---

## 6. 注意事項

### Security.framework の追加方法

Xcode で手動追加が必要:
1. Project Navigator → nTabula ターゲット選択
2. General → Frameworks, Libraries, and Embedded Content
3. `+` → Security.framework を追加

または `xcodeproj` ファイルを直接編集して追加。

### 既存コードへの影響

- `PersistenceManager.Keys.notionToken` は loadToken() マイグレーション後も削除しない
  （UserDefaults のキー名として必要）
- `private let defaults = UserDefaults.standard` は維持（他のメソッドで使用）
- AppState.swift の変更は TASK-0002 で対応

### Swift 6 互換性

- `SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete` は Sendable 対応不要（非 actor 内の処理）
- `PersistenceManager` は `final class`（継承なし）
- Keychain 操作はメインスレッド以外でも安全（スレッドセーフ）

### エラーハンドリング方針

- Keychain エラーは `@discardableResult` または `return` で静かに失敗
- `errSecSuccess` 以外はすべて失敗として扱う
- ユーザーへのエラー通知は不要（内部的な失敗として扱う）

参照元: `CLAUDE.md`, `docs/design/ntabula/architecture.md`, `docs/spec/ntabula/requirements.md`
