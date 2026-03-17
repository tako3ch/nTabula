# Keychain メソッド実装 テストケース定義

**機能名**: keychain
**タスクID**: TASK-0001
**要件名**: ntabula
**作成日**: 2026-03-16
**テストフレームワーク**: XCTest（Swift 6、macOS 14.0+）
**テストファイル**: `nTabulaTests/PersistenceManagerTests.swift`

---

## 開発言語・フレームワーク

- **プログラミング言語**: Swift 6
  - macOS 向けネイティブアプリ。Security.framework が標準で利用可能
  - XCTest との親和性が高く、実 Keychain を使ったテストが可能
- **テストフレームワーク**: XCTest
  - macOS 標準のテストフレームワーク。Xcode と統合済み
  - `setUp()` / `tearDown()` で Keychain のクリーンアップが可能
  - `XCTAssertEqual` などのアサーションが豊富

**信頼性**: 🔵 *CLAUDE.md・note.md 技術スタックより*

---

## セットアップ・クリーンアップ設計

```swift
// 【テスト前準備】: 各テスト実行前に Keychain と UserDefaults をクリーンアップ
// 【環境初期化】: 前テストの残留データがテスト結果に影響しないよう毎回初期化
override func setUp() {
    super.setUp()
    // Keychain クリーンアップ
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "jp.umi.design.nTabula",
        kSecAttrAccount as String: "NotionToken"
    ]
    SecItemDelete(query as CFDictionary)
    // UserDefaults クリーンアップ（マイグレーションテスト用）
    UserDefaults.standard.removeObject(forKey: "nTabula.notionToken")
}

// 【テスト後処理】: 各テスト実行後に Keychain をクリーンアップ
// 【状態復元】: 実際の Keychain を使用するため、テスト後のクリーンアップが必須
override func tearDown() {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "jp.umi.design.nTabula",
        kSecAttrAccount as String: "NotionToken"
    ]
    SecItemDelete(query as CFDictionary)
    UserDefaults.standard.removeObject(forKey: "nTabula.notionToken")
    super.tearDown()
}
```

**信頼性**: 🔵 *note.md「Keychain テストの注意点」より*

---

## 1. 正常系テストケース

### TC-001: saveToken / loadToken 基本正常系 🔵

**信頼性**: 🔵 *TASK-0001.md テストケース1・REQ-403 より*

- **テスト名**: `testSaveAndLoadToken_正常系_保存したトークンを読み込める`
- **何をテストするか**: saveToken() で保存したトークンを loadToken() で正しく読み込めること
- **期待される動作**: Keychain への書き込みと読み込みが対称的に動作する

**入力値**:
- `token = "secret-integration-token-1234"`
- **入力データの意味**: Notion Integration Token として想定される典型的な文字列

**期待される結果**:
- `loadToken()` の戻り値が `"secret-integration-token-1234"` と等しい
- **期待結果の理由**: saveToken → Keychain 保存 → loadToken → Keychain 読込 の一連のフローが正常動作するため

**テストの目的**: saveToken / loadToken の基本的な往復動作の確認

```swift
// 【テスト目的】: saveToken で保存したトークンが loadToken で正しく取得できることを確認
// 【テスト内容】: Keychain への書き込み → 読み込みの一連フローをテスト
// 【期待される動作】: 保存した文字列が完全に一致して返される
// 🔵 REQ-403・persistence-schema.md より
func testSaveAndLoadToken_正常系_保存したトークンを読み込める() {
    let sut = PersistenceManager.shared
    let token = "secret-integration-token-1234"

    // 【実際の処理実行】: saveToken で Keychain に保存
    sut.saveToken(token)

    // 【実際の処理実行】: loadToken で Keychain から読み込み
    let loaded = sut.loadToken()

    // 【結果検証】: 保存したトークンと読み込んだトークンが一致することを確認
    // 【確認内容】: Keychain の読み書きが対称的に動作することを保証
    XCTAssertEqual(loaded, token) // 🔵 保存値と読込値の一致確認
}
```

---

### TC-002: 日本語・特殊文字を含むトークン 🟡

**信頼性**: 🟡 *Keychain の UTF-8 データ保存仕様から妥当な推測*

- **テスト名**: `testSaveAndLoadToken_正常系_特殊文字を含むトークンを保存できる`
- **何をテストするか**: 特殊文字や記号を含む文字列を Keychain に保存・復元できること
- **期待される動作**: UTF-8 エンコード → Keychain 保存 → UTF-8 デコードが正確に行われる

**入力値**:
- `token = "token-with-special!@#$%^&*()_+chars"`
- **入力データの意味**: API トークンに含まれうる特殊文字の網羅的テスト

**期待される結果**:
- `loadToken()` の戻り値が入力と完全一致

```swift
// 【テスト目的】: 特殊文字を含むトークンが UTF-8 を経由して正確に保存・復元できることを確認
// 🟡 UTF-8 エンコード仕様から妥当な推測
func testSaveAndLoadToken_正常系_特殊文字を含むトークンを保存できる() {
    let sut = PersistenceManager.shared
    let token = "token-with-special!@#$%^&*()_+chars"

    sut.saveToken(token)
    let loaded = sut.loadToken()

    XCTAssertEqual(loaded, token) // 🟡 特殊文字が正確に保持されることを確認
}
```

---

### TC-003: 長いトークン文字列 🟡

**信頼性**: 🟡 *Keychain のデータ容量制限の観点から妥当な推測*

- **テスト名**: `testSaveAndLoadToken_正常系_長いトークンを保存できる`
- **何をテストするか**: Notion Integration Token として想定される最大長のトークンが保存できること
- **期待される動作**: 長い文字列も完全に保存・復元できる

**入力値**:
- `token = "ntn_" + String(repeating: "a", count: 256)` （260文字）
- **入力データの意味**: Notion Token は通常 "ntn_" プレフィックスを持ち、その後に Base64 等の文字列が続く

**期待される結果**:
- `loadToken()` の戻り値が入力と完全一致

```swift
// 【テスト目的】: 長いトークン文字列が Keychain に正しく保存・復元できることを確認
// 🟡 Notion Token の実際の形式から妥当な推測
func testSaveAndLoadToken_正常系_長いトークンを保存できる() {
    let sut = PersistenceManager.shared
    let token = "ntn_" + String(repeating: "a", count: 256)

    sut.saveToken(token)
    let loaded = sut.loadToken()

    XCTAssertEqual(loaded, token) // 🟡 長いトークンが完全に保存・復元されることを確認
}
```

---

## 2. 異常系テストケース

### TC-004: Keychain に何もない状態で loadToken 🔵

**信頼性**: 🔵 *TASK-0001.md テストケース2・EDGE-005 より*

- **テスト名**: `testLoadToken_異常系_Keychainが空の場合は空文字を返す`
- **エラーケースの概要**: Keychain にも UserDefaults にもトークンが存在しない状態
- **エラー処理の重要性**: 新規ユーザー（未設定状態）でのアプリ起動時の動作保証

**入力値**:
- Keychain: 空（setUp でクリーン済み）
- UserDefaults["nTabula.notionToken"]: 未設定（setUp でクリーン済み）
- **不正な理由**: アプリ初回起動時の正常な「未設定」状態

**期待される結果**:
- `loadToken()` が `""` を返す
- **エラーメッセージの内容**: エラーではなく空文字返却（AppState 側で未設定として扱う）
- **システムの安全性**: 空文字返却によりクラッシュせず動作を継続

```swift
// 【テスト目的】: Keychain・UserDefaults 両方が空の場合に空文字が返ることを確認
// 【テスト内容】: 新規ユーザー（初回起動）のシナリオをシミュレート
// 【期待される動作】: "" が返されてクラッシュしない
// 🔵 TASK-0001.md テストケース2・EDGE-005 より
func testLoadToken_異常系_Keychainが空の場合は空文字を返す() {
    let sut = PersistenceManager.shared

    // 【前提条件確認】: setUp により Keychain と UserDefaults は空の状態

    // 【実際の処理実行】: 空の状態で loadToken を呼び出す
    let result = sut.loadToken()

    // 【結果検証】: 空文字が返されることを確認
    XCTAssertEqual(result, "") // 🔵 EDGE-005: Keychain に何もない場合は空文字返却
}
```

---

### TC-005: 空文字列トークンの保存 🟡

**信頼性**: 🟡 *saveToken 実装設計から妥当な推測（空文字は UTF-8 変換成功するため保存される）*

- **テスト名**: `testSaveToken_異常系_空文字列を保存した場合の動作確認`
- **エラーケースの概要**: 空文字列をトークンとして保存しようとするケース
- **エラー処理の重要性**: ユーザーがトークンを削除（空に）した場合の動作確認

**入力値**:
- `token = ""`
- **不正な理由**: トークン未設定時に送られる可能性がある

**期待される結果**:
- `saveToken("")` を実行した後、`loadToken()` が `""` を返す（空文字は UTF-8 変換成功のため保存される）
- または `loadToken()` が `""` を返す（どちらの動作でも AppState は正常動作）

```swift
// 【テスト目的】: 空文字列を saveToken に渡した場合の動作を確認
// 【テスト内容】: guard let data チェックを通過する（空文字の UTF-8 は有効な Data）
// 🟡 saveToken の guard 条件から妥当な推測
func testSaveToken_異常系_空文字列を保存した場合の動作確認() {
    let sut = PersistenceManager.shared

    // 【実際の処理実行】: 空文字列を保存
    sut.saveToken("")
    let result = sut.loadToken()

    // 【結果検証】: 保存後も loadToken が空文字を返す（空文字は保存可能）
    XCTAssertEqual(result, "") // 🟡 空文字の保存・読込の一貫性確認
}
```

---

## 3. 境界値テストケース

### TC-006: トークン上書き（Delete → Add の動作確認）🔵

**信頼性**: 🔵 *TASK-0001.md テストケース3・persistence-schema.md Delete→Add方式 より*

- **テスト名**: `testSaveToken_境界値_既存トークンを上書きできる`
- **境界値の意味**: 同じ Keychain エントリに対して2回保存したとき、後の値が正しく反映されること
- **境界値での動作保証**: SecItemDelete → SecItemAdd の上書きロジックの正常動作

**入力値**:
1. `saveToken("old-token-value")`
2. `saveToken("new-token-value")`
- **境界値選択の根拠**: 上書き時に「古いエントリが残らず新しい値だけ取得できること」を確認する必要がある

**期待される結果**:
- `loadToken()` が `"new-token-value"` を返す（`"old-token-value"` ではない）
- **境界での正確性**: SecItemDelete で確実に古いエントリが消えてから SecItemAdd が実行される

```swift
// 【テスト目的】: 既存トークンを上書きした場合に新しいトークンだけが保存されることを確認
// 【テスト内容】: Delete → Add 上書き方式の正常動作を検証
// 【期待される動作】: 2回目の saveToken 後は新しい値のみ取得される
// 🔵 TASK-0001.md テストケース3・persistence-schema.md より
func testSaveToken_境界値_既存トークンを上書きできる() {
    let sut = PersistenceManager.shared

    // 【テストデータ準備】: 最初のトークンを保存
    sut.saveToken("old-token-value")

    // 【実際の処理実行】: 新しいトークンで上書き
    sut.saveToken("new-token-value")
    let result = sut.loadToken()

    // 【結果検証】: 新しいトークンのみが返されることを確認
    XCTAssertEqual(result, "new-token-value")       // 🔵 新しい値が取得される
    XCTAssertNotEqual(result, "old-token-value")     // 🔵 古い値は消えている
}
```

---

### TC-007: UserDefaults マイグレーション 🔵

**信頼性**: 🔵 *TASK-0001.md テストケース4・persistence-schema.md 起動時マイグレーション より*

- **テスト名**: `testLoadToken_境界値_UserDefaultsのトークンをKeychainにマイグレーションできる`
- **境界値の意味**: UserDefaults に旧トークンがあり Keychain が空の状態（既存ユーザーの初回アップデート後）
- **境界値での動作保証**: マイグレーションが1回だけ実行され、その後 UserDefaults が削除されること

**入力値**:
- Keychain: 空（setUp でクリーン済み）
- `UserDefaults.standard.set("migrated-token", forKey: "nTabula.notionToken")`
- **境界値選択の根拠**: 既存ユーザーがアップデートする際に必ず通るパス

**期待される結果**:
1. `loadToken()` が `"migrated-token"` を返す
2. `UserDefaults.standard.string(forKey: "nTabula.notionToken")` が `nil` になる
3. 2回目の `loadToken()` でも `"migrated-token"` が返る（Keychain から取得）
- **境界での正確性**: マイグレーション後は UserDefaults が削除され Keychain から読み込まれる

```swift
// 【テスト目的】: UserDefaults の旧トークンを Keychain に移行できることを確認
// 【テスト内容】: 起動時マイグレーション（UserDefaults → Keychain）フロー全体をテスト
// 【期待される動作】:
//   1. loadToken がマイグレーション元のトークンを返す
//   2. UserDefaults からトークンが削除される
//   3. Keychain にトークンが保存される
// 🔵 TASK-0001.md テストケース4・persistence-schema.md 起動時マイグレーションより
func testLoadToken_境界値_UserDefaultsのトークンをKeychainにマイグレーションできる() {
    let sut = PersistenceManager.shared

    // 【テストデータ準備】: UserDefaults に旧トークンを設定（既存ユーザーの状態を模倣）
    UserDefaults.standard.set("migrated-token", forKey: "nTabula.notionToken")

    // 【実際の処理実行】: loadToken を呼び出してマイグレーションを実行
    let result = sut.loadToken()

    // 【結果検証1】: マイグレーション元のトークンが返されること
    XCTAssertEqual(result, "migrated-token") // 🔵 UserDefaults の値が正しく返される

    // 【結果検証2】: UserDefaults からトークンが削除されたこと
    let remainingDefaults = UserDefaults.standard.string(forKey: "nTabula.notionToken")
    XCTAssertNil(remainingDefaults) // 🔵 UserDefaults からのキー削除を確認

    // 【結果検証3】: 2回目の loadToken でも同じ値が返ること（Keychain から取得）
    let secondLoad = sut.loadToken()
    XCTAssertEqual(secondLoad, "migrated-token") // 🔵 Keychain への保存確認（2回目も取得可能）
}
```

---

### TC-008: マイグレーション後の UserDefaults が空の場合 🔵

**信頼性**: 🔵 *persistence-schema.md 起動時マイグレーションのパターン3 より*

- **テスト名**: `testLoadToken_境界値_Keychainも空でUserDefaultsも空の場合は空文字を返す`
- **境界値の意味**: 両ストレージが完全に空（新規ユーザーまたは完全クリーン後）
- **境界値での動作保証**: フォールスルーして空文字を返す最終パスが正しく動作する

**入力値**:
- Keychain: 空、UserDefaults["nTabula.notionToken"]: 未設定
- **境界値選択の根拠**: 3つのパス（Keychain あり / UserDefaults あり / 両方なし）の最終パスを検証

**期待される結果**:
- `loadToken()` が `""` を返す

```swift
// 【テスト目的】: Keychain・UserDefaults 両方が空の場合に空文字を返す最終フォールスルーを確認
// 🔵 persistence-schema.md フロー「両方なし（新規ユーザー）」より
func testLoadToken_境界値_Keychainも空でUserDefaultsも空の場合は空文字を返す() {
    let sut = PersistenceManager.shared

    // 【前提条件確認】: setUp により両ストレージが空
    let result = sut.loadToken()

    // 【結果検証】: 空文字が返される
    XCTAssertEqual(result, "") // 🔵 最終フォールスルーで空文字返却
}
```

---

### TC-009: 連続 saveToken（複数回上書き）🟡

**信頼性**: 🟡 *Delete→Add 方式の連続実行動作から妥当な推測*

- **テスト名**: `testSaveToken_境界値_複数回連続保存しても最後の値が取得できる`
- **境界値の意味**: 連続して複数回 saveToken を呼び出したとき最後の値が正しく保存されること
- **境界値での動作保証**: Delete → Add の繰り返しでも Keychain が破損しないこと

**入力値**:
1. `saveToken("token-1")`
2. `saveToken("token-2")`
3. `saveToken("token-3")`

**期待される結果**:
- `loadToken()` が `"token-3"` を返す

```swift
// 【テスト目的】: 連続して saveToken を呼び出した場合に最後の値が正しく取得できることを確認
// 🟡 Delete→Add 連続実行の安定性確認
func testSaveToken_境界値_複数回連続保存しても最後の値が取得できる() {
    let sut = PersistenceManager.shared

    sut.saveToken("token-1")
    sut.saveToken("token-2")
    sut.saveToken("token-3")

    let result = sut.loadToken()

    XCTAssertEqual(result, "token-3") // 🟡 最後に保存した値が取得される
}
```

---

## 4. Keychain 定数の仕様確認テスト

### TC-010: Keychain 定数（Service・Account）の検証 🔵

**信頼性**: 🔵 *persistence-schema.md Keychain エントリ仕様・TASK-0001.md 完了条件 より*

- **テスト名**: `testKeychainConstants_正常系_正しいServiceとAccountが使用されている`
- **何をテストするか**: 保存したトークンが設計仕様通りの Service / Account で Keychain に格納されていること
- **期待される動作**: `kSecAttrService = "jp.umi.design.nTabula"`, `kSecAttrAccount = "NotionToken"` で保存される

**テストの目的**: 定数の誤りによる Keychain エントリ不一致を防ぐ

```swift
// 【テスト目的】: 設計仕様通りの Keychain 定数（Service/Account）で保存されることを確認
// 【テスト内容】: saveToken 後に Security.framework で直接 Keychain を検索して存在確認
// 🔵 persistence-schema.md Keychain エントリ仕様より
func testKeychainConstants_正常系_正しいServiceとAccountが使用されている() {
    let sut = PersistenceManager.shared
    let token = "verify-constants-token"

    sut.saveToken(token)

    // Security.framework で直接 Keychain を検索（PersistenceManager を経由しない）
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "jp.umi.design.nTabula",  // 🔵 設計仕様の値
        kSecAttrAccount as String: "NotionToken",             // 🔵 設計仕様の値
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    // 【結果検証】: 指定した定数でエントリが存在することを確認
    XCTAssertEqual(status, errSecSuccess) // 🔵 指定定数でエントリが見つかる
    if let data = result as? Data {
        let retrievedToken = String(data: data, encoding: .utf8)
        XCTAssertEqual(retrievedToken, token) // 🔵 取得値と保存値が一致
    } else {
        XCTFail("Keychain からデータを取得できなかった")
    }
}
```

---

## テストケース一覧

| ID | テスト名 | 分類 | 信頼性 | 要件対応 |
|----|---------|------|--------|---------|
| TC-001 | saveToken/loadToken 基本正常系 | 正常系 | 🔵 | REQ-403, テストケース1 |
| TC-002 | 特殊文字を含むトークン | 正常系 | 🟡 | REQ-403 |
| TC-003 | 長いトークン文字列 | 正常系 | 🟡 | REQ-403 |
| TC-004 | Keychain が空の場合は空文字 | 異常系 | 🔵 | EDGE-005, テストケース2 |
| TC-005 | 空文字列トークンの保存 | 異常系 | 🟡 | — |
| TC-006 | 既存トークンを上書き | 境界値 | 🔵 | テストケース3, Delete→Add |
| TC-007 | UserDefaults マイグレーション | 境界値 | 🔵 | テストケース4, NFR-102 |
| TC-008 | 両ストレージが空 | 境界値 | 🔵 | EDGE-005 |
| TC-009 | 連続複数回保存 | 境界値 | 🟡 | — |
| TC-010 | Keychain 定数検証 | 正常系 | 🔵 | TASK-0001 完了条件 |

---

## 信頼性レベルサマリー

| 信頼性 | 件数 | 割合 |
|--------|------|------|
| 🔵 青信号 | 7件 | 70% |
| 🟡 黄信号 | 3件 | 30% |
| 🔴 赤信号 | 0件 | 0% |

**品質評価**: ✅ 高品質

---

## 要件定義との対応関係

- **参照した機能概要**: `docs/implements/ntabula/TASK-0001/keychain-requirements.md` セクション1
- **参照した入力・出力仕様**: `docs/implements/ntabula/TASK-0001/keychain-requirements.md` セクション2
- **参照した制約条件**: `docs/implements/ntabula/TASK-0001/keychain-requirements.md` セクション3（Delete→Add・Keychain定数）
- **参照した使用例**: `docs/implements/ntabula/TASK-0001/keychain-requirements.md` セクション4（エッジケース）
- **参照したタスク定義**: `docs/tasks/ntabula/TASK-0001.md`（テストケース1〜4）
- **参照した設計文書**: `docs/design/ntabula/persistence-schema.md`
