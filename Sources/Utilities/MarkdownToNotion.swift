import Foundation

/// Markdown テキストを Notion API の children ブロック配列（[[String: Any]]）に変換する
enum MarkdownToNotion {

    // MARK: - Public

    static func convert(_ markdown: String) -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        let lines = markdown.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // フェンスコードブロック
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                let code = codeLines.joined(separator: "\n")
                blocks.append(codeBlock(code, language: lang.isEmpty ? "plain text" : lang))
                i += 1 // closing ``` をスキップ
                continue
            }

            if let block = parseLine(line) {
                blocks.append(block)
            }
            i += 1
        }

        return blocks
    }

    // MARK: - Line Parser

    private static func parseLine(_ line: String) -> [String: Any]? {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        if line.hasPrefix("### ") {
            return block("heading_3", richText: parseInline(String(line.dropFirst(4))))
        }
        if line.hasPrefix("## ") {
            return block("heading_2", richText: parseInline(String(line.dropFirst(3))))
        }
        if line.hasPrefix("# ") {
            return block("heading_1", richText: parseInline(String(line.dropFirst(2))))
        }
        if line.hasPrefix("> ") {
            return block("quote", richText: parseInline(String(line.dropFirst(2))))
        }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            return ["object": "block", "type": "divider", "divider": [:] as [String: Any]]
        }

        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            let text = String(line.dropFirst(2))
            if text.hasPrefix("[ ] ") {
                return todoBlock(parseInline(String(text.dropFirst(4))), checked: false)
            }
            if text.lowercased().hasPrefix("[x] ") {
                return todoBlock(parseInline(String(text.dropFirst(4))), checked: true)
            }
            return block("bulleted_list_item", richText: parseInline(text))
        }

        if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            return block("numbered_list_item", richText: parseInline(String(line[match.upperBound...])))
        }

        return block("paragraph", richText: parseInline(line))
    }

    // MARK: - Block Builders

    private static func block(_ type: String, richText: [[String: Any]]) -> [String: Any] {
        ["object": "block", "type": type, type: ["rich_text": richText]]
    }

    private static func codeBlock(_ text: String, language: String) -> [String: Any] {
        [
            "object": "block",
            "type": "code",
            "code": ["rich_text": [plainRT(text)], "language": language]
        ]
    }

    private static func todoBlock(_ richText: [[String: Any]], checked: Bool) -> [String: Any] {
        [
            "object": "block",
            "type": "to_do",
            "to_do": ["rich_text": richText, "checked": checked]
        ]
    }

    // MARK: - Inline Parser

    static func parseInline(_ text: String) -> [[String: Any]] {
        var result: [[String: Any]] = []
        var current = ""
        var idx = text.startIndex

        while idx < text.endIndex {
            // Bold **text**
            if text[idx...].hasPrefix("**") {
                let start = text.index(idx, offsetBy: 2)
                if let end = text.range(of: "**", range: start..<text.endIndex) {
                    flush(&current, into: &result)
                    result.append(styledRT(String(text[start..<end.lowerBound]), bold: true))
                    idx = end.upperBound
                    continue
                }
            }
            // Bold __text__
            if text[idx...].hasPrefix("__") {
                let start = text.index(idx, offsetBy: 2)
                if let end = text.range(of: "__", range: start..<text.endIndex) {
                    flush(&current, into: &result)
                    result.append(styledRT(String(text[start..<end.lowerBound]), bold: true))
                    idx = end.upperBound
                    continue
                }
            }
            // Italic *text* (** でない場合)
            if text[idx...].hasPrefix("*") && !text[idx...].hasPrefix("**") {
                let start = text.index(idx, offsetBy: 1)
                if let endIdx = findSingleMarker(text, marker: "*", from: start) {
                    flush(&current, into: &result)
                    result.append(styledRT(String(text[start..<endIdx]), italic: true))
                    idx = text.index(endIdx, offsetBy: 1)
                    continue
                }
            }
            // Inline code `text`
            if text[idx...].hasPrefix("`") {
                let start = text.index(idx, offsetBy: 1)
                if let end = text.range(of: "`", range: start..<text.endIndex) {
                    flush(&current, into: &result)
                    result.append(styledRT(String(text[start..<end.lowerBound]), code: true))
                    idx = end.upperBound
                    continue
                }
            }
            // Strikethrough ~~text~~
            if text[idx...].hasPrefix("~~") {
                let start = text.index(idx, offsetBy: 2)
                if let end = text.range(of: "~~", range: start..<text.endIndex) {
                    flush(&current, into: &result)
                    result.append(styledRT(String(text[start..<end.lowerBound]), strikethrough: true))
                    idx = end.upperBound
                    continue
                }
            }
            // Link [text](url)
            if text[idx...].hasPrefix("["), let link = parseLink(text, from: idx) {
                flush(&current, into: &result)
                result.append(linkRT(link.text, url: link.url))
                idx = link.end
                continue
            }

            current.append(text[idx])
            idx = text.index(after: idx)
        }

        flush(&current, into: &result)
        return result.isEmpty ? [plainRT(text)] : result
    }

    // MARK: - Rich Text Helpers

    private static func plainRT(_ content: String) -> [String: Any] {
        ["type": "text", "text": ["content": content], "annotations": defaultAnnotations()]
    }

    private static func styledRT(
        _ content: String,
        bold: Bool = false,
        italic: Bool = false,
        code: Bool = false,
        strikethrough: Bool = false
    ) -> [String: Any] {
        [
            "type": "text",
            "text": ["content": content],
            "annotations": [
                "bold": bold, "italic": italic,
                "strikethrough": strikethrough, "underline": false,
                "code": code, "color": "default"
            ]
        ]
    }

    private static func linkRT(_ content: String, url: String) -> [String: Any] {
        [
            "type": "text",
            "text": ["content": content, "link": ["url": url]],
            "annotations": defaultAnnotations()
        ]
    }

    private static func defaultAnnotations() -> [String: Any] {
        ["bold": false, "italic": false, "strikethrough": false,
         "underline": false, "code": false, "color": "default"]
    }

    private static func flush(_ current: inout String, into result: inout [[String: Any]]) {
        guard !current.isEmpty else { return }
        result.append(plainRT(current))
        current = ""
    }

    // MARK: - String Helpers

    private static func findSingleMarker(_ text: String, marker: String, from start: String.Index) -> String.Index? {
        var idx = start
        while idx < text.endIndex {
            if text[idx...].hasPrefix(marker) && !text[idx...].hasPrefix(marker + marker) {
                return idx
            }
            idx = text.index(after: idx)
        }
        return nil
    }

    private struct LinkResult {
        let text: String; let url: String; let end: String.Index
    }

    private static func parseLink(_ text: String, from start: String.Index) -> LinkResult? {
        let textStart = text.index(start, offsetBy: 1)
        guard let textEndRange = text.range(of: "]", range: textStart..<text.endIndex) else { return nil }
        let linkText = String(text[textStart..<textEndRange.lowerBound])

        let afterBracket = textEndRange.upperBound
        guard afterBracket < text.endIndex, text[afterBracket...].hasPrefix("(") else { return nil }
        let urlStart = text.index(afterBracket, offsetBy: 1)
        guard let urlEndRange = text.range(of: ")", range: urlStart..<text.endIndex) else { return nil }
        let url = String(text[urlStart..<urlEndRange.lowerBound])

        return LinkResult(text: linkText, url: url, end: urlEndRange.upperBound)
    }
}
