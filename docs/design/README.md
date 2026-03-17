# nTabula 技術設計書 インデックス

**分析日時**: 2026-03-16
**対象**: macOS メモアプリ nTabula (Swift 6 / SwiftUI + Notion API)

---

## ドキュメント一覧

| ファイル | 内容 |
|---------|------|
| [architecture.md](./ntabula/architecture.md) | アーキテクチャ概要、レイヤー構成、デザインパターン |
| [dataflow.md](./ntabula/dataflow.md) | ユーザー操作・Notion 保存・タブ切り替えのシーケンス図 |
| [api-specs.md](./ntabula/api-specs.md) | Notion REST API 仕様（使用エンドポイント・ブロック形式） |
| [persistence-schema.md](./ntabula/persistence-schema.md) | UserDefaults スキーマ・TabItem JSON 構造・保存タイミング |
| [interfaces.swift](./ntabula/interfaces.swift) | Swift 型定義集約（モデル・サービス・状態管理） |

---

## アーキテクチャ概要

```
┌──────────────────────────────────────────────────────┐
│                    nTabula macOS App                 │
│                                                      │
│  ┌─────────────┐    ┌──────────────────────────────┐│
│  │  SwiftUI    │    │         AppState             ││
│  │  Views      │◄───│  @Observable @MainActor      ││
│  │             │───►│  (Single Source of Truth)    ││
│  └─────────────┘    └──────────┬───────────────────┘│
│         │                      │                     │
│  ┌──────▼──────┐     ┌─────────▼──────────────────┐ │
│  │  NSTextView │     │       Services              │ │
│  │  (AppKit)   │     │  NotionService (actor)      │ │
│  └─────────────┘     │  HotKeyService (Carbon)     │ │
│                      └─────────┬──────────────────-┘ │
│  ┌──────────────┐    ┌─────────▼──────────────────┐  │
│  │ Persistence  │    │     Notion REST API         │  │
│  │ UserDefaults │    │  api.notion.com/v1          │  │
│  └──────────────┘    └────────────────────────────-┘  │
└──────────────────────────────────────────────────────┘
```

## 技術スタック

| 項目 | 詳細 |
|------|------|
| 言語 | Swift 6 |
| UI フレームワーク | SwiftUI (macOS 14+) + AppKit (NSTextView) |
| 状態管理 | @Observable マクロ |
| 非同期 | Swift Concurrency (async/await, actor) |
| 外部通信 | URLSession + Notion REST API |
| 永続化 | UserDefaults |
| ビルド | Xcode |
| 外部依存 | なし |
