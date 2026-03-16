import Foundation

/// Markdown テキストを Notion API の children ブロック配列（[[String: Any]]）に変換する
enum MarkdownToNotion {

    // MARK: - Public

    /// Markdown テキスト全体を code ブロック（language: markdown）として返す。
    /// Notion の rich_text は 2000 文字制限があるため、超える場合は複数ブロックに分割する。
    static func convertToMarkdownBlock(_ markdown: String) -> [[String: Any]] {
        guard !markdown.isEmpty else { return [] }
        let limit = 2000
        var blocks: [[String: Any]] = []
        var remaining = markdown
        while !remaining.isEmpty {
            let chunk: String
            if remaining.count <= limit {
                chunk = remaining
                remaining = ""
            } else {
                let idx = remaining.index(remaining.startIndex, offsetBy: limit)
                if let newline = remaining[..<idx].lastIndex(of: "\n") {
                    chunk = String(remaining[...newline])
                    remaining = String(remaining[remaining.index(after: newline)...])
                } else {
                    chunk = String(remaining[..<idx])
                    remaining = String(remaining[idx...])
                }
            }
            blocks.append(codeBlock(chunk, language: "markdown"))
        }
        return blocks
    }

    private static func codeBlock(_ text: String, language: String) -> [String: Any] {
        [
            "object": "block",
            "type": "code",
            "code": ["rich_text": [["type": "text", "text": ["content": text]]], "language": language]
        ]
    }
}
