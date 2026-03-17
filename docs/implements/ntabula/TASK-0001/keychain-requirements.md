# Keychain メソッド実装 要件定義書

**機能名**: keychain
**タスクID**: TASK-0001
**要件名**: ntabula
**作成日**: 2026-03-16

---

## 1. 機能の概要

### 何をする機能か 🔵

PersistenceManager に macOS Keychain アクセスメソッド（`saveToken` / `loadToken`）を実装する。現在 UserDefaults 平文保存している Notion Integration Token を、Security.framework の SecItem API を使って Keychain に安全に保存・読み込みできるようにする。

**信頼性**: 🔵 *TASK-0001.md・REQ-403・architecture.md より*

### どのような問題を解決するか 🔵

- Notion Integration Token が UserDefaults に平文保存されており、セキュリティ上問題がある（NFR-101）
- macOS Keychain に移行することで、トークンを暗号化して安全に保存する
- 既存ユーザーの UserDefaults に保存済みのトークンを自動マイグレーションする

**信頼性**: 🔵 *REQ-403・NFR-101・persistence-schema.md より*

### 想定されるユーザー 🔵

- `AppState.init()`: 起動時に `loadToken()` を呼び出してトークンを復元
- `AppState.updateNotionToken()`: ユーザーがトークンを設定・変更する際に `saveToken()` を呼び出す

**信頼性**: 🔵 *AppState.swift 既存実装より*

### システム内での位置づけ 🔵

- `PersistenceManager`（UserDefaults + Keychain ラッパー）の一部
- `AppState` → `PersistenceManager` → macOS Keychain の永続化レイヤー
- TASK-0002（AppState マイグレーション）の基盤となるコンポーネント

**信頼性**: 🔵 *architecture.md・dataflow.md より*

**参照したEARS要件**: REQ-403, NFR-101, NFR-102
**参照した設計文書**: `docs/design/ntabula/architecture.md`, `docs/design/ntabula/persistence-schema.md`

---

## 2. 入力・出力の仕様

### saveToken(_ token: String) 🔵

**信頼性**: 🔵 *persistence-schema.md Keychain操作メソッドより*

- **入力**: `token: String` — 保存する Notion Integration Token
  - 空文字列も入力として受け付ける（guard で UTF-8 変換失敗時のみスキップ）
  - nil は渡さない（String 型のため）
- **出力**: なし（`func saveToken(_ token: String)` — 戻り値なし）
- **副作用**: Keychain に `kSecClassGenericPassword` エントリを保存
  - 既存エントリは Delete → Add で上書き（SecItemUpdate は使わない）
- **エラー処理**: 静かに失敗（`guard let data` で UTF-8 変換失敗のみ早期リターン）

**実装ファイル**: `Sources/Utilities/PersistenceManager.swift`

### loadToken() -> String 🔵

**信頼性**: 🔵 *persistence-schema.md 起動時マイグレーションより*

- **入力**: なし
- **出力**: `String` — Keychain から読み込んだトークン文字列
  - Keychain に存在する場合: トークン文字列
  - Keychain にない場合（マイグレーション）: UserDefaults のトークン（存在すれば）
  - 両方にない場合: `""` （空文字列）
- **副作用（マイグレーション時のみ）**:
  1. Keychain への SecItemAdd（マイグレーション保存）
  2. UserDefaults から `"nTabula.notionToken"` キーの削除

**実装ファイル**: `Sources/Utilities/PersistenceManager.swift`

### データフロー 🔵

**信頼性**: 🔵 *dataflow.md フロー8「Keychain トークン移行フロー」より*

```
AppState.init()
  └→ PersistenceManager.loadToken()
       ├→ SecItemCopyMatching (Keychain 検索)
       │    ├ 成功: token を返す
       │    └ 失敗: UserDefaults["nTabula.notionToken"] を確認
       │         ├ 存在: SecItemAdd → removeObject(forKey:) → token を返す
       │         └ 不在: "" を返す
       └→ token を AppState.notionToken に代入
```

**参照したEARS要件**: REQ-403
**参照した設計文書**: `docs/design/ntabula/dataflow.md` フロー8

---

## 3. 制約条件

### Security.framework インポート 🔵

**信頼性**: 🔵 *architecture.md Keychain設計より*

- `import Security` を `Sources/Utilities/PersistenceManager.swift` の先頭に追加
- Xcode プロジェクト設定で Security.framework のリンクが必要（現在未追加）

### Keychain 定数仕様 🔵

**信頼性**: 🔵 *persistence-schema.md Keychainエントリより*

- `kSecAttrService = "jp.umi.design.nTabula"`（Bundle ID と一致）
- `kSecAttrAccount = "NotionToken"`
- `kSecClass = kSecClassGenericPassword`
- `kSecAttrSynchronizable` は設定しない（iCloud 同期なし）

### App Sandbox 互換性 🔵

**信頼性**: 🔵 *TASK-0001.md 注意事項より*

- App Sandbox ON のまま動作可能
- Keychain Sharing エンタイトルメント不要（単一アプリ）
- `Resources/nTabula.entitlements` の変更不要

### Swift 6 互換性 🔵

**信頼性**: 🔵 *CLAUDE.md・既存実装パターンより*

- `PersistenceManager` は `final class`（`@MainActor` 非付与）
- Keychain 操作はスレッドセーフ（macOS Security.framework 内部実装）
- `Sendable` 準拠は不要

### 既存コードへの非破壊性 🔵

**信頼性**: 🔵 *TASK-0001.md・AppState.swift より*

- 既存の `saveToken` / `loadToken` メソッドシグネチャは変更しない
- `private let defaults = UserDefaults.standard` プロパティは維持（他のメソッドで使用）
- AppState.swift への変更は不要（TASK-0002 担当）

**参照したEARS要件**: NFR-101, NFR-102, REQ-403
**参照した設計文書**: `docs/design/ntabula/architecture.md`, `Resources/nTabula.entitlements`

---

## 4. 想定される使用例

### 基本的な使用パターン 🔵

**信頼性**: 🔵 *AppState.swift 既存実装より*

```swift
// 起動時（AppState.init()）
let token = PersistenceManager.shared.loadToken()

// トークン保存時（AppState.updateNotionToken()）
PersistenceManager.shared.saveToken(newToken)
```

### エッジケース 🔵

**信頼性**: 🔵 *TASK-0001.md テストケース4・EDGE-005より*

1. **Keychain にトークンなし（新規ユーザー）**: `loadToken()` が `""` を返す
2. **UserDefaults にトークンあり（既存ユーザー）**: 自動マイグレーション実行
3. **両方にトークンなし**: `""` を返す
4. **トークン上書き**: Delete → Add で正しく上書き
5. **空文字列保存**: `token.data(using: .utf8)` は空 Data になるが保存される（guard は通過）

### エラーケース 🔵

**信頼性**: 🔵 *persistence-schema.md・設計文書より*

- `errSecItemNotFound`: Keychain にエントリなし → UserDefaults フォールバック
- UTF-8 変換失敗: `guard let data` で早期リターン（実質発生しない）
- Keychain アクセス失敗（権限エラー等）: 静かに失敗、空文字返却

**参照したEARS要件**: EDGE-005
**参照した設計文書**: `docs/design/ntabula/persistence-schema.md`

---

## 5. EARS要件・設計文書との対応関係

**参照した機能要件**:
- REQ-403: Notion Integration Token を macOS Keychain に保存しなければならない
- REQ-403: 起動時に UserDefaults からの自動マイグレーションを実施しなければならない

**参照した非機能要件**:
- NFR-101: Notion Integration Token は Keychain に暗号化保存しなければならない
- NFR-102: 既存ユーザーのトークンは起動時に自動マイグレーションしなければならない

**参照したEdgeケース**:
- EDGE-005: Keychain にトークンがない場合は空文字を返す

**参照した設計文書**:
- **アーキテクチャ**: `docs/design/ntabula/architecture.md` — Keychain設計セクション
- **データフロー**: `docs/design/ntabula/dataflow.md` — フロー8「Keychain トークン移行フロー」
- **永続化スキーマ**: `docs/design/ntabula/persistence-schema.md` — Keychain エントリ・操作メソッド
- **型定義**: `docs/design/ntabula/interfaces.swift` — PersistenceManager インターフェース
- **タスク定義**: `docs/tasks/ntabula/TASK-0001.md`

---

## 品質評価

| 評価項目 | 判定 |
|---------|------|
| 要件の曖昧さ | なし |
| 入出力定義の完全性 | 完全 |
| 制約条件の明確性 | 明確 |
| 実装可能性 | 確実 |
| 信頼性レベル分布 | 🔵 青信号 100% |

**品質評価**: ✅ 高品質

### 信頼性レベルサマリー

- 🔵 **青信号**: 全項目 (100%)
- 🟡 **黄信号**: 0項目 (0%)
- 🔴 **赤信号**: 0項目 (0%)
