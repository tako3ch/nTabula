# nTabula アーキテクチャ設計

**作成日**: 2026-03-16
**更新日**: 2026-03-16（kairo-design によるヒアリング反映）
**関連要件定義**: [requirements.md](../../spec/ntabula/requirements.md)
**ヒアリング記録**: [design-interview.md](design-interview.md)

**【信頼性レベル凡例】**:
- 🔵 **青信号**: EARS要件定義書・設計文書・ユーザヒアリングを参考にした確実な設計
- 🟡 **黄信号**: EARS要件定義書・設計文書・ユーザヒアリングから妥当な推測による設計
- 🔴 **赤信号**: EARS要件定義書・設計文書・ユーザヒアリングにない推測による設計

---

## システム概要 🔵

**信頼性**: 🔵 *CLAUDE.md・architecture.md(逆生成)より*

nTabula は Notion にマークダウンを保存できる macOS ネイティブメモアプリ。ローカルで素早くメモし、好きなタイミングで Notion に同期するワークフローを実現する。ヘビー Notion ユーザー・軽量エディタを求めるユーザーの両方を対象とする。

## アーキテクチャパターン 🔵

**信頼性**: 🔵 *architecture.md(逆生成)・既存実装より*

- **パターン**: MVVM-like（`@Observable AppState` を ViewModel として機能させる単方向データフロー）
- **選択理由**: SwiftUI の `@Observable` + `@Environment` によるリアクティブな状態配信と、AppKit (`NSTextView`) との `NSViewRepresentable` ブリッジを組み合わせた macOS ネイティブアーキテクチャ

## コンポーネント構成

### UI 層 🔵

**信頼性**: 🔵 *既存実装 Views/ より*

- **フレームワーク**: SwiftUI (macOS 14.0+)
- **AppKit 統合**: `NSViewRepresentable` ブリッジ（`EditorView` ← `NSTextView`）
- **状態管理**: `@Observable` マクロ + `@Environment` 依存注入
- **ウィンドウ管理**: `AppDelegate` (`NSApplicationDelegateAdaptor`)

### ビジネスロジック層 🔵

**信頼性**: 🔵 *既存実装 App/, Services/ より*

- **状態ハブ**: `AppState` (`@MainActor` シングルトン)
- **Notion クライアント**: `NotionService` (`actor` で排他制御)
- **ホットキー**: Carbon API (`RegisterEventHotKey`) — Ctrl+Shift+N

### データアクセス層 🔵

**信頼性**: 🔵 *既存実装 Utilities/ + ユーザヒアリング 2026-03-16 Keychain確認より*

- **永続化**: `PersistenceManager`（UserDefaults ラッパー、`init(defaults:)` overload でテスト注入対応）
- **トークン保管**: macOS Keychain (`Security.framework`) ← UserDefaults から移行
- **ネットワーク**: `URLSession`（`NotionService` 内部、`init(token:session:)` overload でテスト注入対応）
- **DB**: なし（ローカルデータはすべて UserDefaults）

---

## 新規実装設計（kairo-requirements 確定要件）

### 1. Keychain トークン保管 🔵

**信頼性**: 🔵 *REQ-403・NFR-101・ユーザヒアリング 2026-03-16 Keychain確認*

**要件**: REQ-403, NFR-101

`Security.framework` の SecItem API を `PersistenceManager` 内に直接実装。

```
kSecClass        = kSecClassGenericPassword
kSecAttrService  = "jp.umi.design.nTabula"
kSecAttrAccount  = "NotionToken"
kSecValueData    = token.data(using: .utf8)
```

**移行戦略（起動時自動移行）**: 🔵 *ユーザヒアリング 2026-03-16 移行戦略確認より*

```
AppState.init():
  1. PersistenceManager.loadToken() → Keychain から試行
  2. Keychain にない場合のみ UserDefaults["nTabula.notionToken"] を読む
  3. UserDefaults にある場合: Keychain に保存 → UserDefaults から削除
```

**App Sandbox 考慮事項**: 🔵 *ユーザヒアリング 2026-03-16 Keychain実装確認より*

- `kSecAttrSynchronizable` 不要（単一アプリ、iCloud 同期なし）
- Keychain Sharing は不要（同一 Bundle ID 内のみ使用）
- App Sandbox ON のまま動作（App Sandbox は Keychain アクセスをブロックしない）

### 2. Cmd+W キーバインド 🔵

**信頼性**: 🔵 *REQ-105・ユーザヒアリング 2026-03-16 Cmd+W確認より*

**要件**: REQ-105

`nTabulaApp.swift` の `Commands` ブロックに追加。既存の Cmd+T (`addNewTab`) と同じパターン。

```swift
// nTabulaApp.swift
CommandGroup(replacing: .newItem) {
    Button("新規タブ") { appState.addNewTab() }
        .keyboardShortcut("t", modifiers: .command)
    Button("タブを閉じる") { ... appState.closeTab(tab) }
        .keyboardShortcut("w", modifiers: .command)
        .disabled(appState.activeTab == nil)
}
```

ピン留めタブは `closeTab` 内の既存ガード (`isPinned` チェック) で保護される。

### 3. タブ D&D 並び替え 🔵

**信頼性**: 🔵 *REQ-305・ユーザヒアリング 2026-03-16 D&Dアプローチ確認より*

**要件**: REQ-305

SwiftUI `.draggable` / `.dropDestination` (macOS 14+ ネイティブ) を使用。

- **TabBarView（横タブ）**: 各タブビューに `.draggable(tab.id)` + `.dropDestination(for: UUID.self)` を付与
- **VerticalSidebarView（縦サイドバー）**: `List` の `onMove` または `.draggable` / `.dropDestination` を使用
- **制約**: ピン留めタブ ⇔ 非ピン留めタブ間の移動は禁止（isPinned チェック）
- **AppState**: `moveTab(fromOffsets:toOffset:)` メソッドを追加

### 4. テスト可能化（依存注入） 🔵

**信頼性**: 🔵 *NFR-301・NFR-302・ユーザヒアリング 2026-03-16 Unit Test確認より*

**要件**: NFR-301, NFR-302

| クラス | overload | テスト時の使用方法 |
|--------|----------|-----------------|
| `NotionService` | `init(token: String, session: URLSession = .shared)` | `MockURLProtocol` を登録した `URLSession` を注入 |
| `PersistenceManager` | `init(defaults: UserDefaults = .standard)` | `UserDefaults(suiteName: "test-\(UUID())")` を注入 |

---

## システム構成図

```mermaid
graph TB
    subgraph "macOS App (nTabula)"
        HK[HotKeyService\nCtrl+Shift+N]
        AD[AppDelegate\nWindow管理]
        AS[AppState\n@Observable @MainActor]
        CMD[Commands\nCmd+T / Cmd+W / Cmd+S]

        subgraph "Views"
            MW[MainWindowView]
            EV[EditorView\nNSViewRepresentable]
            TB[TabBarView\n横タブ + D&D]
            SB[VerticalSidebarView\n縦サイドバー + D&D]
            ST[SettingsView]
        end

        NS[NotionService\nactor + URLSession注入]
        PM[PersistenceManager\nUserDefaults注入]
        MTN[MarkdownToNotion]
    end

    subgraph "Storage"
        UD[(UserDefaults\nタブ・設定)]
        KC[(macOS Keychain\nNotionToken)]
    end

    subgraph "External"
        NOTION[Notion REST API\nv2022-06-28]
    end

    HK --> AD
    AD --> AS
    CMD --> AS
    AS --> Views
    Views --> AS
    AS --> NS
    NS --> NOTION
    AS --> PM
    PM --> UD
    PM --> KC
    AS --> MTN
```

**信頼性**: 🔵 *要件定義・既存設計より*

---

## ディレクトリ構造 🔵

**信頼性**: 🔵 *既存プロジェクト構造・CLAUDE.mdより*

```
Sources/
├── App/
│   ├── nTabulaApp.swift     # @main + Commands (Cmd+T, Cmd+W, Cmd+S)
│   ├── AppDelegate.swift    # NSWindow管理, HotKeyService起動
│   └── AppState.swift       # @Observable グローバル状態 + moveTab()
├── Models/
│   ├── TabItem.swift        # タブモデル + TabLayoutMode
│   └── NotionModels.swift   # Notion APIレスポンス型 (Sendable)
├── Services/
│   ├── NotionService.swift  # actor + init(token:session:) overload
│   └── HotKeyService.swift  # Carbon RegisterEventHotKey
├── Views/
│   ├── MainWindowView.swift # ルートレイアウト (横/縦切り替え)
│   ├── EditorView.swift     # NSTextView + MarkdownTextStorage
│   ├── TabBarView.swift     # 横タブ + .draggable/.dropDestination
│   ├── VerticalSidebarView.swift # 縦サイドバー + D&D
│   └── SettingsView.swift   # 設定 (一般 / Notion)
└── Utilities/
    ├── MarkdownToNotion.swift
    └── PersistenceManager.swift # UserDefaults + Keychain + init(defaults:)
```

---

## 非機能要件の実現方法

### パフォーマンス 🔵

**信頼性**: 🔵 *NFR-001・NFR-002・NFR-003・既存実装より*

- **シンタックスHL**: 変更された段落範囲のみ再計算 (`paragraphRange`)
- **タブ切り替え**: `tabID` 変化時のみ `textView.string` を更新
- **Notion 同期**: `isDirty == false && notionPageID != nil` の場合スキップ

### セキュリティ 🔵

**信頼性**: 🔵 *REQ-402・REQ-403・NFR-101・NFR-102・NFR-103より*

- **トークン保管**: macOS Keychain (`kSecClassGenericPassword`) ← UserDefaults から移行
- **App Sandbox**: ON — Network Client (Outgoing) のみ許可
- **HTTPS**: Notion API は HTTPS 必須 (App Sandbox により強制)
- **SecureField**: トークン入力は `SecureField` (`NSSecureTextField` ラップ)

### 可用性・信頼性 🔵

**信頼性**: 🔵 *NFR-201・NFR-202より*

- **エラー表示**: `syncError` を StatusBar に赤文字で即時表示
- **再起動後の復元**: UserDefaults からタブ一覧・設定を復元、Keychain からトークンを復元

### テスト可能性 🔵

**信頼性**: 🔵 *NFR-301・NFR-302・NFR-303より*

- **NotionService**: `URLSession` 注入 → `MockURLProtocol` によるネットワークモック
- **PersistenceManager**: `UserDefaults` 注入 → `UserDefaults(suiteName:)` によるストレージ分離

---

## 技術的制約

### Notion API 制約 🔵

**信頼性**: 🔵 *REQ-401・REQ-404・REQ-406・CLAUDE.mdより*

- `page_size`: 100 固定（ページネーション UI 不要）
- ブロック更新方式: 全削除 → 再追加（差分更新なし）
- API バージョン: `2022-06-28`

### Markdown サポート範囲 🔵

**信頼性**: 🔵 *REQ-405・CLAUDE.md・既存実装より*

- 対応: H1-H3、引用、箇条書き・番号付き・ToDo リスト、コードブロック、水平線、インライン (bold/italic/code/strikethrough/link)
- H4 以降: `paragraph` にフォールバック
- 非対応: テーブル、画像・添付ファイル

### Swift 6 / App Sandbox 🔵

**信頼性**: 🔵 *REQ-402・CLAUDE.md・既存実装より*

- `Sendable` 準拠 (`NotionModels.swift`)
- App Sandbox ON のまま Keychain アクセス可能（同一アプリ内）
- `kSecAttrSynchronizable` 不要（単一アプリ、iCloud 同期なし）

---

## 関連文書

- **データフロー**: [dataflow.md](dataflow.md)
- **型定義**: [interfaces.swift](interfaces.swift)
- **Notion API 仕様**: [api-specs.md](api-specs.md)
- **永続化スキーマ**: [persistence-schema.md](persistence-schema.md)
- **ヒアリング記録**: [design-interview.md](design-interview.md)
- **要件定義**: [requirements.md](../../spec/ntabula/requirements.md)

---

## 信頼性レベルサマリー

- 🔵 青信号: 29件 (97%)
- 🟡 黄信号: 1件 (3%)
- 🔴 赤信号: 0件 (0%)

**品質評価**: ✅ 高品質（実装コード + ユーザヒアリングで全件確認済み）
