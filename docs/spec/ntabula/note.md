# nTabula コンテキストノート

**生成日**: 2026-03-16
**用途**: kairo-requirements / kairo-design / kairo-tasks の参照用ノート

---

## プロジェクト概要

**nTabula** — Notion にマークダウンを保存できる macOS メモアプリ（umi.design 自社プロジェクト）

- ローカル下書きを素早く作成し、好きなタイミングで Notion に同期するワークフロー
- ヘビー Notion ユーザー向けのネイティブ軽量エディタ

---

## 技術スタック

| 項目 | 内容 |
|------|------|
| 言語 | Swift 6 |
| UI フレームワーク | SwiftUI (macOS 14.0+) + AppKit (NSViewRepresentable) |
| 状態管理 | @Observable @MainActor (AppState) |
| 外部通信 | URLSession + Notion REST API (v2022-06-28) |
| 永続化 | UserDefaults (PersistenceManager シングルトン) |
| ホットキー | Carbon API (RegisterEventHotKey) |
| テスト | XCTest（ターゲット未追加） |
| ビルド | Xcode 15 / Swift Package Manager |
| 最小 OS | macOS 14.0 (Sonoma) |

---

## ディレクトリ構成

```
Sources/
├── App/            AppState.swift, AppDelegate.swift, nTabulaApp.swift
├── Models/         TabItem.swift, NotionModels.swift
├── Services/       NotionService.swift, HotKeyService.swift
├── Views/          MainWindowView.swift, EditorView.swift,
│                   TabBarView.swift, VerticalSidebarView.swift, SettingsView.swift
└── Utilities/      MarkdownToNotion.swift, PersistenceManager.swift

Resources/          Info.plist, nTabula.entitlements
docs/
├── design/ntabula/ architecture.md, dataflow.md, api-specs.md, persistence-schema.md
├── spec/ntabula/   requirements.md, user-stories.md, acceptance-criteria.md,
│                   test-specs.md, test-cases.md, tests/*.swift
└── tasks/          rev-tasks で生成したタスク一覧（機能別 overview.md）
```

---

## アーキテクチャ要点

- **MVVM-like 単方向データフロー**: AppState (ViewModel) → View（読み取り専用）
- **Single Source of Truth**: AppState がすべての状態を保持
- **Actor 排他制御**: NotionService は actor で並行アクセスを保護
- **Coordinator パターン**: EditorView.Coordinator が NSTextViewDelegate を実装
- **NotificationCenter**: Cmd+S イベントを View をまたいで伝達

---

## 開発ルール

- ソースコードの編集は `Sources/` のみ（`nTabula/` フォルダは Xcode 自動生成、触らない）
- コミットは明示的に依頼されたときのみ
- コードコメントは日本語
- コミットメッセージは日本語

---

## 主要な制約・制限

| 制約 | 内容 |
|-----|------|
| Notion API ページネーション | page_size: 100 固定、100件超は取得不可 |
| ブロック更新方式 | 全ブロック削除 → 再追加（差分更新なし） |
| Markdown サポート範囲 | H1-H3、引用、箇条書き・番号付きリスト、コードブロック、ToDo、インライン (bold/italic/code/strikethrough/link) |
| H4以下の見出し | paragraph にフォールバック |
| テーブル記法 | 未サポート |
| 画像・添付ファイル | 未サポート |
| トークン保存 | UserDefaults（Keychain 未使用） |

---

## 実装状態サマリー（rev-tasks 分析より）

| 機能 | 実装状態 |
|-----|---------|
| タブ管理（CRUD・ピン留め・レイアウト） | ✅ 実装済み |
| マークダウンエディタ + シンタックスHL | ✅ 実装済み |
| リスト継続入力 | ✅ 実装済み |
| IME 対応 | ✅ 実装済み |
| Notion API 連携（作成・更新） | ✅ 実装済み |
| 自動保存 (3秒 debounce) | ✅ 実装済み |
| グローバルホットキー Ctrl+Shift+N | ✅ 実装済み |
| UserDefaults 永続化 | ✅ 実装済み |
| Markdown→Notion ブロック変換 | ✅ 実装済み |
| フォント設定 | ✅ 実装済み |
| Xcode テストターゲット | ❌ 未追加 |
| URLSession 注入 (テスト可能化) | ❌ 未実装 |

---

## 関連設計文書

- `docs/design/ntabula/architecture.md` — アーキテクチャ設計
- `docs/design/ntabula/dataflow.md` — データフロー図
- `docs/design/ntabula/api-specs.md` — Notion API 仕様
- `docs/design/ntabula/persistence-schema.md` — UserDefaults スキーマ
- `docs/spec/ntabula/requirements.md` — EARS 機能要件（rev-requirements 生成）
- `docs/spec/ntabula/user-stories.md` — ユーザーストーリー
- `docs/spec/ntabula/acceptance-criteria.md` — 受け入れ基準
- `docs/spec/ntabula/test-specs.md` — テスト仕様書
- `docs/spec/ntabula/test-cases.md` — テストケース一覧
