import XCTest
@testable import nTabula

/// PersistenceManager のテスト
/// テスト間で UserDefaults が汚染されないよう suiteName でサンドボックス化する
final class PersistenceManagerTests: XCTestCase {

    private var sut: PersistenceManager!
    private var testDefaults: UserDefaults!
    private let suiteName = "jp.umi.design.nTabula.tests.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)!
        // Note: PersistenceManager は現状 UserDefaults.standard を直接使用している。
        // テスト用 UserDefaults を注入できるよう init(defaults:) の追加が推奨される。
        // 現時点では標準スイートを使い、tearDown でクリーンアップする。
        sut = PersistenceManager.shared
    }

    override func tearDown() {
        // テスト用キーをクリーンアップ（標準 UserDefaults を汚染しないため）
        let testKeys = [
            "nTabula.tabs",
            "nTabula.activeTabID",
            "nTabula.tabLayoutMode",
            "nTabula.notionSaveTarget",
            "nTabula.selectedDatabaseID",
            "nTabula.selectedParentPageID",
            "nTabula.autoSaveEnabled",
            "nTabula.editorFontSize",
            "nTabula.editorFontName",
            "nTabula.notionToken"
        ]
        for key in testKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        testDefaults.removeSuite(named: suiteName)
        super.tearDown()
    }

    // MARK: - TC-027: タブ保存・復元サイクル

    func test_saveTabs_loadTabs_roundTrip() throws {
        let tab1 = TabItem(
            id: UUID(),
            title: "2026-03-16-1",
            content: "本文1",
            notionPageID: "page-id-1",
            databaseID: "db-id-1",
            titlePropertyName: "Name",
            isPinned: false
        )
        let tab2 = TabItem(
            id: UUID(),
            title: "2026-03-16-2",
            content: "本文2",
            notionPageID: nil,
            databaseID: nil,
            titlePropertyName: "",
            isPinned: true
        )

        sut.saveTabs([tab1, tab2])
        let loaded = sut.loadTabs()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, tab1.id)
        XCTAssertEqual(loaded[0].title, "2026-03-16-1")
        XCTAssertEqual(loaded[0].content, "本文1")
        XCTAssertEqual(loaded[0].notionPageID, "page-id-1")
        XCTAssertEqual(loaded[0].databaseID, "db-id-1")
        XCTAssertEqual(loaded[0].titlePropertyName, "Name")
        XCTAssertFalse(loaded[0].isPinned)

        XCTAssertEqual(loaded[1].id, tab2.id)
        XCTAssertEqual(loaded[1].title, "2026-03-16-2")
        XCTAssertNil(loaded[1].notionPageID)
        XCTAssertTrue(loaded[1].isPinned)
    }

    // MARK: - TC-028: isDirty は常に false で復元

    func test_saveTabs_isDirtyAlwaysFalseOnLoad() {
        var tab = TabItem()
        tab.isDirty = true  // 意図的に dirty にする
        XCTAssertTrue(tab.isDirty)

        sut.saveTabs([tab])
        let loaded = sut.loadTabs()

        XCTAssertFalse(loaded.first?.isDirty == true, "復元時は isDirty が false であること")
    }

    // MARK: - TC-029: 未設定キーのデフォルト値

    func test_loadTabs_returnsEmptyArrayWhenNotSet() {
        UserDefaults.standard.removeObject(forKey: "nTabula.tabs")
        let tabs = sut.loadTabs()
        XCTAssertTrue(tabs.isEmpty)
    }

    func test_loadActiveTabID_returnsNilWhenNotSet() {
        UserDefaults.standard.removeObject(forKey: "nTabula.activeTabID")
        let id = sut.loadActiveTabID()
        XCTAssertNil(id)
    }

    func test_loadToken_returnsEmptyStringWhenNotSet() {
        UserDefaults.standard.removeObject(forKey: "nTabula.notionToken")
        let token = sut.loadToken()
        XCTAssertEqual(token, "")
    }

    func test_loadSelectedDatabaseID_returnsEmptyStringWhenNotSet() {
        UserDefaults.standard.removeObject(forKey: "nTabula.selectedDatabaseID")
        let dbID = sut.loadSelectedDatabaseID()
        XCTAssertEqual(dbID, "")
    }

    func test_loadSelectedParentPageID_returnsEmptyStringWhenNotSet() {
        UserDefaults.standard.removeObject(forKey: "nTabula.selectedParentPageID")
        let pageID = sut.loadSelectedParentPageID()
        XCTAssertEqual(pageID, "")
    }

    func test_loadNotionSaveTarget_defaultsToDatabase() {
        UserDefaults.standard.removeObject(forKey: "nTabula.notionSaveTarget")
        let target = sut.loadNotionSaveTarget()
        XCTAssertEqual(target, .database)
    }

    func test_loadTabLayoutMode_defaultsToHorizontal() {
        UserDefaults.standard.removeObject(forKey: "nTabula.tabLayoutMode")
        let mode = sut.loadTabLayoutMode()
        XCTAssertEqual(mode, .horizontal)
    }

    func test_loadAutoSaveEnabled_defaultsToTrue() {
        UserDefaults.standard.removeObject(forKey: "nTabula.autoSaveEnabled")
        let enabled = sut.loadAutoSaveEnabled()
        XCTAssertTrue(enabled)
    }

    func test_loadFontSize_defaultsTo14() {
        UserDefaults.standard.removeObject(forKey: "nTabula.editorFontSize")
        let size = sut.loadFontSize()
        XCTAssertEqual(size, 14)
    }

    func test_loadFontName_returnsEmptyStringWhenNotSet() {
        UserDefaults.standard.removeObject(forKey: "nTabula.editorFontName")
        let name = sut.loadFontName()
        XCTAssertEqual(name, "")
    }

    // MARK: - 個別プロパティの保存・復元

    func test_saveAndLoad_activeTabID() {
        let id = UUID()
        sut.saveActiveTabID(id)
        XCTAssertEqual(sut.loadActiveTabID(), id)
    }

    func test_saveAndLoad_activeTabID_nil() {
        sut.saveActiveTabID(UUID())  // 先に書き込む
        sut.saveActiveTabID(nil)
        XCTAssertNil(sut.loadActiveTabID())
    }

    func test_saveAndLoad_token() {
        sut.saveToken("secret-token-xyz")
        XCTAssertEqual(sut.loadToken(), "secret-token-xyz")
    }

    func test_saveAndLoad_selectedDatabaseID() {
        sut.saveSelectedDatabaseID("db-abc-123")
        XCTAssertEqual(sut.loadSelectedDatabaseID(), "db-abc-123")
    }

    func test_saveAndLoad_selectedParentPageID() {
        sut.saveSelectedParentPageID("page-xyz-456")
        XCTAssertEqual(sut.loadSelectedParentPageID(), "page-xyz-456")
    }

    func test_saveAndLoad_notionSaveTarget_page() {
        sut.saveNotionSaveTarget(.page)
        XCTAssertEqual(sut.loadNotionSaveTarget(), .page)
    }

    func test_saveAndLoad_tabLayoutMode_vertical() {
        sut.saveTabLayoutMode(.vertical)
        XCTAssertEqual(sut.loadTabLayoutMode(), .vertical)
    }

    func test_saveAndLoad_autoSaveEnabled_false() {
        sut.saveAutoSaveEnabled(false)
        XCTAssertFalse(sut.loadAutoSaveEnabled())
    }

    func test_saveAndLoad_fontSize() {
        sut.saveFontSize(20.0)
        XCTAssertEqual(sut.loadFontSize(), 20.0, accuracy: 0.001)
    }

    func test_saveAndLoad_fontName() {
        sut.saveFontName("Monaco")
        XCTAssertEqual(sut.loadFontName(), "Monaco")
    }

    // MARK: - 空タブリスト

    func test_saveEmptyTabs_loadReturnsEmpty() {
        sut.saveTabs([])
        let loaded = sut.loadTabs()
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - 大量タブの保存

    func test_saveManyTabs_roundTrip() {
        let tabs = (1...50).map { i -> TabItem in
            TabItem(
                id: UUID(),
                title: "タブ\(i)",
                content: String(repeating: "本文", count: 100),
                notionPageID: i % 2 == 0 ? "page-\(i)" : nil,
                databaseID: nil,
                titlePropertyName: "Name",
                isPinned: false
            )
        }
        sut.saveTabs(tabs)
        let loaded = sut.loadTabs()

        XCTAssertEqual(loaded.count, 50)
        XCTAssertEqual(loaded[0].title, "タブ1")
        XCTAssertEqual(loaded[49].title, "タブ50")
    }
}
