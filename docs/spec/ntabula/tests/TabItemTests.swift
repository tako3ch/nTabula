import XCTest
@testable import nTabula

final class TabItemTests: XCTestCase {

    // MARK: - TC-011: Codable エンコード

    func test_tabItem_encodesAllFields() throws {
        let tab = TabItem(
            id: UUID(),
            title: "テストタイトル",
            content: "本文",
            notionPageID: "page-123",
            databaseID: "db-456",
            titlePropertyName: "Name",
            isPinned: true
        )
        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(TabItem.self, from: data)

        XCTAssertEqual(decoded.id, tab.id)
        XCTAssertEqual(decoded.title, "テストタイトル")
        XCTAssertEqual(decoded.content, "本文")
        XCTAssertEqual(decoded.notionPageID, "page-123")
        XCTAssertEqual(decoded.databaseID, "db-456")
        XCTAssertEqual(decoded.titlePropertyName, "Name")
        XCTAssertEqual(decoded.isPinned, true)
    }

    // MARK: - TC-012: isDirty は復元時 false

    func test_tabItem_isDirtyAlwaysFalseOnDecode() throws {
        var tab = TabItem()
        tab.isDirty = true
        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(TabItem.self, from: data)
        XCTAssertFalse(decoded.isDirty)
    }

    // MARK: - TC-013: titlePropertyName デフォルト値

    func test_tabItem_titlePropertyNameDefaultsToEmpty() {
        let tab = TabItem()
        XCTAssertEqual(tab.titlePropertyName, "")
    }

    // MARK: - TC-013: 旧データ（titlePropertyName なし）の後方互換性

    func test_tabItem_decodesLegacyDataWithoutTitlePropertyName() throws {
        // titlePropertyName フィールドがない旧データ
        let legacyJSON = """
        {
            "id": "\(UUID().uuidString)",
            "title": "旧タブ",
            "content": "本文",
            "isPinned": false,
            "createdAt": 0.0,
            "updatedAt": 0.0
        }
        """.data(using: .utf8)!
        let tab = try JSONDecoder().decode(TabItem.self, from: legacyJSON)
        // フォールバック: 空文字
        XCTAssertEqual(tab.titlePropertyName, "")
    }

    // MARK: - TC-041: derivedTitle H1記法を除去

    func test_derivedTitle_removesH1Prefix() {
        var tab = TabItem()
        tab.content = "# 見出しタイトル\n本文"
        XCTAssertEqual(tab.derivedTitle, "見出しタイトル")
    }

    func test_derivedTitle_removesH3Prefix() {
        var tab = TabItem()
        tab.content = "### セクション\n本文"
        XCTAssertEqual(tab.derivedTitle, "セクション")
    }

    // MARK: - TC-042: derivedTitle 50文字上限

    func test_derivedTitle_truncatesTo50Chars() {
        var tab = TabItem()
        tab.content = String(repeating: "あ", count: 60)
        XCTAssertEqual(tab.derivedTitle.count, 50)
    }

    func test_derivedTitle_usesFirstNonEmptyLine() {
        var tab = TabItem()
        tab.content = "\n\n有効な行\n次の行"
        XCTAssertEqual(tab.derivedTitle, "有効な行")
    }

    func test_derivedTitle_emptyContentReturnsDefault() {
        let tab = TabItem()
        XCTAssertEqual(tab.derivedTitle, "新規ノート")
    }

    // MARK: - TC-049: TabLayoutMode rawValue

    func test_tabLayoutMode_rawValues() {
        XCTAssertEqual(TabLayoutMode.horizontal.rawValue, "horizontal")
        XCTAssertEqual(TabLayoutMode.vertical.rawValue, "vertical")
    }

    func test_tabLayoutMode_initFromRawValue() {
        XCTAssertEqual(TabLayoutMode(rawValue: "horizontal"), .horizontal)
        XCTAssertEqual(TabLayoutMode(rawValue: "vertical"), .vertical)
        XCTAssertNil(TabLayoutMode(rawValue: "invalid"))
    }

    // MARK: - TC-048: NotionSaveTarget rawValue

    func test_notionSaveTarget_rawValues() {
        XCTAssertEqual(NotionSaveTarget.database.rawValue, "database")
        XCTAssertEqual(NotionSaveTarget.page.rawValue, "page")
    }
}
