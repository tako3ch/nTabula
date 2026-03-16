import SwiftUI
import Observation

enum NotionSaveTarget: String, Codable {
    case database
    case page
}

@Observable
@MainActor
final class AppState {

    // MARK: - Tabs

    var tabs: [TabItem] = []
    var activeTabID: UUID?

    // MARK: - Notion

    var notionToken: String = ""
    var databases: [NotionDatabase] = []
    var pages: [NotionPageItem] = []
    var selectedDatabaseID: String = ""
    var selectedParentPageID: String = ""
    var notionSaveTarget: NotionSaveTarget = .database
    var isSyncing: Bool = false
    var syncError: String? = nil

    // MARK: - UI

    var tabLayoutMode: TabLayoutMode = .horizontal
    var autoSaveEnabled: Bool = true
    var editorFontSize: CGFloat = 14
    var editorFontName: String = ""
    var isPreviewVisible: Bool = false

    // MARK: - Notion Service

    private(set) var notionService: NotionService

    // MARK: - Init

    init() {
        let pm = PersistenceManager.shared
        let token = pm.loadToken()
        notionService = NotionService(token: token)

        notionToken = token
        tabs = pm.loadTabs()
        activeTabID = pm.loadActiveTabID() ?? tabs.first?.id
        selectedDatabaseID = pm.loadSelectedDatabaseID()
        selectedParentPageID = pm.loadSelectedParentPageID()
        notionSaveTarget = pm.loadNotionSaveTarget()
        tabLayoutMode = pm.loadTabLayoutMode()
        autoSaveEnabled = pm.loadAutoSaveEnabled()
        editorFontSize = pm.loadFontSize()
        editorFontName = pm.loadFontName()

        if tabs.isEmpty { addNewTab() }
    }

    // MARK: - Computed

    var activeTab: TabItem? {
        get { tabs.first(where: { $0.id == activeTabID }) }
        set {
            if let newTab = newValue,
               let idx = tabs.firstIndex(where: { $0.id == newTab.id }) {
                tabs[idx] = newTab
            }
        }
    }

    var selectedDatabase: NotionDatabase? {
        databases.first(where: { $0.id == selectedDatabaseID })
    }

    var hasValidSaveTarget: Bool {
        switch notionSaveTarget {
        case .database: return !selectedDatabaseID.isEmpty
        case .page:     return !selectedParentPageID.isEmpty
        }
    }

    /// ピン留めタブを先頭にしたソート済みリスト
    var sortedTabs: [TabItem] {
        tabs.filter(\.isPinned) + tabs.filter({ !$0.isPinned })
    }

    // MARK: - Tab Management

    func addNewTab() {
        var tab = TabItem()
        tab.title = generateDefaultTitle()
        tab.databaseID = selectedDatabaseID.isEmpty ? nil : selectedDatabaseID
        tabs.append(tab)
        activeTabID = tab.id
        saveTabs()
    }

    private func generateDefaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        let count = tabs.filter { $0.title.hasPrefix(dateStr) }.count
        return "\(dateStr)-\(count + 1)"
    }

    func updateTitle(_ title: String, for tabID: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[idx].title = title
        tabs[idx].isDirty = true
        saveTabs()
    }

    // MARK: - Recently Closed Tabs

    /// 最近閉じたタブのスタック（最大10件）。Cmd+Shift+N で復元できる。
    private(set) var recentlyClosedTabs: [TabItem] = []

    var canRestoreTab: Bool { !recentlyClosedTabs.isEmpty }

    func closeTab(_ tab: TabItem) {
        guard !tab.isPinned else { return }
        let idx = tabs.firstIndex(of: tab)
        // 最近閉じたタブに追加（最大10件）
        recentlyClosedTabs.append(tab)
        if recentlyClosedTabs.count > 10 { recentlyClosedTabs.removeFirst() }
        tabs.removeAll { $0.id == tab.id }
        if activeTabID == tab.id {
            if let idx {
                let newIdx = max(0, idx - 1)
                activeTabID = tabs.isEmpty ? nil : tabs[min(newIdx, tabs.count - 1)].id
            } else {
                activeTabID = tabs.last?.id
            }
        }
        saveTabs()
    }

    func restoreLastClosedTab() {
        guard let tab = recentlyClosedTabs.popLast() else { return }
        tabs.append(tab)
        activeTabID = tab.id
        saveTabs()
    }

    func updateContent(_ content: String, for tabID: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[idx].content = content
        tabs[idx].isDirty = true
        tabs[idx].updatedAt = Date()
    }

    func togglePin(_ tab: TabItem) {
        guard let idx = tabs.firstIndex(of: tab) else { return }
        tabs[idx].isPinned.toggle()
        saveTabs()
    }

    /// sortedTabs の index 番目のタブに切り替える（0-based）
    func switchToTab(at index: Int) {
        guard index < sortedTabs.count else { return }
        activeTabID = sortedTabs[index].id
    }

    /// ピン留め状態が同じタブ間でのみ並び替えを許可する
    func moveTab(from sourceID: UUID, to destinationID: UUID) {
        guard sourceID != destinationID,
              let srcIdx = tabs.firstIndex(where: { $0.id == sourceID }),
              let dstIdx = tabs.firstIndex(where: { $0.id == destinationID }),
              tabs[srcIdx].isPinned == tabs[dstIdx].isPinned
        else { return }
        tabs.move(fromOffsets: IndexSet(integer: srcIdx), toOffset: dstIdx > srcIdx ? dstIdx + 1 : dstIdx)
        saveTabs()
    }

    func saveTabs() {
        PersistenceManager.shared.saveTabs(tabs)
        PersistenceManager.shared.saveActiveTabID(activeTabID)
    }

    func markSaved(_ tabID: UUID, pageID: String, titlePropertyName: String) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[idx].isDirty = false
        tabs[idx].notionPageID = pageID
        tabs[idx].titlePropertyName = titlePropertyName
        saveTabs()
    }

    // MARK: - Notion Token

    func updateNotionToken(_ token: String) {
        notionToken = token
        PersistenceManager.shared.saveToken(token)
        Task { await notionService.updateToken(token) }
    }

    // MARK: - Notion Sync

    func syncActiveTab() async {
        guard let tab = activeTab else { return }
        // 変更なし & 既に Notion に保存済みならスキップ
        guard tab.isDirty || tab.notionPageID == nil else { return }

        isSyncing = true
        syncError = nil

        do {
            let blocks = MarkdownToNotion.convertToMarkdownBlock(tab.content)
            let title = tab.title.isEmpty ? "Untitled" : tab.title
            let page: NotionPage
            let usedTitlePropertyName: String

            if let pageID = tab.notionPageID {
                // 既存ページ更新: タブに保存されたプロパティ名を優先、なければ現在のモードから推定
                let propName: String
                if !tab.titlePropertyName.isEmpty {
                    propName = tab.titlePropertyName
                } else if notionSaveTarget == .page {
                    propName = "title"
                } else {
                    propName = selectedDatabase?.titlePropertyName ?? "Name"
                }
                page = try await notionService.updatePageContent(
                    pageID: pageID, title: title, titlePropertyName: propName, blocks: blocks
                )
                usedTitlePropertyName = propName
            } else if notionSaveTarget == .page && !selectedParentPageID.isEmpty {
                // ページの子として新規作成
                page = try await notionService.createSubPage(
                    pageID: selectedParentPageID, title: title, blocks: blocks
                )
                usedTitlePropertyName = "title"
            } else {
                guard !selectedDatabaseID.isEmpty else {
                    syncError = "データベースが未選択です"
                    isSyncing = false
                    return
                }
                let propName = selectedDatabase?.titlePropertyName ?? "Name"
                page = try await notionService.createPage(
                    databaseID: selectedDatabaseID, title: title, titlePropertyName: propName, blocks: blocks
                )
                usedTitlePropertyName = propName
            }
            markSaved(tab.id, pageID: page.id, titlePropertyName: usedTitlePropertyName)
        } catch {
            syncError = error.localizedDescription
        }

        isSyncing = false
    }

    func fetchDatabases() async {
        do {
            databases = try await notionService.fetchDatabases()
        } catch {
            syncError = error.localizedDescription
        }
    }

    func fetchPages() async {
        do {
            pages = try await notionService.fetchPages()
        } catch {
            syncError = error.localizedDescription
        }
    }
}
