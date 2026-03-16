import Foundation
import AppKit
import Security

final class PersistenceManager {
    static let shared = PersistenceManager()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let tabs = "nTabula.tabs"
        static let activeTabID = "nTabula.activeTabID"
        static let windowFrame = "nTabula.windowFrame"
        static let tabLayoutMode = "nTabula.tabLayoutMode"
        static let notionToken = "nTabula.notionToken"
        static let selectedDatabaseID = "nTabula.selectedDatabaseID"
        static let selectedParentPageID = "nTabula.selectedParentPageID"
        static let notionSaveTarget = "nTabula.notionSaveTarget"
        static let autoSaveEnabled = "nTabula.autoSaveEnabled"
        static let editorFontSize = "nTabula.editorFontSize"
        static let editorFontName = "nTabula.editorFontName"
    }

    // Keychain 操作はメインスレッドで呼ぶと警告が出るため専用キューで実行
    private let keychainQueue = DispatchQueue(label: "jp.umi.design.nTabula.keychain", qos: .userInitiated)

    private init() {}

    // MARK: - Tabs

    func saveTabs(_ tabs: [TabItem]) {
        guard let data = try? JSONEncoder().encode(tabs) else { return }
        defaults.set(data, forKey: Keys.tabs)
    }

    func loadTabs() -> [TabItem] {
        guard let data = defaults.data(forKey: Keys.tabs),
              let tabs = try? JSONDecoder().decode([TabItem].self, from: data) else {
            return []
        }
        return tabs
    }

    func saveActiveTabID(_ id: UUID?) {
        defaults.set(id?.uuidString, forKey: Keys.activeTabID)
    }

    func loadActiveTabID() -> UUID? {
        guard let str = defaults.string(forKey: Keys.activeTabID) else { return nil }
        return UUID(uuidString: str)
    }

    // MARK: - Window

    func saveWindowFrame(_ frame: NSRect) {
        defaults.set(NSStringFromRect(frame), forKey: Keys.windowFrame)
    }

    func loadWindowFrame() -> NSRect? {
        guard let str = defaults.string(forKey: Keys.windowFrame) else { return nil }
        let rect = NSRectFromString(str)
        return rect == .zero ? nil : rect
    }

    // MARK: - Keychain 定数
    // 🔵 persistence-schema.md Keychain エントリ仕様より
    private enum KeychainConstants {
        static let service = "jp.umi.design.nTabula"
        static let account = "NotionToken"
    }

    // MARK: - Notion

    /// 【機能概要】: Notion Integration Token を Keychain に保存する
    /// 【実装方針】: Delete → Add 上書き方式（SecItemUpdate は使わない）
    /// 【スレッド対応】: async + semaphore でバックグラウンドスレッドで実行（sync は GCD 最適化でメインスレッド実行になるため使わない）
    /// 【テスト対応】: TC-001〜TC-006, TC-009, TC-010 を通すための実装
    /// 🔵 persistence-schema.md・keychain-requirements.md より
    func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        // 【async + semaphore】: keychainQueue で確実にバックグラウンド実行（sync は calling thread 最適化されるため不可）
        let semaphore = DispatchSemaphore(value: 0)
        keychainQueue.async {
            // 【既存エントリ削除】: 上書きのため先に削除する 🔵
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: KeychainConstants.service,
                kSecAttrAccount as String: KeychainConstants.account
            ]
            SecItemDelete(deleteQuery as CFDictionary)

            // 【新規エントリ追加】: Keychain に保存 🔵
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: KeychainConstants.service,
                kSecAttrAccount as String: KeychainConstants.account,
                kSecValueData as String: data
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
            semaphore.signal()
        }
        semaphore.wait()
    }

    /// 【機能概要】: Keychain から Notion Integration Token を読み込む
    /// 【実装方針】: Keychain 優先 → UserDefaults マイグレーション → 空文字フォールバック
    /// 【スレッド対応】: async + semaphore でバックグラウンドスレッドで実行
    /// 【テスト対応】: TC-001〜TC-009 を通すための実装
    /// 🔵 persistence-schema.md・keychain-requirements.md より
    func loadToken() -> String {
        var tokenResult = ""
        // 【async + semaphore】: keychainQueue で確実にバックグラウンド実行 🔵
        let semaphore = DispatchSemaphore(value: 0)
        keychainQueue.async { [self] in
            // 【Keychain 読み込み】: まず Keychain から取得を試みる 🔵
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: KeychainConstants.service,
                kSecAttrAccount as String: KeychainConstants.account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecSuccess,
               let data = result as? Data,
               let token = String(data: data, encoding: .utf8) {
                tokenResult = token
                semaphore.signal()
                return
            }

            // 【マイグレーション】: UserDefaults に旧トークンがあれば Keychain へ移行 🔵
            // TC-007: loadToken 呼び出し後に UserDefaults からトークンが削除されることを保証
            if let legacyToken = self.defaults.string(forKey: Keys.notionToken), !legacyToken.isEmpty {
                guard let data = legacyToken.data(using: .utf8) else {
                    semaphore.signal()
                    return
                }
                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: KeychainConstants.service,
                    kSecAttrAccount as String: KeychainConstants.account
                ]
                SecItemDelete(deleteQuery as CFDictionary)
                let addQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: KeychainConstants.service,
                    kSecAttrAccount as String: KeychainConstants.account,
                    kSecValueData as String: data
                ]
                SecItemAdd(addQuery as CFDictionary, nil)
                self.defaults.removeObject(forKey: Keys.notionToken)
                tokenResult = legacyToken
            }

            // 【フォールバック】: どちらにもなければ空文字 🔵
            semaphore.signal()
        }
        semaphore.wait()
        return tokenResult
    }

    func saveSelectedDatabaseID(_ id: String) {
        defaults.set(id, forKey: Keys.selectedDatabaseID)
    }

    func loadSelectedDatabaseID() -> String {
        defaults.string(forKey: Keys.selectedDatabaseID) ?? ""
    }

    func saveSelectedParentPageID(_ id: String) {
        defaults.set(id, forKey: Keys.selectedParentPageID)
    }

    func loadSelectedParentPageID() -> String {
        defaults.string(forKey: Keys.selectedParentPageID) ?? ""
    }

    func saveNotionSaveTarget(_ target: NotionSaveTarget) {
        defaults.set(target.rawValue, forKey: Keys.notionSaveTarget)
    }

    func loadNotionSaveTarget() -> NotionSaveTarget {
        guard let raw = defaults.string(forKey: Keys.notionSaveTarget),
              let target = NotionSaveTarget(rawValue: raw) else { return .database }
        return target
    }

    // MARK: - UI Settings

    func saveTabLayoutMode(_ mode: TabLayoutMode) {
        defaults.set(mode.rawValue, forKey: Keys.tabLayoutMode)
    }

    func loadTabLayoutMode() -> TabLayoutMode {
        guard let raw = defaults.string(forKey: Keys.tabLayoutMode),
              let mode = TabLayoutMode(rawValue: raw) else { return .horizontal }
        return mode
    }

    func saveAutoSaveEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.autoSaveEnabled)
    }

    func loadAutoSaveEnabled() -> Bool {
        defaults.object(forKey: Keys.autoSaveEnabled) as? Bool ?? true
    }

    func saveFontSize(_ size: CGFloat) {
        defaults.set(Double(size), forKey: Keys.editorFontSize)
    }

    func loadFontSize() -> CGFloat {
        let val = defaults.double(forKey: Keys.editorFontSize)
        return val > 0 ? CGFloat(val) : 14
    }

    func saveFontName(_ name: String) {
        defaults.set(name, forKey: Keys.editorFontName)
    }

    func loadFontName() -> String {
        defaults.string(forKey: Keys.editorFontName) ?? ""
    }
}
