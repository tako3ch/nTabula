# Notion API 仕様書（逆生成）

## 分析日時
2026-03-16

---

## ベース URL
```
https://api.notion.com/v1
```

## 認証方式
```
Authorization: Bearer <Integration Token>
Notion-Version: 2022-06-28
Content-Type: application/json
```

Integration Token は Settings > Notion タブで設定。UserDefaults に平文保存。

---

## 使用エンドポイント一覧

### 1. データベース・ページ一覧取得

#### POST /search （データベース一覧）
**用途**: Integration に共有されているデータベース一覧を取得

**リクエスト**:
```json
{
  "filter": { "value": "database", "property": "object" },
  "page_size": 100
}
```

**レスポンス** (主要フィールド):
```json
{
  "object": "list",
  "results": [
    {
      "object": "database",
      "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "title": [{ "type": "text", "plain_text": "DB名" }],
      "properties": {
        "Name": { "id": "title", "type": "title", "title": {} }
      }
    }
  ],
  "has_more": false,
  "next_cursor": null
}
```

**Swift 型**: `NotionListResponse<NotionDatabase>`

---

#### POST /search （ページ一覧）
**用途**: Integration に共有されているページ一覧を取得（親ページ選択用）

**リクエスト**:
```json
{
  "filter": { "value": "page", "property": "object" },
  "page_size": 100
}
```

**Swift 型**: `NotionListResponse<NotionPageItem>`

---

### 2. ページ操作

#### POST /pages （DB への新規ページ作成）
**用途**: 選択したデータベースの直下にページを新規作成

**リクエスト**:
```json
{
  "parent": { "database_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" },
  "properties": {
    "<titlePropertyName>": {
      "title": [{ "text": { "content": "ページタイトル" } }]
    }
  },
  "children": [ /* Notion ブロック配列 */ ]
}
```

> `titlePropertyName` はデータベースの `type == "title"` プロパティ名（例: "Name", "タイトル"）を動的解決

**Swift 型**: `NotionPage`

---

#### POST /pages （子ページ作成）
**用途**: 選択した親ページの子として新規ページを作成

**リクエスト**:
```json
{
  "parent": { "page_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" },
  "properties": {
    "title": {
      "title": [{ "text": { "content": "ページタイトル" } }]
    }
  },
  "children": [ /* Notion ブロック配列 */ ]
}
```

**Swift 型**: `NotionPage`

---

#### PATCH /pages/{page_id} （タイトル更新）
**用途**: 既存ページのタイトルを更新

**リクエスト**:
```json
{
  "properties": {
    "<titlePropertyName>": {
      "title": [{ "text": { "content": "新しいタイトル" } }]
    }
  }
}
```

**Swift 型**: `NotionPage`

---

### 3. ブロック操作

#### GET /blocks/{block_id}/children
**用途**: ページの既存ブロック一覧を取得（更新前の全削除用）

**レスポンス**:
```json
{
  "object": "list",
  "results": [
    { "object": "block", "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" }
  ]
}
```

**Swift 型**: `NotionBlockChildrenResponse`

---

#### DELETE /blocks/{block_id}
**用途**: ブロックを削除（ページ更新時に全ブロック削除）

**レスポンス**: `{}` (空オブジェクト)

**Swift 型**: `IgnoredResponse`

---

#### PATCH /blocks/{block_id}/children
**用途**: ページに新規ブロックを追加

**リクエスト**:
```json
{
  "children": [ /* Notion ブロック配列 */ ]
}
```

**Swift 型**: `IgnoredResponse`

---

## Notion ブロック形式（MarkdownToNotion 出力）

### paragraph
```json
{
  "object": "block",
  "type": "paragraph",
  "paragraph": {
    "rich_text": [ /* rich_text 配列 */ ]
  }
}
```

### heading_1 / heading_2 / heading_3
```json
{
  "type": "heading_1",
  "heading_1": { "rich_text": [...] }
}
```

### bulleted_list_item
```json
{
  "type": "bulleted_list_item",
  "bulleted_list_item": { "rich_text": [...] }
}
```

### numbered_list_item
```json
{
  "type": "numbered_list_item",
  "numbered_list_item": { "rich_text": [...] }
}
```

### to_do
```json
{
  "type": "to_do",
  "to_do": { "rich_text": [...], "checked": false }
}
```

### quote
```json
{
  "type": "quote",
  "quote": { "rich_text": [...] }
}
```

### code
```json
{
  "type": "code",
  "code": { "rich_text": [...], "language": "swift" }
}
```

### divider
```json
{ "type": "divider", "divider": {} }
```

### Rich Text オブジェクト
```json
{
  "type": "text",
  "text": {
    "content": "テキスト",
    "link": null
  },
  "annotations": {
    "bold": false,
    "italic": false,
    "code": false,
    "strikethrough": false,
    "underline": false,
    "color": "default"
  }
}
```

---

## エラーレスポンス

```json
{
  "object": "error",
  "status": 400,
  "code": "validation_error",
  "message": "Name is not a property that exists."
}
```

**Swift 型**: `NotionAPIError` (Decodable, LocalizedError)

### 主要エラーコード

| code | 説明 | 対処 |
|------|------|------|
| `validation_error` | プロパティ名が存在しない | titlePropertyName を確認（DB のタイトルプロパティ名） |
| `unauthorized` | Token が無効 | Settings で Token を再設定 |
| `object_not_found` | ページ/DB が見つからない | notionPageID を null にして再作成 |
| `rate_limited` | レート制限 | 自動リトライなし（未実装） |
