import XCTest
@testable import nTabula

/// AppState のユニットテスト
/// Note: @Observable @MainActor のため、MainActor context で実行する
@MainActor
final class AppStateTests: XCTestCase {

    private var sut: AppState!

    override func setUp() async throws {
        // UserDefaults を分離するためサンドボックス用スイートを使用
        // 実際のテストターゲットでは AppState の init を
        // テスト用 UserDefaults を注入できるよう修正が必要
        sut = AppState()
        // 既存タブをクリア
        sut.tabs.removeAll()
    }

    // MARK: - TC-018: addNewTab デフォルトタイトル生成

    func test_addNewTab_generatesDateBasedTitle() {
        sut.addNewTab()
        guard let tab = sut.tabs.last else { return XCTFail("タブが作成されていない") }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())

        XCTAssertTrue(tab.title.hasPrefix(dateStr), "タイトルが日付で始まること: \(tab.title)")
        XCTAssertTrue(tab.title.hasSuffix("-1"), "初回は -1 で終わること: \(tab.title)")
    }

    // MARK: - TC-019: 連番生成

    func test_addNewTab_incrementsCounterForSameDay() {
        sut.addNewTab()
        sut.addNewTab()
        sut.addNewTab()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())

        XCTAssertEqual(sut.tabs[0].title, "\(dateStr)-1")
        XCTAssertEqual(sut.tabs[1].title, "\(dateStr)-2")
        XCTAssertEqual(sut.tabs[2].title, "\(dateStr)-3")
    }

    // MARK: - TC-020: closeTab activeTab 移動

    func test_closeTab_movesActiveTabToPreviousTab() {
        sut.addNewTab() // A
        sut.addNewTab() // B
        sut.addNewTab() // C

        let tabB = sut.tabs[1]
        sut.activeTabID = tabB.id
        sut.closeTab(tabB)

        XCTAssertEqual(sut.tabs.count, 2)
        XCTAssertFalse(sut.tabs.contains(tabB))
        // B を閉じたら A (直前) がアクティブに
        XCTAssertEqual(sut.activeTabID, sut.tabs[0].id)
    }

    func test_closeTab_lastTab_activeTabBecomesNilOrRemaining() {
        sut.addNewTab()
        let tab = sut.tabs[0]
        sut.activeTabID = tab.id
        sut.closeTab(tab)

        // タブが 0 になった場合
        if sut.tabs.isEmpty {
            XCTAssertNil(sut.activeTabID)
        }
    }

    // MARK: - TC-021: ピン留めタブは閉じ不可

    func test_closeTab_pinnedTabIsNotClosed() {
        sut.addNewTab()
        var tab = sut.tabs[0]
        tab.isPinned = true
        sut.tabs[0] = tab

        sut.closeTab(sut.tabs[0])
        XCTAssertEqual(sut.tabs.count, 1, "ピン留めタブは閉じられないこと")
    }

    // MARK: - TC-022: sortedTabs ピン留め先頭

    func test_sortedTabs_pinnedTabsFirst() {
        sut.addNewTab() // 通常
        sut.addNewTab() // 通常
        sut.addNewTab() // ピン留め予定

        sut.togglePin(sut.tabs[2])

        XCTAssertTrue(sut.sortedTabs[0].isPinned, "先頭がピン留めであること")
    }

    // MARK: - TC-023: syncActiveTab isDirty=false + notionPageID あり → スキップ

    func test_syncActiveTab_skipsWhenNotDirtyAndHasPageID() async {
        sut.addNewTab()
        guard let idx = sut.tabs.indices.first else { return XCTFail() }
        sut.tabs[idx].isDirty = false
        sut.tabs[idx].notionPageID = "existing-page-id"
        sut.activeTabID = sut.tabs[idx].id

        // 保存前の状態
        let initialSyncError = sut.syncError

        await sut.syncActiveTab()

        // isSyncing が動いていない (スキップされた) こと
        XCTAssertFalse(sut.isSyncing)
        // エラーが変化していないこと
        XCTAssertEqual(sut.syncError, initialSyncError)
    }

    // MARK: - TC-024: syncActiveTab notionPageID=nil は実行される

    func test_syncActiveTab_executesWhenNoPageID() async {
        sut.addNewTab()
        guard let idx = sut.tabs.indices.first else { return XCTFail() }
        sut.tabs[idx].isDirty = false
        sut.tabs[idx].notionPageID = nil  // 未保存
        sut.activeTabID = sut.tabs[idx].id
        // 保存先未設定なのでエラーになるはず (スキップはされない)
        sut.selectedDatabaseID = ""
        sut.notionSaveTarget = .database

        await sut.syncActiveTab()

        // "データベースが未選択です" のエラーが出ること = 実行は試みた
        XCTAssertNotNil(sut.syncError)
    }

    // MARK: - TC-025: hasValidSaveTarget (.database)

    func test_hasValidSaveTarget_databaseMode_trueWhenDBSelected() {
        sut.notionSaveTarget = .database
        sut.selectedDatabaseID = "some-db-id"
        XCTAssertTrue(sut.hasValidSaveTarget)
    }

    func test_hasValidSaveTarget_databaseMode_falseWhenNoDB() {
        sut.notionSaveTarget = .database
        sut.selectedDatabaseID = ""
        XCTAssertFalse(sut.hasValidSaveTarget)
    }

    // MARK: - TC-026: hasValidSaveTarget (.page)

    func test_hasValidSaveTarget_pageMode_trueWhenPageSelected() {
        sut.notionSaveTarget = .page
        sut.selectedParentPageID = "some-page-id"
        XCTAssertTrue(sut.hasValidSaveTarget)
    }

    func test_hasValidSaveTarget_pageMode_falseWhenNoPage() {
        sut.notionSaveTarget = .page
        sut.selectedParentPageID = ""
        XCTAssertFalse(sut.hasValidSaveTarget)
    }

    // MARK: - TC-043: updateContent isDirty 設定

    func test_updateContent_setsDirty() {
        sut.addNewTab()
        guard let tab = sut.tabs.first else { return XCTFail() }
        XCTAssertFalse(tab.isDirty)

        sut.updateContent("新しい内容", for: tab.id)

        XCTAssertTrue(sut.tabs.first?.isDirty == true)
        XCTAssertEqual(sut.tabs.first?.content, "新しい内容")
    }

    // MARK: - TC-044: markSaved titlePropertyName 保存

    func test_markSaved_storesTitlePropertyName() {
        sut.addNewTab()
        guard let tab = sut.tabs.first else { return XCTFail() }

        sut.markSaved(tab.id, pageID: "page-id", titlePropertyName: "タイトル")

        XCTAssertEqual(sut.tabs.first?.notionPageID, "page-id")
        XCTAssertEqual(sut.tabs.first?.titlePropertyName, "タイトル")
        XCTAssertFalse(sut.tabs.first?.isDirty == true)
    }

    // MARK: - TC-045: togglePin

    func test_togglePin_togglesIsPinned() {
        sut.addNewTab()
        let tab = sut.tabs[0]
        XCTAssertFalse(tab.isPinned)

        sut.togglePin(tab)
        XCTAssertTrue(sut.tabs[0].isPinned)

        sut.togglePin(sut.tabs[0])
        XCTAssertFalse(sut.tabs[0].isPinned)
    }
}
