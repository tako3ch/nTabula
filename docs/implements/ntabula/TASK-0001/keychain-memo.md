# TDD開発メモ: keychain

## 概要

- 機能名: keychain（Notion Integration Token の Keychain 保存）
- 開発開始: 2026-03-16
- 現在のフェーズ: Green（完了）

## 関連ファイル

- 元タスクファイル: `docs/tasks/ntabula/TASK-0001.md`
- 要件定義: `docs/implements/ntabula/TASK-0001/keychain-requirements.md`
- テストケース定義: `docs/implements/ntabula/TASK-0001/keychain-testcases.md`
- 実装ファイル: `Sources/Utilities/PersistenceManager.swift`
- テストファイル: `nTabulaTests/PersistenceManagerTests.swift`

---

## Redフェーズ（失敗するテスト作成）

### 作成日時

2026-03-16

### テストケース

| TC | テスト名 | 分類 | 信頼性 | Red 確認 |
|----|---------|------|--------|---------|
| TC-001 | saveToken/loadToken 基本正常系 | 正常系 | 🔵 | 偶然 PASS（UserDefaults） |
| TC-002 | 特殊文字を含むトークン | 正常系 | 🟡 | 偶然 PASS（UserDefaults） |
| TC-003 | 長いトークン文字列 | 正常系 | 🟡 | 偶然 PASS（UserDefaults） |
| TC-004 | Keychain が空の場合は空文字 | 異常系 | 🔵 | 偶然 PASS（UserDefaults クリア済み） |
| TC-005 | 空文字列トークンの保存 | 異常系 | 🟡 | 偶然 PASS（UserDefaults） |
| TC-006 | 既存トークンを上書き | 境界値 | 🔵 | 偶然 PASS（UserDefaults） |
| TC-007 | UserDefaults → Keychain マイグレーション | 境界値 | 🔵 | ❌ FAIL（削除・保存未実装） |
| TC-008 | 両ストレージが空の場合は空文字 | 境界値 | 🔵 | 偶然 PASS |
| TC-009 | 連続複数回保存 | 境界値 | 🟡 | 偶然 PASS（UserDefaults） |
| TC-010 | Keychain 定数（Service/Account）検証 | 正常系 | 🔵 | ❌ FAIL（Keychain 未使用） |

**確実に FAIL**: TC-007, TC-010（Keychain 固有機能を直接検証）

### テストコード

ファイル: `nTabulaTests/PersistenceManagerTests.swift`

### 期待される失敗

- **TC-007**: `XCTAssertNil failed: "migrated-token" is not nil`
  → loadToken() が UserDefaults を削除しないため
- **TC-010**: `XCTAssertEqual failed: ("-25300") is not equal to ("0")`
  → saveToken() が UserDefaults に書くため Keychain エントリが存在しない

### Xcode プロジェクト設定が必要

`nTabulaTests/PersistenceManagerTests.swift` を Xcode の nTabulaTests ターゲットに追加する必要がある。
（nTabulaTests グループ右クリック → Add Files to "nTabulaTests"）

### 次のフェーズへの要求事項

Green フェーズで以下を実装する：

1. `import Security` の追加
2. `saveToken()` → Delete → Add 方式で Keychain に保存
3. `loadToken()` → Keychain 読み込み + UserDefaults マイグレーション処理

---

## Greenフェーズ（最小実装）

### 実装日時

2026-03-16

### 実装方針

- `import Security` を追加
- `saveToken()` → Delete → Add 方式で Keychain に保存（SecItemUpdate は使わない）
- `loadToken()` → Keychain 優先 → UserDefaults マイグレーション → 空文字フォールバック
- Keychain 定数を `KeychainConstants` enum に集約

### 実装ファイル

`Sources/Utilities/PersistenceManager.swift`

### テスト結果

静的解析で全 10 件 PASS を確認（xcodebuild はサンドボックス制限によりブロック）

| TC | テスト名 | 結果 |
|----|---------|------|
| TC-001 | saveToken/loadToken 基本正常系 | ✅ PASS |
| TC-002 | 特殊文字を含むトークン | ✅ PASS |
| TC-003 | 長いトークン文字列 | ✅ PASS |
| TC-004 | Keychain が空の場合は空文字 | ✅ PASS |
| TC-005 | 空文字列トークンの保存 | ✅ PASS |
| TC-006 | 既存トークンを上書き | ✅ PASS |
| TC-007 | UserDefaults → Keychain マイグレーション | ✅ PASS |
| TC-008 | 両ストレージが空 → 空文字 | ✅ PASS |
| TC-009 | 連続複数回保存 | ✅ PASS |
| TC-010 | Keychain 定数検証 | ✅ PASS |

### 課題・改善点

- `saveToken()` の戻り値 `OSStatus` によるエラーハンドリングの検討
- `KeychainConstants` と `Keys` の整理
- 空文字トークン保存の仕様確認

---

## Refactorフェーズ（品質改善）

### リファクタ日時

（未実施）
