// ==========================================================
// nTabula 型定義集約
//
// 作成日: 2026-03-16
// 更新日: 2026-03-16（kairo-design によるヒアリング反映）
// 関連設計: architecture.md
//
// 信頼性レベル:
// - 🔵 青信号: EARS要件定義書・設計文書・既存実装を参考にした確実な型定義
// - 🟡 黄信号: EARS要件定義書・設計文書・既存実装から妥当な推測による型定義
// - 🔴 赤信号: EARS要件定義書・設計文書・既存実装にない推測による型定義
//
// 実際の実装は Sources/ 以下の各ファイルを参照
// ==========================================================

import Foundation
import Security

// MARK: - ドメインモデル

/// タブレイアウトモード
/// 🔵 Sources/Models/TabItem.swift より
enum TabLayoutMode: String, Codable, CaseIterable {
    case horizontal  // 横タブバー
    case vertical    // Arc 風縦サイドバー
}

/// Notion への保存先タイプ
/// 🔵 Sources/App/AppState.swift より
enum NotionSaveTarget: String, Codable {
    case database  // データベースの直下にページ作成
    case page      // 選択した親ページの子ページとして作成
}

/// タブデータモデル
/// 🔵 Sources/Models/TabItem.swift より
struct TabItem: Identifiable, Codable, Equatable {
    var id: UUID                        // 🔵 既存実装より
    var title: String                   // 🔵 デフォルト: yyyy-MM-dd-連番 (NFR-402)
    var content: String                 // 🔵 Markdown 本文
    var notionPageID: String?           // 🔵 Notion 保存済みの場合のみ設定
    var databaseID: String?             // 🟡 現状未使用。将来的なタブ単位保存先として保留
    var titlePropertyName: String       // 🔵 Notion タイトルプロパティ名 (REQ-407)
    var isPinned: Bool                  // 🔵 ピン留め状態 (REQ-304)
    var isDirty: Bool                   // 🔵 永続化しない (起動時常に false)
    var createdAt: Date                 // 🔵 既存実装より
    var updatedAt: Date                 // 🔵 既存実装より

    /// 本文1行目からタイトルを生成 (マークダウン記号を除去、最大50文字 EDGE-103)
    /// 🔵 TabItem.derivedTitle より
    var derivedTitle: String { fatalError("実装は Sources/Models/TabItem.swift 参照") }
}

// MARK: - Notion API レスポンス型
// 🔵 Sources/Models/NotionModels.swift より

/// Notion データベース
/// 🔵 REQ-407 動的タイトルプロパティ名解決より
struct NotionDatabase: Identifiable, Hashable, Sendable {
    let id: String
    let title: [NotionRichTextItem]
    let titlePropertyName: String  // type == "title" のプロパティ名を自動解決 (REQ-407)
    var displayTitle: String       // タイトルを結合・トリム
}

/// Notion ページ (作成/更新レスポンス)
/// 🔵 NotionService.createPage() / updatePageContent() の戻り値
struct NotionPage: Sendable {
    let id: String
    let url: String?
    let createdTime: String
    let lastEditedTime: String
}

/// Notion ページ (ページ一覧用)
/// 🔵 NotionService.fetchPages() の戻り値
struct NotionPageItem: Identifiable, Hashable, Sendable {
    let id: String
    let displayTitle: String
}

/// Notion リッチテキスト要素
/// 🔵 NotionDatabase.title の要素型
struct NotionRichTextItem: Sendable {
    let type: String
    let plainText: String
}

/// Notion ページングレスポンス
/// 🔵 REQ-404 page_size=100 固定（hasMore/nextCursor は使用しない）
struct NotionListResponse<T: Decodable> {
    let results: [T]
    let hasMore: Bool       // 常に false (page_size=100 以内に収める設計)
    let nextCursor: String? // 常に nil (ページネーション未使用)
}

/// Notion ブロック子要素レスポンス
/// 🔵 NotionService.updatePageContent() 内で使用
struct NotionBlockChildrenResponse: Sendable {
    let results: [NotionBlockResult]
}

/// Notion ブロック (ID のみ、削除用)
/// 🔵 REQ-406 全ブロック削除→再追加方式より
struct NotionBlockResult: Sendable {
    let id: String
}

/// Notion API エラー
/// 🔵 EDGE-001 より
struct NotionAPIError: Decodable, Error, LocalizedError, Sendable {
    let object: String
    let status: Int
    let code: String
    let message: String
    var errorDescription: String? { "Notion API Error [\(code)]: \(message)" }
}

// MARK: - サービス層
// 🔵 Sources/Services/NotionService.swift より

/// Notion REST API クライアント (actor)
/// 🔵 REQ-401 Notion-Version: 2022-06-28
/// 🔵 NFR-301 URLSession 注入対応 (Unit Test 用)
actor NotionService {
    // MARK: init

    /// 本番用 init
    /// 🔵 既存実装より
    init(token: String)

    /// テスト用 init (NFR-301)
    /// 🔵 ユーザヒアリング 2026-03-16 Unit Test確認より
    init(token: String, session: URLSession)

    // MARK: Methods
    // fetchDatabases() async throws -> [NotionDatabase]
    // fetchPages()     async throws -> [NotionPageItem]
    // createPage(databaseID:title:titlePropertyName:blocks:) async throws -> NotionPage
    // createSubPage(pageID:title:blocks:)                   async throws -> NotionPage
    // updatePageContent(pageID:title:titlePropertyName:blocks:) async throws -> NotionPage
    // updateToken(_: String)
}

// MARK: - グローバル状態
// 🔵 Sources/App/AppState.swift より

/// @Observable @MainActor グローバル状態
/// 🔵 REQ-002 Single Source of Truth
@MainActor
final class AppState: ObservableObject {
    // MARK: Tabs (REQ-001)
    var tabs: [TabItem]                 // 🔵 全タブリスト
    var activeTabID: UUID?              // 🔵 アクティブタブID
    var sortedTabs: [TabItem]           // 🔵 ピン留め先頭ソート済み (REQ-203)
    var activeTab: TabItem?             // 🔵 activeTabID に対応するタブ

    // MARK: Notion (REQ-403, REQ-404)
    var notionToken: String             // 🔵 Keychain から復元
    var databases: [NotionDatabase]     // 🔵 fetchDatabases() 結果
    var pages: [NotionPageItem]         // 🔵 fetchPages() 結果
    var selectedDatabaseID: String      // 🔵 選択中 DB ID
    var selectedParentPageID: String    // 🔵 選択中 親ページ ID
    var notionSaveTarget: NotionSaveTarget // 🔵 保存先タイプ
    var selectedDatabase: NotionDatabase?  // 🔵 選択中 DB オブジェクト
    var isSyncing: Bool                 // 🔵 同期中フラグ (REQ-201)
    var syncError: String?              // 🔵 エラーメッセージ (NFR-201)

    // MARK: UI
    var tabLayoutMode: TabLayoutMode    // 🔵 横/縦 (REQ-302)
    var autoSaveEnabled: Bool           // 🔵 自動保存 ON/OFF (REQ-301)
    var editorFontSize: CGFloat         // 🔵 10...28, デフォルト 14 (EDGE-104)
    var editorFontName: String          // 🔵 "" = SF Mono (REQ-303)

    // MARK: 既存メソッド
    // addNewTab()                                      🔵 REQ-104
    // closeTab(_ tab: TabItem)                         🔵 REQ-108, EDGE-002, EDGE-003
    // togglePin(_ tab: TabItem)                        🔵 REQ-304
    // updateTitle(_: String, for: UUID)                🔵 REQ-107
    // updateContent(_: String, for: UUID)              🔵
    // markSaved(_: UUID, pageID: String, titlePropertyName: String) 🔵
    // saveTabs()                                       🔵
    // updateNotionToken(_: String)                     🔵 REQ-403
    // syncActiveTab() async                            🔵 REQ-103, REQ-106, REQ-109-112
    // fetchDatabases() async                           🔵
    // fetchPages() async                               🔵

    // MARK: 新規メソッド

    /// タブを D&D で並び替える (REQ-305)
    /// 🔵 ユーザヒアリング 2026-03-16 D&D確認より
    /// - ピン留め ↔ 非ピン留め 間の移動は禁止
    func moveTab(fromOffsets: IndexSet, toOffset: Int)
}

// MARK: - 永続化
// 🔵 Sources/Utilities/PersistenceManager.swift より

/// UserDefaults + Keychain ラッパー
/// 🔵 REQ-403 Keychain 移行 / NFR-302 UserDefaults 注入対応
final class PersistenceManager {
    // MARK: init

    /// 本番用 シングルトン
    /// 🔵 既存実装より
    static let shared: PersistenceManager

    /// 本番用 init (シングルトン経由)
    /// 🔵 既存実装より
    private init()

    /// テスト用 init (NFR-302)
    /// 🔵 ユーザヒアリング 2026-03-16 Unit Test確認より
    init(defaults: UserDefaults)

    // MARK: UserDefaults メソッド (既存)
    func saveTabs(_ tabs: [TabItem])
    func loadTabs() -> [TabItem]
    func saveActiveTabID(_ id: UUID?)
    func loadActiveTabID() -> UUID?
    func saveWindowFrame(_ frame: NSRect)
    func loadWindowFrame() -> NSRect?
    func saveSelectedDatabaseID(_ id: String)
    func loadSelectedDatabaseID() -> String
    func saveSelectedParentPageID(_ id: String)
    func loadSelectedParentPageID() -> String
    func saveNotionSaveTarget(_ target: NotionSaveTarget)
    func loadNotionSaveTarget() -> NotionSaveTarget
    func saveTabLayoutMode(_ mode: TabLayoutMode)
    func loadTabLayoutMode() -> TabLayoutMode
    func saveAutoSaveEnabled(_ enabled: Bool)
    func loadAutoSaveEnabled() -> Bool
    func saveFontSize(_ size: CGFloat)
    func loadFontSize() -> CGFloat  // EDGE-104: 0以下は14ptにフォールバック
    func saveFontName(_ name: String)
    func loadFontName() -> String

    // MARK: Keychain メソッド (新規 REQ-403, NFR-101)
    // 🔵 ユーザヒアリング 2026-03-16 Security.framework直接実装確認より

    /// トークンを Keychain に保存（既存エントリは Delete → Add で上書き）
    /// 🔵 REQ-403
    func saveToken(_ token: String)

    /// トークンを Keychain から読み込む
    /// Keychain になければ UserDefaults を確認し、あれば自動移行する（起動時マイグレーション）
    /// 🔵 REQ-403・ユーザヒアリング 2026-03-16 起動時自動移行確認より
    func loadToken() -> String

    // MARK: Keychain 定数 (private)
    // kSecAttrService = "jp.umi.design.nTabula"
    // kSecAttrAccount = "NotionToken"
    // kSecClass       = kSecClassGenericPassword
}

// MARK: - Markdown 変換
// 🔵 Sources/Utilities/MarkdownToNotion.swift より

/// Markdown String → Notion API ブロック配列
/// 🔵 REQ-004, REQ-405 H4以降はparagraphにフォールバック
enum MarkdownToNotion {
    /// - Parameter markdown: Markdown テキスト
    /// - Returns: Notion API `children` に渡す `[[String: Any]]`
    static func convert(_ markdown: String) -> [[String: Any]] { [] }
}

// MARK: - Notification Name
/// 🔵 nTabulaApp.swift / NTTextView.keyDown より
extension Notification.Name {
    /// Cmd+S / ツールバーの保存ボタン → Notion 同期フロー起動
    static let ntSaveDocument: Notification.Name
}

// MARK: - テスト用型（nTabulaTests ターゲット）
// 🔵 NFR-301, NFR-302, NFR-303 より

/// MockURLProtocol - URLSession をモックするための URLProtocol サブクラス
/// 🔵 ユーザヒアリング 2026-03-16 Unit Test確認より
/// 実装先: nTabulaTests/Mocks/MockURLProtocol.swift
class MockURLProtocol: URLProtocol {
    /// テスト用のレスポンスをクロージャで設定
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { return true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }
    override func startLoading() { /* requestHandler を実行してモックレスポンスを返す */ }
    override func stopLoading() {}
}

// MARK: - 信頼性レベルサマリー
// - 🔵 青信号: 42項目 (98%)
// - 🟡 黄信号: 1項目 (2%)  ← TabItem.databaseID の将来的な使用方針
// - 🔴 赤信号: 0項目 (0%)
//
// 品質評価: ✅ 高品質
