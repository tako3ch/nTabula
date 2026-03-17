import XCTest
import Security
@testable import nTabula

// MARK: - PersistenceManagerTests
// 【テスト対象】: PersistenceManager の Keychain 保存・読込・マイグレーション機能
// 【テスト種別】: Unit Test（実 Keychain を使用）
// 【テストケース数】: 10件（正常系3 / 異常系2 / 境界値5）
// 🔵 docs/implements/ntabula/TASK-0001/keychain-testcases.md より

final class PersistenceManagerTests: XCTestCase {

    // MARK: - セットアップ・クリーンアップ

    override func setUp() {
        super.setUp()
        // 【テスト前準備】: 各テスト実行前に Keychain と UserDefaults をクリーンアップ
        // 【環境初期化】: 前テストの残留データがテスト結果に影響しないよう毎回初期化
        // 🔵 note.md「Keychain テストの注意点」より
        cleanupKeychain()
        UserDefaults.standard.removeObject(forKey: "nTabula.notionToken")
    }

    override func tearDown() {
        // 【テスト後処理】: 各テスト実行後に Keychain と UserDefaults をクリーンアップ
        // 【状態復元】: 実際の Keychain を使用するため、テスト後のクリーンアップが必須
        cleanupKeychain()
        UserDefaults.standard.removeObject(forKey: "nTabula.notionToken")
        super.tearDown()
    }

    // MARK: - ヘルパー

    // 【スレッド対応】: Keychain 操作はバックグラウンドスレッドで実行（メインスレッド警告を回避）
    private func cleanupKeychain() {
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue(label: "test.keychain.cleanup").async {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "jp.umi.design.nTabula",
                kSecAttrAccount as String: "NotionToken"
            ]
            SecItemDelete(query as CFDictionary)
            semaphore.signal()
        }
        semaphore.wait()
    }

    // MARK: - 正常系テストケース

    /// TC-001: saveToken / loadToken 基本正常系
    // 【テスト目的】: saveToken で保存したトークンが loadToken で正しく取得できることを確認
    // 【テスト内容】: Keychain への書き込み → 読み込みの一連フローをテスト
    // 【期待される動作】: 保存した文字列が完全に一致して返される
    // 🔵 REQ-403・TASK-0001.md テストケース1 より
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

    /// TC-002: 特殊文字を含むトークンの保存・復元
    // 【テスト目的】: 特殊文字を含むトークンが UTF-8 を経由して正確に保存・復元できることを確認
    // 【テスト内容】: 記号・特殊文字を含む文字列の Keychain 保存・復元テスト
    // 【期待される動作】: UTF-8 エンコード → Keychain 保存 → UTF-8 デコードが正確に行われる
    // 🟡 Keychain の UTF-8 データ保存仕様から妥当な推測
    func testSaveAndLoadToken_正常系_特殊文字を含むトークンを保存できる() {
        let sut = PersistenceManager.shared
        let token = "token-with-special!@#$%^&*()_+chars"

        // 【実際の処理実行】: 特殊文字を含むトークンを保存・読込
        sut.saveToken(token)
        let loaded = sut.loadToken()

        // 【結果検証】: 特殊文字が正確に保持されることを確認
        XCTAssertEqual(loaded, token) // 🟡 特殊文字が正確に保持されることを確認
    }

    /// TC-003: 長いトークン文字列の保存・復元
    // 【テスト目的】: 長いトークン文字列が Keychain に正しく保存・復元できることを確認
    // 【テスト内容】: Notion Integration Token の実際の形式（ntn_ + 長い文字列）をシミュレート
    // 【期待される動作】: 長い文字列も完全に保存・復元できる
    // 🟡 Notion Token の実際の形式から妥当な推測
    func testSaveAndLoadToken_正常系_長いトークンを保存できる() {
        let sut = PersistenceManager.shared
        let token = "ntn_" + String(repeating: "a", count: 256) // 260文字

        // 【実際の処理実行】: 長いトークンを保存・読込
        sut.saveToken(token)
        let loaded = sut.loadToken()

        // 【結果検証】: 長いトークンが完全に保存・復元されることを確認
        XCTAssertEqual(loaded, token) // 🟡 長いトークンが完全に保存・復元されることを確認
    }

    // MARK: - 異常系テストケース

    /// TC-004: Keychain が空の場合は空文字を返す
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

    /// TC-005: 空文字列トークンの保存時の動作確認
    // 【テスト目的】: 空文字列を saveToken に渡した場合の動作を確認
    // 【テスト内容】: guard let data チェックを通過する（空文字の UTF-8 は有効な Data）
    // 【期待される動作】: 保存後も loadToken が空文字を返す
    // 🟡 saveToken の guard 条件から妥当な推測
    func testSaveToken_異常系_空文字列を保存した場合の動作確認() {
        let sut = PersistenceManager.shared

        // 【実際の処理実行】: 空文字列を保存し読み込む
        sut.saveToken("")
        let result = sut.loadToken()

        // 【結果検証】: 保存後も loadToken が空文字を返す（空文字は保存可能）
        XCTAssertEqual(result, "") // 🟡 空文字の保存・読込の一貫性確認
    }

    // MARK: - 境界値テストケース

    /// TC-006: 既存トークンの上書き（Delete → Add 方式の動作確認）
    // 【テスト目的】: 既存トークンを上書きした場合に新しいトークンだけが保存されることを確認
    // 【テスト内容】: Delete → Add 上書き方式の正常動作を検証
    // 【期待される動作】: 2回目の saveToken 後は新しい値のみ取得される
    // 🔵 TASK-0001.md テストケース3・persistence-schema.md より
    func testSaveToken_境界値_既存トークンを上書きできる() {
        let sut = PersistenceManager.shared

        // 【テストデータ準備】: 最初のトークンを保存（古い値）
        sut.saveToken("old-token-value")

        // 【実際の処理実行】: 新しいトークンで上書き
        sut.saveToken("new-token-value")
        let result = sut.loadToken()

        // 【結果検証】: 新しいトークンのみが返されることを確認
        XCTAssertEqual(result, "new-token-value")       // 🔵 新しい値が取得される
        XCTAssertNotEqual(result, "old-token-value")    // 🔵 古い値は消えている
    }

    /// TC-007: UserDefaults から Keychain へのマイグレーション
    // 【テスト目的】: UserDefaults の旧トークンを Keychain に移行できることを確認
    // 【テスト内容】: 起動時マイグレーション（UserDefaults → Keychain）フロー全体をテスト
    // 【期待される動作】:
    //   1. loadToken がマイグレーション元のトークンを返す
    //   2. UserDefaults からトークンが削除される
    //   3. Keychain にトークンが保存される（2回目の loadToken でも取得可能）
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

    /// TC-008: Keychain も UserDefaults も空の場合は空文字を返す
    // 【テスト目的】: Keychain・UserDefaults 両方が空の場合に空文字を返す最終フォールスルーを確認
    // 【テスト内容】: 3つの分岐パス（Keychainあり / UserDefaultsあり / 両方なし）の最終パス
    // 【期待される動作】: "" が返される
    // 🔵 persistence-schema.md フロー「両方なし（新規ユーザー）」より
    func testLoadToken_境界値_Keychainも空でUserDefaultsも空の場合は空文字を返す() {
        let sut = PersistenceManager.shared

        // 【前提条件確認】: setUp により両ストレージが空
        let result = sut.loadToken()

        // 【結果検証】: 空文字が返される
        XCTAssertEqual(result, "") // 🔵 最終フォールスルーで空文字返却
    }

    /// TC-009: 連続した複数回の saveToken
    // 【テスト目的】: 連続して saveToken を呼び出した場合に最後の値が正しく取得できることを確認
    // 【テスト内容】: Delete → Add 上書き方式を連続で3回実行
    // 【期待される動作】: 最後に保存したトークンのみが Keychain に残る
    // 🟡 Delete→Add 連続実行の安定性確認
    func testSaveToken_境界値_複数回連続保存しても最後の値が取得できる() {
        let sut = PersistenceManager.shared

        // 【テストデータ準備】: 3回連続で保存（最後の値が残るべき）
        sut.saveToken("token-1")
        sut.saveToken("token-2")
        sut.saveToken("token-3")

        let result = sut.loadToken()

        // 【結果検証】: 最後に保存した値が取得される
        XCTAssertEqual(result, "token-3") // 🟡 最後に保存した値が取得される
    }

    // MARK: - Keychain 定数検証テスト

    /// TC-010: Keychain 定数（Service・Account）の検証
    // 【テスト目的】: 設計仕様通りの Keychain 定数（Service/Account）で保存されることを確認
    // 【テスト内容】: saveToken 後に Security.framework で直接 Keychain を検索して存在確認
    // 【期待される動作】:
    //   - kSecAttrService = "jp.umi.design.nTabula" で保存されている
    //   - kSecAttrAccount = "NotionToken" で保存されている
    // 🔵 persistence-schema.md Keychain エントリ仕様・TASK-0001.md 完了条件 より
    func testKeychainConstants_正常系_正しいServiceとAccountが使用されている() {
        let sut = PersistenceManager.shared
        let token = "verify-constants-token"

        // 【実際の処理実行】: saveToken でトークンを保存
        sut.saveToken(token)

        // 【結果検証】: Security.framework で直接 Keychain を検索（PersistenceManager を経由しない）
        // 【スレッド対応】: バックグラウンドキューで実行してメインスレッド警告を回避
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "jp.umi.design.nTabula",  // 🔵 設計仕様の Service 値
            kSecAttrAccount as String: "NotionToken",             // 🔵 設計仕様の Account 値
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        var status: OSStatus = errSecInternalError
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue(label: "test.keychain.verify").async {
            status = SecItemCopyMatching(query as CFDictionary, &result)
            semaphore.signal()
        }
        semaphore.wait()

        // 【確認内容1】: 指定した定数でエントリが存在することを確認
        XCTAssertEqual(status, errSecSuccess) // 🔵 指定定数でエントリが見つかる

        // 【確認内容2】: 取得したデータが保存したトークンと一致することを確認
        if let data = result as? Data {
            let retrievedToken = String(data: data, encoding: .utf8)
            XCTAssertEqual(retrievedToken, token) // 🔵 取得値と保存値が一致
        } else {
            XCTFail("Keychain からデータを取得できなかった") // 🔵 データ取得失敗は仕様違反
        }
    }
}
