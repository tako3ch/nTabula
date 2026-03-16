import Foundation

enum TabLayoutMode: String, Codable, CaseIterable {
    case horizontal
    case vertical

    var label: String {
        switch self {
        case .horizontal: return "横タブ"
        case .vertical: return "縦タブ"
        }
    }
}

struct TabItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var notionPageID: String?
    var databaseID: String?
    var titlePropertyName: String  // ページ保存時のタイトルプロパティ名（"title" or DBのプロパティ名）
    var isPinned: Bool
    var isDirty: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        notionPageID: String? = nil,
        databaseID: String? = nil,
        titlePropertyName: String = "",
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.notionPageID = notionPageID
        self.databaseID = databaseID
        self.titlePropertyName = titlePropertyName
        self.isPinned = isPinned
        self.isDirty = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // isDirty は常にリセットして復元
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        content = try c.decode(String.self, forKey: .content)
        notionPageID = try c.decodeIfPresent(String.self, forKey: .notionPageID)
        databaseID = try c.decodeIfPresent(String.self, forKey: .databaseID)
        titlePropertyName = try c.decodeIfPresent(String.self, forKey: .titlePropertyName) ?? ""
        isPinned = try c.decode(Bool.self, forKey: .isPinned)
        isDirty = false
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    /// コンテンツの最初の行からタイトルを生成
    var derivedTitle: String {
        let firstLine = content
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        let cleaned = firstLine
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
        return cleaned.isEmpty ? "新規ノート" : String(cleaned.prefix(50))
    }

    static func == (lhs: TabItem, rhs: TabItem) -> Bool { lhs.id == rhs.id }
}
