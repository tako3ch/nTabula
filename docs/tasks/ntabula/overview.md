# nTabula タスク概要

**作成日**: 2026-03-16
**プロジェクト期間**: 2026-03-17 - 2026-03-27（10日）
**推定工数**: 74時間
**総タスク数**: 11件

## 関連文書

- **要件定義書**: [📋 requirements.md](../spec/ntabula/requirements.md)
- **設計文書**: [📐 architecture.md](../design/ntabula/architecture.md)
- **データフロー図**: [🔄 dataflow.md](../design/ntabula/dataflow.md)
- **型定義**: [📝 interfaces.swift](../design/ntabula/interfaces.swift)
- **永続化スキーマ**: [🗄️ persistence-schema.md](../design/ntabula/persistence-schema.md)
- **コンテキストノート**: [📝 note.md](../spec/ntabula/note.md)

## フェーズ構成

| フェーズ | 期間 | 成果物 | タスク数 | 工数 |
|---------|------|--------|----------|------|
| Phase 1 - 基盤・データアクセス層 | Day 1-3 | Keychain実装・moveTab | 3件 | 24h |
| Phase 2 - サービス層依存注入 | Day 4-4 | URLSession/UserDefaults注入 | 2件 | 8h |
| Phase 3 - UI層実装 | Day 5-7 | Cmd+W・TabD&D | 3件 | 20h |
| Phase 4 - テスト基盤 | Day 8-10 | XCTest・MockURLProtocol | 3件 | 22h |

## タスク番号管理

**使用済みタスク番号**: TASK-0001 〜 TASK-0011
**次回開始番号**: TASK-0012

## 全体進捗

- [ ] Phase 1: 基盤・データアクセス層
- [ ] Phase 2: サービス層依存注入
- [ ] Phase 3: UI層実装
- [ ] Phase 4: テスト基盤

## マイルストーン

- **M1: データアクセス層完成** (Day 3): Keychain実装・マイグレーション・moveTab完了
- **M2: 依存注入完成** (Day 4): URLSession/UserDefaults注入、全サービスがテスト可能に
- **M3: UI完成** (Day 7): Cmd+W・タブD&D（横縦両対応）完了
- **M4: テスト完成** (Day 10): Unit Test基盤・NotionService・PersistenceManagerテスト完了

---

## Phase 1: 基盤・データアクセス層

**期間**: Day 1-3
**目標**: Keychain によるトークン管理・起動時マイグレーション・タブ並び替えの基盤実装
**成果物**: Keychain API・AppState マイグレーション・AppState.moveTab()

### タスク一覧

- [ ] [TASK-0001: PersistenceManager Keychain メソッド実装](TASK-0001.md) - 8h (TDD) 🔵
- [ ] [TASK-0002: AppState 起動時マイグレーション + Keychain 統合](TASK-0002.md) - 8h (TDD) 🔵
- [ ] [TASK-0003: AppState.moveTab() 実装](TASK-0003.md) - 8h (TDD) 🔵

### 依存関係

```
TASK-0001 → TASK-0002
TASK-0003（独立）
```

---

## Phase 2: サービス層依存注入

**期間**: Day 4
**目標**: テスト可能な依存注入アーキテクチャの確立
**成果物**: NotionService URLSession注入・PersistenceManager UserDefaults注入

### タスク一覧

- [ ] [TASK-0004: NotionService URLSession 注入対応](TASK-0004.md) - 4h (DIRECT) 🔵
- [ ] [TASK-0005: PersistenceManager UserDefaults 注入対応](TASK-0005.md) - 4h (DIRECT) 🔵

### 依存関係

```
TASK-0002 → TASK-0004
TASK-0001 → TASK-0005
```

---

## Phase 3: UI層実装

**期間**: Day 5-7
**目標**: ユーザー向け新機能（Cmd+W・タブD&D）の完成
**成果物**: Cmd+W キーバインド・TabBarView D&D・VerticalSidebarView D&D

### タスク一覧

- [ ] [TASK-0006: Cmd+W キーバインド実装](TASK-0006.md) - 4h (DIRECT) 🔵
- [ ] [TASK-0007: TabBarView タブ D&D 実装](TASK-0007.md) - 8h (TDD) 🔵
- [ ] [TASK-0008: VerticalSidebarView タブ D&D 実装](TASK-0008.md) - 8h (TDD) 🔵

### 依存関係

```
TASK-0003 → TASK-0007
TASK-0003 → TASK-0008
TASK-0006（独立）
```

---

## Phase 4: テスト基盤

**期間**: Day 8-10
**目標**: Unit Test インフラ構築と主要コンポーネントのテスト完成
**成果物**: nTabulaTests ターゲット・MockURLProtocol・PersistenceManager/NotionServiceテスト

### タスク一覧

- [ ] [TASK-0009: nTabulaTests ターゲット + MockURLProtocol 作成](TASK-0009.md) - 6h (DIRECT) 🔵
- [ ] [TASK-0010: PersistenceManager コアロジック テスト実装](TASK-0010.md) - 8h (TDD) 🔵
- [ ] [TASK-0011: NotionService コアロジック テスト実装](TASK-0011.md) - 8h (TDD) 🔵

### 依存関係

```
TASK-0009 → TASK-0010
TASK-0009 → TASK-0011
TASK-0005 → TASK-0010
TASK-0004 → TASK-0011
```

---

## 信頼性レベルサマリー

### 全タスク統計

- **総タスク数**: 11件
- 🔵 **青信号**: 11件 (100%)
- 🟡 **黄信号**: 0件 (0%)
- 🔴 **赤信号**: 0件 (0%)

### フェーズ別信頼性

| フェーズ | 🔵 青 | 🟡 黄 | 🔴 赤 | 合計 |
|---------|-------|-------|-------|------|
| Phase 1 | 3 | 0 | 0 | 3 |
| Phase 2 | 2 | 0 | 0 | 2 |
| Phase 3 | 3 | 0 | 0 | 3 |
| Phase 4 | 3 | 0 | 0 | 3 |

**品質評価**: ✅ 高品質

## クリティカルパス

```
TASK-0001 → TASK-0002 → TASK-0004 → TASK-0011
TASK-0001 → TASK-0005 → TASK-0010
TASK-0003 → TASK-0007
TASK-0009 → TASK-0010
TASK-0009 → TASK-0011
```

**クリティカルパス工数**: 30時間（TASK-0001→0002→0004→0009→0011）
**並行作業可能工数**: 44時間

## 次のステップ

タスクを実装するには:
- 全タスク順番に実装: `/tsumiki:kairo-implement`
- 特定タスクを実装: `/tsumiki:kairo-implement TASK-0001`
