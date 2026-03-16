import Foundation

// MARK: - Database

struct NotionDatabase: Identifiable, Hashable, Sendable {
    let id: String
    let title: [NotionRichTextItem]
    let titlePropertyName: String  // DBのタイトルプロパティ名（"Name", "タイトル" など）

    var displayTitle: String {
        let joined = title.map(\.plainText).joined().trimmingCharacters(in: .whitespaces)
        return joined.isEmpty ? "Untitled" : joined
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: NotionDatabase, rhs: NotionDatabase) -> Bool { lhs.id == rhs.id }
}

extension NotionDatabase: Decodable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode([NotionRichTextItem].self, forKey: .title)
        // properties から type == "title" のプロパティ名を動的に取得
        if let props = try? container.decode([String: _NotionPropertyTypeMeta].self, forKey: .properties),
           let name = props.first(where: { $0.value.type == "title" })?.key {
            self.titlePropertyName = name
        } else {
            self.titlePropertyName = "Name"
        }
    }
    private enum CodingKeys: String, CodingKey { case id, title, properties }
}

private struct _NotionPropertyTypeMeta: Decodable {
    let type: String
}

// MARK: - Page Item（ページ一覧用）

struct NotionPageItem: Identifiable, Hashable, Sendable {
    let id: String
    let displayTitle: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: NotionPageItem, rhs: NotionPageItem) -> Bool { lhs.id == rhs.id }
}

extension NotionPageItem: Decodable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        let props = try? container.decode([String: _NotionTitlePropValue].self, forKey: .properties)
        let texts = props?.values.first(where: { !$0.titleTexts.isEmpty })?.titleTexts
        self.displayTitle = texts?.map(\.plainText).joined() ?? "Untitled"
    }
    private enum CodingKeys: String, CodingKey { case id, properties }
}

private struct _NotionTitlePropValue: Decodable, Sendable {
    let titleTexts: [NotionRichTextItem]
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        titleTexts = (try? c.decode([NotionRichTextItem].self, forKey: .title)) ?? []
    }
    private enum CodingKeys: String, CodingKey { case title }
}

// MARK: - Page

struct NotionPage: Sendable {
    let id: String
    let url: String?
    let createdTime: String
    let lastEditedTime: String
}

extension NotionPage: Decodable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.createdTime = try container.decode(String.self, forKey: .createdTime)
        self.lastEditedTime = try container.decode(String.self, forKey: .lastEditedTime)
    }
    private enum CodingKeys: String, CodingKey {
        case id, url, createdTime, lastEditedTime
    }
}

// MARK: - Rich Text

struct NotionRichTextItem: Sendable {
    let type: String
    let plainText: String
}

extension NotionRichTextItem: Decodable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.plainText = try container.decode(String.self, forKey: .plainText)
    }
    private enum CodingKeys: String, CodingKey { case type, plainText }
}

// MARK: - List Response

struct NotionListResponse<T: Decodable> {
    nonisolated(unsafe) let results: [T]
    let hasMore: Bool
    let nextCursor: String?
}

extension NotionListResponse: Decodable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decode([T].self, forKey: .results)
        hasMore = try container.decode(Bool.self, forKey: .hasMore)
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    }
    private enum CodingKeys: String, CodingKey { case results, hasMore, nextCursor }
}

extension NotionListResponse: Sendable where T: Sendable {}

// MARK: - Block Children

struct NotionBlockChildrenResponse: Sendable {
    let results: [NotionBlockResult]
}

extension NotionBlockChildrenResponse: Decodable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decode([NotionBlockResult].self, forKey: .results)
    }
    private enum CodingKeys: String, CodingKey { case results }
}

struct NotionBlockResult: Sendable {
    let id: String
}

extension NotionBlockResult: Decodable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
    }
    private enum CodingKeys: String, CodingKey { case id }
}

// MARK: - API Error

struct NotionAPIError: Decodable, Error, LocalizedError, Sendable {
    let object: String
    let status: Int
    let code: String
    let message: String

    var errorDescription: String? { "Notion API Error [\(code)]: \(message)" }
}
