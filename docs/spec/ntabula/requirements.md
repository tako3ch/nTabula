# nTabula 要件定義書

**作成日**: 2026-03-16
**更新日**: 2026-03-16（kairo-requirements によるヒアリング反映）

## 概要

nTabula は Notion にマークダウンを保存できる macOS ネイティブメモアプリ。ローカルで素早くメモし、好きなタイミングで Notion へ同期するワークフローを実現する。ヘビー Notion ユーザー・軽量エディタを求めるユーザーの両方を対象とする。

## 関連文書

- **ヒアリング記録**: [💬 interview-record.md](interview-record.md)
- **ユーザストーリー**: [📖 user-stories.md](user-stories.md)
- **受け入れ基準**: [✅ acceptance-criteria.md](acceptance-criteria.md)
- **コンテキストノート**: [📝 note.md](note.md)
- **準備タスク**: [🔧 prep.md](prep.md)
- **テスト仕様**: [🧪 test-specs.md](test-specs.md)
- **テストケース**: [📋 test-cases.md](test-cases.md)

---

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 **青信号**: 実装コード・設計文書・ユーザヒアリングを参考にした確実な要件
- 🟡 **黄信号**: 実装コード・設計文書から妥当な推測による要件
- 🔴 **赤信号**: 実装・設計文書にない推測による要件

---

### 通常要件

- REQ-001: システムはマークダウンテキストをタブ単位で管理しなければならない 🔵 *AppState.swift L91-141より*
- REQ-002: システムは `AppState` を Single Source of Truth として状態を一元管理しなければならない 🔵 *architecture.md・AppState.swiftより*
- REQ-003: システムはマークダウンのシンタックスハイライトをリアルタイムで表示しなければならない 🔵 *EditorView.swift L263-319より*
- REQ-004: システムはマークダウンを Notion API の children ブロック配列に変換しなければならない 🔵 *MarkdownToNotion.swift・CLAUDE.mdより*
- REQ-005: システムはタブ一覧・設定・トークンを永続化しなければならない 🔵 *PersistenceManager.swiftより*

### 条件付き要件

- REQ-101: `Ctrl+Shift+N` が押された場合、システムはウィンドウを最前面に表示しなければならない 🔵 *HotKeyService.swift・README.mdより*
- REQ-102: ウィンドウがすでにアクティブな場合、`Ctrl+Shift+N` でウィンドウを隠さなければならない 🔵 *AppDelegate.swiftより*
- REQ-103: `Cmd+S` が押された場合、システムはアクティブタブを Notion に同期しなければならない 🔵 *nTabulaApp.swift L42-48・CLAUDE.mdより*
- REQ-104: `Cmd+T` が押された場合、システムは新規タブを追加しなければならない 🔵 *nTabulaApp.swift L35-40・README.mdより*
- REQ-105: `Cmd+W` が押された場合、システムはアクティブタブを閉じなければならない 🔵 *ユーザヒアリング 2026-03-16 確認*
- REQ-106: `isDirty == false && notionPageID != nil` の場合、システムは Notion への API コールをスキップしなければならない 🔵 *AppState.swift syncActiveTab()より*
- REQ-107: タイトルが設定されていない場合、システムはコンテンツ先頭行から `derivedTitle` を生成しなければならない 🔵 *TabItem.swiftより*
- REQ-108: ピン留めタブを閉じようとした場合、システムはタブを削除してはならない 🔵 *AppState.swift closeTab()より*
- REQ-109: データベース未選択の場合、システムは syncError を設定し同期をスキップしなければならない 🔵 *AppState.swift syncActiveTab()より*
- REQ-110: ページ保存先未選択の場合、システムは syncError を設定し同期をスキップしなければならない 🔵 *AppState.swift syncActiveTab()より*
- REQ-111: 初回同期（notionPageID == nil）の場合、システムは必ず API を呼び出しページを作成しなければならない 🔵 *AppState.swift syncActiveTab()より*
- REQ-112: 2回目以降の同期（notionPageID != nil && isDirty == true）の場合、システムは既存ページを更新しなければならない 🔵 *AppState.swift syncActiveTab()より*
- REQ-113: IME 変換中（hasMarkedText() == true）の場合、システムはシンタックスハイライトの再計算をスキップしなければならない 🔵 *EditorView.swift L229-230より*

### 状態要件

- REQ-201: 同期中（isSyncing == true）の状態にある場合、システムは保存ボタンを無効化しなければならない 🔵 *MainWindowView.swift ステータスバーより*
- REQ-202: タブが選択されている状態にある場合、システムはそのタブのコンテンツをエディタに表示しなければならない 🔵 *EditorView.swift updateNSView()より*
- REQ-203: ピン留め状態にある場合、タブはソート後に先頭に表示されなければならない 🔵 *AppState.sortedTabsより*

### オプション要件

- REQ-301: システムは入力停止後 3 秒で自動的にローカル状態を保存してもよい 🔵 *EditorView.swift L114-123より*
- REQ-302: システムはタブレイアウトを横タブ / 縦サイドバーで切り替えられてもよい 🔵 *AppState.tabLayoutMode・MainWindowView.swiftより*
- REQ-303: システムはエディタのフォント種類とサイズをカスタマイズできてもよい 🔵 *SettingsView.swift L19-36より*
- REQ-304: システムはタブをピン留めして一覧の先頭に固定できてもよい 🔵 *AppState.togglePin()より*
- REQ-305: システムはタブをドラッグ&ドロップで並び替えられてもよい 🔵 *ユーザヒアリング 2026-03-16 優先機能として確認*

### 制約要件

- REQ-401: システムは Notion API バージョン `2022-06-28` を使用しなければならない 🔵 *CLAUDE.md・NotionService.swiftより*
- REQ-402: システムは App Sandbox ON・Network Client (Outgoing) のみ許可しなければならない 🔵 *CLAUDE.md・nTabula.entitlementsより*
- REQ-403: システムはトークンを macOS Keychain に保存しなければならない 🔵 *ユーザヒアリング 2026-03-16 確認*
- REQ-404: システムは Notion API の page_size を 100 で固定し、ページネーション UI は実装してはならない 🔵 *ユーザヒアリング 2026-03-16 確認*
- REQ-405: MarkdownToNotion は H4 以降の見出しを `paragraph` ブロックに変換しなければならない 🔵 *MarkdownToNotion.swiftより*
- REQ-406: ページ更新は全ブロック削除 → 再追加の方式で行わなければならない 🔵 *NotionService.swift・CLAUDE.mdより*
- REQ-407: システムはデータベースのタイトルプロパティ名を動的に解決しなければならない（日本語プロパティ名対応） 🔵 *NotionModels.swift titlePropertyNameより*
- REQ-408: システムはウィンドウサイズ・位置を記憶しなければならない 🔵 *AppDelegate.swift L34-36, L57-65より*

---

## 非機能要件

### パフォーマンス

- NFR-001: シンタックスハイライトは変更された段落範囲のみ再計算しなければならない 🔵 *EditorView.swift paragraphRangeより*
- NFR-002: タブ切り替え時はタブID変化時のみ `textView.string` を更新しなければならない 🔵 *EditorView.swift updateNSView()より*
- NFR-003: Notion 同期は isDirty == false && notionPageID != nil の場合スキップしなければならない 🔵 *AppState.swift syncActiveTab()より*

### セキュリティ

- NFR-101: Notion Integration Token は macOS Keychain に保存しなければならない 🔵 *ユーザヒアリング 2026-03-16 確認*
- NFR-102: Notion API 通信は HTTPS（App Sandbox 必須）で行わなければならない 🔵 *nTabula.entitlementsより*
- NFR-103: Token は SecureField で入力されなければならない 🔵 *SettingsView.swiftより*

### 可用性・信頼性

- NFR-201: 同期エラー（syncError）はステータスバーに赤文字で即座に表示されなければならない 🔵 *MainWindowView.swift L72-109より*
- NFR-202: アプリ終了・再起動後もタブ一覧・設定が復元されなければならない 🔵 *PersistenceManager.swift・AppState.initより*

### 保守性・テスト可能性

- NFR-301: NotionService は URLSession を注入可能な設計にしなければならない（`init(token:session:)` overload） 🔵 *ユーザヒアリング 2026-03-16 Unit Test 実装確認*
- NFR-302: PersistenceManager は UserDefaults を注入可能な設計にしなければならない 🔵 *ユーザヒアリング 2026-03-16 Unit Test 実装確認*
- NFR-303: Xcode に `nTabulaTests` テストターゲットを追加しなければならない 🔵 *ユーザヒアリング 2026-03-16 Unit Test 実装確認*

### ユーザビリティ

- NFR-401: アプリは macOS ダーク / ライトモードに自動追従しなければならない 🟡 *システムカラー使用から推測（明示実装なし）*
- NFR-402: タブのデフォルトタイトルは `yyyy-MM-dd-N` 形式でなければならない 🔵 *AppState.addNewTab()より*
- NFR-403: エディタのマークダウンリスト継続に対応しなければならない 🔵 *EditorView.swift handleListContinuation()より*

---

## Edgeケース

### エラー処理

- EDGE-001: Notion API がエラーレスポンスを返した場合、`NotionAPIError` をデコードして `syncError` に設定しなければならない 🔵 *NotionService.swiftより*
- EDGE-002: 全タブを閉じた場合、`activeTabID` が nil になりエディタは空表示しなければならない 🔵 *AppState.closeTab()より*
- EDGE-003: アクティブタブを閉じた場合、直前のタブ（存在しない場合は次のタブ）をアクティブにしなければならない 🔵 *AppState.closeTab()より*

### 境界値

- EDGE-101: 同日に複数タブを追加した場合、`yyyy-MM-dd-N` の N は当日分の連番でインクリメントされなければならない 🔵 *AppState.addNewTab()より*
- EDGE-102: コンテンツが空のタブの `derivedTitle` は `"新規ノート"` を返さなければならない 🔵 *TabItem.derivedTitleより*
- EDGE-103: `derivedTitle` は先頭の非空行を最大50文字で切り捨てなければならない 🔵 *TabItem.derivedTitleより*
- EDGE-104: フォントサイズが 0 以下の場合、14pt にフォールバックしなければならない 🔵 *PersistenceManager.loadFontSize()より*
- EDGE-105: タイトルプロパティが空の Notion データベースの場合、`"Name"` にフォールバックしなければならない 🔵 *NotionModels.titlePropertyNameより*
