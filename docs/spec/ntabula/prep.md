# nTabula 準備タスク（ユーザー作業）

> **仕様**: [requirements.md](requirements.md)
> **生成日**: 2026-03-16

**【信頼性レベル凡例】**:
- 🔵 **青信号**: 要件定義書・設計文書・ユーザヒアリングで明確に必要と判明したタスク
- 🟡 **黄信号**: 要件定義書・設計文書から妥当に推測されるタスク
- 🔴 **赤信号**: 推測による予防的タスク（実装時に不要と判明する可能性あり）

---

## 必須（実装開始前に完了が必要）

以下のタスクが完了していないと、実装フェーズでブロッカーになります。

- [ ] **Notion Integration Token の取得** 🔵 *README.md・ユーザヒアリングより*
  - https://www.notion.so/my-integrations で「新しいインテグレーション」を作成
  - 使用するデータベース/ページで「接続」→ インテグレーションを追加
  - 開発テスト用ワークスペースでの動作確認に必要
  - 関連要件: REQ-401, REQ-403

---

## 推奨（実装中に用意できればOK）

実装を開始できますが、該当機能の実装前までに準備してください。

- [ ] **macOS Keychain API の実装方針確認** 🔵 *ユーザヒアリング 2026-03-16 Keychain 移行確認*
  - `Security.framework` の `SecItemAdd` / `SecItemCopyMatching` / `SecItemUpdate` / `SecItemDelete` を使用
  - App Sandbox 環境でのキーチェーン共有設定が不要か確認（単一アプリのため `kSecAttrSynchronizable` 不要の可能性）
  - 必要になるフェーズ: Keychain 移行実装時
  - 関連要件: REQ-403, NFR-101

- [ ] **Xcode テストターゲット `nTabulaTests` の追加** 🔵 *ユーザヒアリング 2026-03-16 Unit Test 実装確認*
  - Xcode → File → New → Target → Unit Testing Bundle
  - Bundle ID: `jp.umi.design.nTabula.Tests`
  - Host App: `nTabula`
  - `docs/spec/ntabula/tests/*.swift` を `nTabulaTests/` グループに追加
  - 必要になるフェーズ: Unit Test 実装時
  - 関連要件: NFR-303

---

## 確認事項（判断が必要）

実装方針に影響するため、早めの判断・確認が推奨されます。

- [ ] **既存ユーザーの Token 移行方法の確認** 🟡 *Keychain 移行要件から推測*
  - 既に UserDefaults にトークンが保存されているユーザーへの移行戦略
  - 選択肢: (A) アプリ起動時に自動移行 / (B) 再入力を求める / (C) 両方を一定期間サポート
  - 関連要件: REQ-403

- [ ] **`TabItem.databaseID` フィールドの使用方針** 🟡 *コード分析（未使用フィールドの発見）から推測*
  - 現状: `TabItem.databaseID` が定義されているが AppState では `selectedDatabaseID` を参照しており未使用
  - 選択肢: (A) フィールドを削除 / (B) タブ単位の保存先として将来的に活用
  - 関連要件: REQ-005

---

## サマリー

| 優先度 | 件数 | 🔵 | 🟡 | 🔴 |
|--------|------|-----|-----|-----|
| 必須 | 1 | 1 | 0 | 0 |
| 推奨 | 2 | 2 | 0 | 0 |
| 確認事項 | 2 | 0 | 2 | 0 |

---

## 関連文書

- **要件定義書**: [requirements.md](requirements.md)
- **ヒアリング記録**: [interview-record.md](interview-record.md)
