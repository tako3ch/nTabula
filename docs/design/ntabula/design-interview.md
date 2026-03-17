# nTabula 設計ヒアリング記録

**作成日**: 2026-03-16
**ヒアリング実施**: kairo-design step4 既存情報ベースの差分ヒアリング

## ヒアリング目的

既存の要件定義書（kairo-requirements で更新済み）・設計文書（rev-design 逆生成）・実装コードを確認し、新規要件（Keychain 移行・Cmd+W・タブ D&D・Unit Test 基盤）の技術設計方針を明確化するためのヒアリングを実施しました。

---

## 質問と回答

### Q1: 既存コードの詳細分析の要否

**質問日時**: 2026-03-16
**カテゴリ**: 既存設計確認
**背景**: kairo-requirements ステップで既に Sources/ 以下の差分分析が完了している。追加走査が必要か確認するため。

**回答**: 不要（推奨）

**信頼性への影響**:
- kairo-requirements でのコード分析結果（UserDefaults 平文保存・Cmd+W 未実装・ページネーション未使用・テスト注入未実装）を設計に引き継ぐ
- 追加の走査なしで設計文書を作成する

---

### Q2: Keychain トークン保管の実装アプローチ

**質問日時**: 2026-03-16
**カテゴリ**: 技術選択
**背景**: REQ-403・NFR-101 で Keychain 移行が確定要件。実装方法（Security.framework 直接 vs ラッパークラス）を確認するため。

**回答**: Security.framework 直接（`SecItemAdd` / `SecItemCopyMatching` / `SecItemUpdate` / `SecItemDelete` を `PersistenceManager` 内に実装）

**確認された設計方針**:
```
kSecClass        = kSecClassGenericPassword
kSecAttrService  = "jp.umi.design.nTabula"
kSecAttrAccount  = "NotionToken"
kSecValueData    = token.data(using: .utf8)
```

**信頼性への影響**:
- NFR-101 の実装方針が 🟡（推測） → 🔵 に向上
- `PersistenceManager` に Keychain メソッドを追加する設計が確定

---

### Q3: 既存 UserDefaults トークンの移行戦略

**質問日時**: 2026-03-16
**カテゴリ**: 既存設計確認
**背景**: 既に UserDefaults にトークンを保存しているユーザーへの対応。自動移行・再入力・両方サポートの 3 択。

**回答**: 起動時自動移行（推奨）

**確認された設計方針**:
1. アプリ起動時に `PersistenceManager.loadToken()` が Keychain を試行
2. Keychain にない場合のみ UserDefaults `"nTabula.notionToken"` を読む
3. UserDefaults にトークンがある場合: Keychain に保存 → UserDefaults から削除

**信頼性への影響**:
- REQ-403 の移行実装方針が 🟡（推測）→ 🔵 に向上
- prep.md の「既存ユーザーの Token 移行方法の確認」タスクが解決済み

---

### Q4: タブ D&D 並び替えの実装アプローチ

**質問日時**: 2026-03-16
**カテゴリ**: 技術選択
**背景**: REQ-305 でタブ D&D が確定要件。SwiftUI ネイティブ API（macOS 14+）vs AppKit ベースの実装を確認するため。

**回答**: SwiftUI `.draggable` / `.dropDestination`（推奨）

**確認された設計方針**:
- macOS 14+ のネイティブ SwiftUI D&D API を使用
- `TabBarView`（横）と `VerticalSidebarView`（縦）の両方で統一実装
- `AppState.moveTab(fromOffsets:toOffset:)` メソッドを追加
- ピン留めタブとの境界（ピン ↔ 非ピン間の移動禁止）はアプリ側でチェック

**信頼性への影響**:
- REQ-305 の実装方針が 🟡（推測）→ 🔵 に向上

---

## ヒアリング結果サマリー

### 確認できた事項
- Keychain 実装: Security.framework 直接（外部ライブラリなし）
- トークン移行: 起動時自動移行（ユーザー操作不要）
- タブ D&D: SwiftUI `.draggable/.dropDestination`（macOS 14+ ネイティブ）
- 既存コード分析: 不要（kairo-requirements で完了済み）

### 設計方針の決定事項
1. `PersistenceManager` に Keychain アクセスメソッドを追加（外部依存なし）
2. `AppState.init()` に起動時マイグレーションロジックを追加
3. `nTabulaApp.swift` の Commands ブロックに Cmd+W を追加
4. `TabBarView` / `VerticalSidebarView` に `.draggable/.dropDestination` を追加
5. `NotionService` に `init(token:session:)` overload を追加（URLSession 注入）
6. `PersistenceManager` に `init(defaults:)` overload を追加（UserDefaults 注入）

### 残課題
- `TabItem.databaseID` フィールドの使用方針（prep.md に記載。現状未使用）
- ダーク/ライトモードの明示的なテスト方法（自動追従で OK か）

### 信頼性レベル分布

**ヒアリング前（rev-design 逆生成時）**:
- 🔵 青信号: 20件
- 🟡 黄信号: 8件
- 🔴 赤信号: 0件

**ヒアリング後（kairo-design 更新後）**:
- 🔵 青信号: 29件 (+9)
- 🟡 黄信号: 1件 (-7)
- 🔴 赤信号: 0件

---

## 関連文書

- **アーキテクチャ設計**: [architecture.md](architecture.md)
- **データフロー**: [dataflow.md](dataflow.md)
- **型定義**: [interfaces.swift](interfaces.swift)
- **永続化スキーマ**: [persistence-schema.md](persistence-schema.md)
- **要件定義**: [requirements.md](../../spec/ntabula/requirements.md)
- **ヒアリング記録（要件定義）**: [interview-record.md](../../spec/ntabula/interview-record.md)
