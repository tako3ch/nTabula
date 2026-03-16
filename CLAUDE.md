# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

**nTabula** — Notion にマークダウンを保存できる macOS メモアプリ（umi.design 自社プロジェクト）

- Swift / SwiftUI + AppKit（macOS 14+）
- Notion REST API（Integration Token 認証）
- 外部依存なし

## ディレクトリ構成

```
nTabula/                         ← プロジェクトルート（ここを編集する）
├── nTabula.xcodeproj
├── nTabula/                     ← Xcode 自動生成フォルダ（触らない）
├── Sources/
│   ├── App/
│   │   ├── nTabulaApp.swift     # @main エントリ、コマンド登録
│   │   ├── AppDelegate.swift    # ウィンドウ管理、HotKeyService 起動
│   │   └── AppState.swift       # @Observable @MainActor グローバル状態
│   ├── Models/
│   │   ├── TabItem.swift        # タブモデル（Codable）+ TabLayoutMode enum
│   │   └── NotionModels.swift   # Notion API レスポンス型（Decodable + Sendable）
│   ├── Services/
│   │   ├── NotionService.swift  # actor、Notion REST API クライアント
│   │   └── HotKeyService.swift  # Carbon RegisterEventHotKey（Ctrl+Shift+N）
│   ├── Views/
│   │   ├── MainWindowView.swift # ルートレイアウト（横/縦タブ切り替え）
│   │   ├── EditorView.swift     # NSTextView + MarkdownTextStorage（シンタックスHL）
│   │   ├── TabBarView.swift     # 横タブバー
│   │   ├── VerticalSidebarView.swift # Arc 風縦タブサイドバー
│   │   └── SettingsView.swift   # 設定ウィンドウ（一般 / Notion）
│   └── Utilities/
│       ├── MarkdownToNotion.swift   # Markdown → [[String: Any]] ブロック変換
│       └── PersistenceManager.swift # UserDefaults 永続化
└── Resources/
    ├── Info.plist
    └── nTabula.entitlements
```

> **重要**: ソースを編集する場所は `Sources/` のみ。`nTabula/` フォルダ（Xcode 自動生成）は触らない。

## Xcode プロジェクト設定

```
Bundle ID:         jp.umi.design.nTabula
Deployment Target: macOS 14.0
Frameworks:        Carbon.framework（HotKeyService に必要）
Entitlements:      Resources/nTabula.entitlements
  - App Sandbox: ON
  - Network Client (Outgoing): ON
```

### Xcode 自動生成ファイルの削除が必要

プロジェクト作成時に `nTabula/nTabulaApp.swift`（`@main` 付き）が自動生成される。`Sources/App/nTabulaApp.swift` と `@main` が重複してビルドエラーになるため、**Xcode の Project Navigator から `nTabula/` グループ内のファイルをすべて削除**すること。

## アーキテクチャの要点

### 状態管理
- `AppState`（`@Observable @MainActor`）が Single Source of Truth
- View は `@Environment(AppState.self)` で参照、バインディングは `@Bindable var state = appState`
- `PersistenceManager.shared` が UserDefaults の読み書きをカプセル化

### エディタ
- `EditorView`（`NSViewRepresentable`）が `NSScrollView > NSTextView` をラップ
- `MarkdownTextStorage`（`NSTextStorage` サブクラス）が `processEditing()` でシンタックスハイライト
- IME 変換中（`hasMarkedText() == true`）はハイライトをスキップして日本語入力が消えるのを防ぐ
- テキスト変更 → `Coordinator`（`NSTextViewDelegate`）→ `AppState.updateContent()` → 3 秒 debounce で自動保存

### Notion API
- `NotionService` は `actor` で排他制御
- リクエストボディは `[String: Any]` → `JSONSerialization`、レスポンスは `Decodable + Sendable`（Swift 6 対応）
- ページ更新: 全ブロック削除 → 新規ブロック追加（Notion API の仕様）

### MarkdownToNotion 変換
- 入力: Markdown 文字列 / 出力: `[[String: Any]]`（Notion API `children` に直渡し）
- 対応: 見出し・箇条書き・番号付きリスト・引用・コードブロック・水平線・ToDo・インライン（bold/italic/code/strikethrough/link）

### グローバルホットキー
- Carbon `RegisterEventHotKey` で Ctrl+Shift+N を登録
- ウィンドウが前面 → 隠す、それ以外 → 前面へ

### Cmd+S フロー
`NTTextView.keyDown` → `NotificationCenter.post(.ntSaveDocument)` → `MainWindowView.onReceive` → `appState.syncActiveTab()`

### 設定ウィンドウを開く
`SettingsLink { }` を使う。`NSApp.sendAction(Selector(("showSettingsWindow:")))` は非推奨。

## Notion API メモ

```
認証:       Authorization: Bearer <token> / Notion-Version: 2022-06-28
DB 検索:    POST /v1/search  { filter: {value:"database"} }
ページ作成: POST /v1/pages   { parent.database_id, properties.Name.title, children }
タイトル更新: PATCH /v1/pages/{id}  { properties }
ブロック取得: GET  /v1/blocks/{id}/children
ブロック削除: DELETE /v1/blocks/{id}
ブロック追加: PATCH /v1/blocks/{id}/children  { children }
```

データベースのタイトルプロパティ名はデフォルト `"Name"`。
