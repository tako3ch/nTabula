# nTabula テストケース一覧（逆生成）

## テストケース概要

| ID | テスト名 | カテゴリ | 優先度 | 実装状況 | 推定工数 |
|----|---------|---------|-------|---------|---------|
| TC-001 | Markdown → paragraph ブロック変換 | 単体 | 高 | ❌ | 1h |
| TC-002 | Markdown → 見出しブロック変換 (H1/H2/H3) | 単体 | 高 | ❌ | 1h |
| TC-003 | Markdown → リストブロック変換 | 単体 | 高 | ❌ | 1h |
| TC-004 | Markdown → ToDo ブロック変換 | 単体 | 高 | ❌ | 0.5h |
| TC-005 | Markdown → コードブロック変換 (言語検出) | 単体 | 高 | ❌ | 1h |
| TC-006 | Markdown → インラインボールド変換 | 単体 | 高 | ❌ | 0.5h |
| TC-007 | Markdown → インラインコード変換 | 単体 | 高 | ❌ | 0.5h |
| TC-008 | Markdown → リンク変換 | 単体 | 高 | ❌ | 0.5h |
| TC-009 | 空文字入力での変換結果 | 単体 | 高 | ❌ | 0.5h |
| TC-010 | 複合 Markdown の変換結果 | 単体 | 高 | ❌ | 1h |
| TC-011 | TabItem Codable エンコード | 単体 | 高 | ❌ | 0.5h |
| TC-012 | TabItem Codable デコード (isDirty リセット) | 単体 | 高 | ❌ | 0.5h |
| TC-013 | TabItem titlePropertyName デフォルト値 | 単体 | 高 | ❌ | 0.5h |
| TC-014 | NotionDatabase titlePropertyName 自動抽出 | 単体 | 高 | ❌ | 1h |
| TC-015 | NotionDatabase 日本語プロパティ名抽出 | 単体 | 高 | ❌ | 0.5h |
| TC-016 | NotionPageItem displayTitle 抽出 | 単体 | 高 | ❌ | 0.5h |
| TC-017 | NotionAPIError デコード | 単体 | 高 | ❌ | 0.5h |
| TC-018 | AppState addNewTab デフォルトタイトル生成 | 単体 | 高 | ❌ | 1h |
| TC-019 | AppState addNewTab 連番生成 (同日複数) | 単体 | 高 | ❌ | 0.5h |
| TC-020 | AppState closeTab activeTab 移動 | 単体 | 高 | ❌ | 1h |
| TC-021 | AppState closeTab ピン留めタブ閉じ不可 | 単体 | 高 | ❌ | 0.5h |
| TC-022 | AppState sortedTabs ピン留め先頭 | 単体 | 高 | ❌ | 0.5h |
| TC-023 | AppState syncActiveTab isDirty=false スキップ | 単体 | 高 | ❌ | 1h |
| TC-024 | AppState syncActiveTab notionPageID=nil は実行 | 単体 | 高 | ❌ | 0.5h |
| TC-025 | AppState hasValidSaveTarget (.database) | 単体 | 中 | ❌ | 0.5h |
| TC-026 | AppState hasValidSaveTarget (.page) | 単体 | 中 | ❌ | 0.5h |
| TC-027 | PersistenceManager タブ保存・復元サイクル | 統合 | 高 | ❌ | 1h |
| TC-028 | PersistenceManager タブ復元時 isDirty=false | 統合 | 高 | ❌ | 0.5h |
| TC-029 | PersistenceManager 未設定キーのデフォルト値 | 単体 | 中 | ❌ | 1h |
| TC-030 | NotionService createPage リクエスト構造 | 統合 | 中 | ❌ | 2h |
| TC-031 | NotionService createSubPage リクエスト構造 | 統合 | 中 | ❌ | 1h |
| TC-032 | NotionService updatePageContent フロー | 統合 | 中 | ❌ | 2h |
| TC-033 | NotionService API エラーのスロー | 統合 | 中 | ❌ | 1h |
| TC-034 | NotionService fetchDatabases デコード | 統合 | 中 | ❌ | 1h |
| TC-035 | MarkdownToNotion 水平線変換 | 単体 | 中 | ❌ | 0.5h |
| TC-036 | MarkdownToNotion 引用ブロック変換 | 単体 | 中 | ❌ | 0.5h |
| TC-037 | MarkdownToNotion 番号付きリスト変換 | 単体 | 中 | ❌ | 0.5h |
| TC-038 | MarkdownToNotion イタリック変換 | 単体 | 中 | ❌ | 0.5h |
| TC-039 | MarkdownToNotion 打ち消し線変換 | 単体 | 中 | ❌ | 0.5h |
| TC-040 | MarkdownToNotion ネストリスト（非サポート確認） | 単体 | 低 | ❌ | 0.5h |
| TC-041 | TabItem derivedTitle H1記法除去 | 単体 | 低 | ❌ | 0.5h |
| TC-042 | TabItem derivedTitle 50文字上限 | 単体 | 低 | ❌ | 0.5h |
| TC-043 | AppState updateContent isDirty 設定 | 単体 | 中 | ❌ | 0.5h |
| TC-044 | AppState markSaved titlePropertyName 保存 | 単体 | 中 | ❌ | 0.5h |
| TC-045 | AppState togglePin 状態反転 | 単体 | 低 | ❌ | 0.5h |
| TC-046 | NotionListResponse hasMore/nextCursor | 単体 | 低 | ❌ | 0.5h |
| TC-047 | NotionService fetchPages デコード | 統合 | 低 | ❌ | 1h |
| TC-048 | NotionSaveTarget rawValue 永続化 | 単体 | 低 | ❌ | 0.5h |
| TC-049 | TabLayoutMode rawValue 永続化 | 単体 | 低 | ❌ | 0.5h |
| TC-050 | MarkdownToNotion 空行の扱い | 単体 | 中 | ❌ | 0.5h |
| TC-051 | MarkdownToNotion 長テキストのパフォーマンス | 単体 | 低 | ❌ | 1h |
| TC-052 | AppState syncActiveTab エラー時 syncError 設定 | 統合 | 高 | ❌ | 1h |

**推定総工数**: 約 34h

---

## 詳細テストケース

### TC-001〜TC-010: MarkdownToNotion 変換

```
対象: Sources/Utilities/MarkdownToNotion.swift
テストファイル: nTabulaTests/Utilities/MarkdownToNotionTests.swift
```

#### TC-001: paragraph ブロック変換

**テスト目的**: 通常テキストが paragraph ブロックに変換されること

**入力**: `"Hello, World!"`

**期待結果**:
```json
[{
  "object": "block",
  "type": "paragraph",
  "paragraph": {
    "rich_text": [{ "type": "text", "text": { "content": "Hello, World!" } }]
  }
}]
```

---

#### TC-002: 見出しブロック変換

**テスト目的**: `#`, `##`, `###` が heading_1/2/3 に変換されること

| 入力 | 期待 type |
|------|---------|
| `"# タイトル"` | `heading_1` |
| `"## サブタイトル"` | `heading_2` |
| `"### セクション"` | `heading_3` |
| `"#### 4階層"` | `paragraph` (非サポート) |

---

#### TC-003: リストブロック変換

| 入力 | 期待 type |
|------|---------|
| `"- アイテム"` | `bulleted_list_item` |
| `"* アイテム"` | `bulleted_list_item` |
| `"+ アイテム"` | `bulleted_list_item` |
| `"1. 番号付き"` | `numbered_list_item` |
| `"10. 大きな番号"` | `numbered_list_item` |

---

#### TC-004: ToDo ブロック変換

| 入力 | 期待 type | checked |
|------|---------|---------|
| `"- [ ] 未完了"` | `to_do` | false |
| `"- [x] 完了"` | `to_do` | true |

---

#### TC-005: コードブロック変換（言語検出）

| 入力 | 期待 language |
|------|-------------|
| `"` ``` `swift\nlet x = 1\n` ``` `"` | `"swift"` |
| `"` ``` `python\nprint()\n` ``` `"` | `"python"` |
| `"` ``` `\ncode\n` ``` `"` | `"plain text"` または `""` |

---

#### TC-009: 空文字入力

**テスト目的**: 空文字や空行のみの入力でクラッシュしないこと

| 入力 | 期待 |
|------|------|
| `""` | `[]` (空配列) |
| `"\n\n\n"` | `[]` または空段落 |

---

#### TC-010: 複合 Markdown

```markdown
# タイトル
本文テキスト

- リスト1
- リスト2

```swift
let x = 1
```

> 引用文
```

**期待**: 6ブロック (heading_1, paragraph, bulleted×2, code, quote)

---

### TC-014〜TC-017: NotionModels デコード

```
対象: Sources/Models/NotionModels.swift
テストファイル: nTabulaTests/Models/NotionModelsTests.swift
```

#### TC-014: NotionDatabase titlePropertyName 自動抽出

**テスト目的**: DB の `properties` から `type == "title"` のキー名を正しく取得すること

**入力 JSON** (英語ワークスペース):
```json
{
  "id": "test-db-id",
  "title": [{ "type": "text", "plain_text": "テストDB" }],
  "properties": {
    "Name": { "type": "title", "title": {} }
  }
}
```
**期待**: `titlePropertyName == "Name"`

---

#### TC-015: 日本語プロパティ名抽出

**入力 JSON** (日本語ワークスペース):
```json
{
  "properties": {
    "タイトル": { "type": "title", "title": {} },
    "タグ": { "type": "multi_select", "multi_select": {} }
  }
}
```
**期待**: `titlePropertyName == "タイトル"`

---

#### TC-016: titlePropertyName フォールバック

**入力 JSON** (`properties` フィールドなし):
```json
{ "id": "xxx", "title": [] }
```
**期待**: `titlePropertyName == "Name"` (デフォルト)

---

### TC-018〜TC-026: AppState ロジック

```
対象: Sources/App/AppState.swift
テストファイル: nTabulaTests/App/AppStateTests.swift
```

#### TC-018: addNewTab デフォルトタイトル生成

**テスト目的**: 新規タブのタイトルが `yyyy-MM-dd-1` 形式であること

**手順**:
1. タブが空の状態で `addNewTab()` を呼ぶ
2. `tabs.last?.title` を確認

**期待**: `"2026-03-16-1"` (実行日に依存)

---

#### TC-019: 連番生成 (同日複数)

**手順**:
1. `addNewTab()` を 3 回呼ぶ

**期待**:
- tabs[0].title: `"2026-03-16-1"`
- tabs[1].title: `"2026-03-16-2"`
- tabs[2].title: `"2026-03-16-3"`

---

#### TC-020: closeTab activeTab 移動

**手順**:
1. タブを 3 つ作成 (A, B, C)
2. activeTabID = B
3. `closeTab(B)`

**期待**:
- tabs に A, C のみ残る
- activeTabID == A (直前のタブに移動)

---

#### TC-023: syncActiveTab isDirty=false スキップ

**テスト目的**: 変更なし + 保存済みの場合、Notion API を呼ばないこと

**手順**:
1. tab.isDirty = false, tab.notionPageID = "some-id" に設定
2. `syncActiveTab()` を呼ぶ
3. API コールが発生しないことを確認

**期待**: `NotionService.updatePageContent` が呼ばれない

---

### TC-027〜TC-029: PersistenceManager

```
対象: Sources/Utilities/PersistenceManager.swift
テストファイル: nTabulaTests/Utilities/PersistenceManagerTests.swift
```

#### TC-027: タブ保存・復元サイクル

**テスト目的**: 保存したタブが完全に復元されること

**手順**:
1. タブを 3 つ作成して保存
2. 新規 PersistenceManager インスタンスから loadTabs()
3. データを比較

**期待**: id, title, content, notionPageID, titlePropertyName がすべて一致

---

#### TC-028: isDirty は常に false で復元

**テスト目的**: 保存時 isDirty=true でも、復元時は false になること

**手順**:
1. `tab.isDirty = true` の状態で保存
2. loadTabs()
3. isDirty を確認

**期待**: `isDirty == false`
