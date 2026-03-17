import XCTest
@testable import nTabula

final class NotionModelsTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - TC-014: NotionDatabase titlePropertyName 自動抽出（英語）

    func test_notionDatabase_extractsNamePropertyName() throws {
        let json = """
        {
            "id": "test-db-id",
            "title": [{ "type": "text", "plain_text": "テストDB" }],
            "properties": {
                "Name": { "type": "title", "id": "title", "title": {} }
            }
        }
        """.data(using: .utf8)!
        let db = try decoder.decode(NotionDatabase.self, from: json)
        XCTAssertEqual(db.titlePropertyName, "Name")
    }

    // MARK: - TC-015: 日本語プロパティ名抽出

    func test_notionDatabase_extractsJapanesePropertyName() throws {
        let json = """
        {
            "id": "test-db-id",
            "title": [{ "type": "text", "plain_text": "日本語DB" }],
            "properties": {
                "タイトル": { "type": "title", "id": "title", "title": {} },
                "タグ": { "type": "multi_select", "multi_select": {} }
            }
        }
        """.data(using: .utf8)!
        let db = try decoder.decode(NotionDatabase.self, from: json)
        XCTAssertEqual(db.titlePropertyName, "タイトル")
    }

    // MARK: - TC-016: titlePropertyName フォールバック

    func test_notionDatabase_fallbacksToNameWhenNoProperties() throws {
        let json = """
        {
            "id": "test-db-id",
            "title": []
        }
        """.data(using: .utf8)!
        let db = try decoder.decode(NotionDatabase.self, from: json)
        XCTAssertEqual(db.titlePropertyName, "Name")
    }

    func test_notionDatabase_fallbacksToNameWhenNoTitleProperty() throws {
        let json = """
        {
            "id": "test-db-id",
            "title": [{ "type": "text", "plain_text": "DB" }],
            "properties": {
                "タグ": { "type": "multi_select", "multi_select": {} }
            }
        }
        """.data(using: .utf8)!
        let db = try decoder.decode(NotionDatabase.self, from: json)
        XCTAssertEqual(db.titlePropertyName, "Name")
    }

    // MARK: - displayTitle

    func test_notionDatabase_displayTitle_joinsRichText() throws {
        let json = """
        {
            "id": "test-id",
            "title": [
                { "type": "text", "plain_text": "My " },
                { "type": "text", "plain_text": "Database" }
            ]
        }
        """.data(using: .utf8)!
        let db = try decoder.decode(NotionDatabase.self, from: json)
        XCTAssertEqual(db.displayTitle, "My Database")
    }

    func test_notionDatabase_displayTitle_emptyReturnsUntitled() throws {
        let json = """
        { "id": "test-id", "title": [] }
        """.data(using: .utf8)!
        let db = try decoder.decode(NotionDatabase.self, from: json)
        XCTAssertEqual(db.displayTitle, "Untitled")
    }

    // MARK: - TC-017: NotionAPIError デコード

    func test_notionAPIError_decodesCorrectly() throws {
        let json = """
        {
            "object": "error",
            "status": 400,
            "code": "validation_error",
            "message": "Name is not a property that exists."
        }
        """.data(using: .utf8)!
        let error = try decoder.decode(NotionAPIError.self, from: json)
        XCTAssertEqual(error.status, 400)
        XCTAssertEqual(error.code, "validation_error")
        XCTAssertEqual(error.errorDescription, "Notion API Error [validation_error]: Name is not a property that exists.")
    }

    // MARK: - TC-046: NotionListResponse

    func test_notionListResponse_decodesHasMore() throws {
        let json = """
        {
            "results": [],
            "has_more": true,
            "next_cursor": "cursor-123"
        }
        """.data(using: .utf8)!
        let response = try decoder.decode(NotionListResponse<NotionDatabase>.self, from: json)
        XCTAssertTrue(response.hasMore)
        XCTAssertEqual(response.nextCursor, "cursor-123")
        XCTAssertTrue(response.results.isEmpty)
    }
}
