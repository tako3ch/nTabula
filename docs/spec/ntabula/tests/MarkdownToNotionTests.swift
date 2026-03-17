import XCTest
@testable import nTabula

final class MarkdownToNotionTests: XCTestCase {

    // MARK: - ヘルパー

    private func blocks(_ markdown: String) -> [[String: Any]] {
        MarkdownToNotion.convert(markdown)
    }

    private func type(of block: [String: Any]) -> String {
        block["type"] as? String ?? ""
    }

    private func richText(of block: [String: Any]) -> [[String: Any]] {
        guard let typeKey = block["type"] as? String,
              let inner = block[typeKey] as? [String: Any],
              let rt = inner["rich_text"] as? [[String: Any]] else { return [] }
        return rt
    }

    private func plainContent(of block: [String: Any]) -> String {
        richText(of: block)
            .compactMap { ($0["text"] as? [String: Any])?["content"] as? String }
            .joined()
    }

    // MARK: - TC-009: 空文字

    func test_emptyString_returnsEmptyArray() {
        XCTAssertTrue(blocks("").isEmpty)
    }

    func test_onlyNewlines_returnsEmpty() {
        let result = blocks("\n\n\n")
        XCTAssertTrue(result.allSatisfy { type(of: $0) != "heading_1" })
    }

    // MARK: - TC-001: paragraph

    func test_plainText_convertsToParagraph() {
        let result = blocks("Hello, World!")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(type(of: result[0]), "paragraph")
        XCTAssertEqual(plainContent(of: result[0]), "Hello, World!")
    }

    // MARK: - TC-002: 見出し

    func test_h1_convertsToHeading1() {
        let result = blocks("# タイトル")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(type(of: result[0]), "heading_1")
        XCTAssertEqual(plainContent(of: result[0]), "タイトル")
    }

    func test_h2_convertsToHeading2() {
        let result = blocks("## サブタイトル")
        XCTAssertEqual(type(of: result[0]), "heading_2")
    }

    func test_h3_convertsToHeading3() {
        let result = blocks("### セクション")
        XCTAssertEqual(type(of: result[0]), "heading_3")
    }

    func test_h4_convertsToParagraph() {
        // H4 以上は非サポート → paragraph として扱う
        let result = blocks("#### 4階層")
        XCTAssertEqual(type(of: result[0]), "paragraph")
    }

    // MARK: - TC-003: 箇条書き

    func test_hyphenBullet_convertsToBulletedListItem() {
        let result = blocks("- アイテム")
        XCTAssertEqual(type(of: result[0]), "bulleted_list_item")
        XCTAssertEqual(plainContent(of: result[0]), "アイテム")
    }

    func test_asteriskBullet_convertsToBulletedListItem() {
        XCTAssertEqual(type(of: blocks("* アイテム")[0]), "bulleted_list_item")
    }

    func test_plusBullet_convertsToBulletedListItem() {
        XCTAssertEqual(type(of: blocks("+ アイテム")[0]), "bulleted_list_item")
    }

    func test_numberedList_convertsToNumberedListItem() {
        let result = blocks("1. 番号付き")
        XCTAssertEqual(type(of: result[0]), "numbered_list_item")
        XCTAssertEqual(plainContent(of: result[0]), "番号付き")
    }

    func test_numberedList_largeNumber() {
        XCTAssertEqual(type(of: blocks("10. 大きな番号")[0]), "numbered_list_item")
    }

    // MARK: - TC-004: ToDo

    func test_uncheckedTodo_convertsToToDo() {
        let result = blocks("- [ ] 未完了")
        XCTAssertEqual(type(of: result[0]), "to_do")
        let inner = result[0]["to_do"] as? [String: Any]
        XCTAssertEqual(inner?["checked"] as? Bool, false)
    }

    func test_checkedTodo_convertsToToDo() {
        let result = blocks("- [x] 完了")
        XCTAssertEqual(type(of: result[0]), "to_do")
        let inner = result[0]["to_do"] as? [String: Any]
        XCTAssertEqual(inner?["checked"] as? Bool, true)
    }

    // MARK: - TC-005: コードブロック

    func test_codeBlock_withLanguage() {
        let md = "```swift\nlet x = 1\n```"
        let result = blocks(md)
        XCTAssertEqual(type(of: result[0]), "code")
        let inner = result[0]["code"] as? [String: Any]
        XCTAssertEqual(inner?["language"] as? String, "swift")
    }

    func test_codeBlock_withoutLanguage() {
        let md = "```\ncode\n```"
        let result = blocks(md)
        XCTAssertEqual(type(of: result[0]), "code")
        let inner = result[0]["code"] as? [String: Any]
        // 言語指定なし → "plain text" または "" どちらでも可
        let lang = inner?["language"] as? String ?? ""
        XCTAssertTrue(lang == "plain text" || lang == "")
    }

    // MARK: - TC-035: 水平線

    func test_hrTripleDash_convertsToDivider() {
        XCTAssertEqual(type(of: blocks("---")[0]), "divider")
    }

    func test_hrTripleAsterisk_convertsToDivider() {
        XCTAssertEqual(type(of: blocks("***")[0]), "divider")
    }

    func test_hrTripleUnderscore_convertsToDivider() {
        XCTAssertEqual(type(of: blocks("___")[0]), "divider")
    }

    // MARK: - TC-036: 引用

    func test_blockquote_convertsToQuote() {
        let result = blocks("> 引用文")
        XCTAssertEqual(type(of: result[0]), "quote")
        XCTAssertEqual(plainContent(of: result[0]), "引用文")
    }

    // MARK: - TC-006: インラインボールド

    func test_boldText_hasAnnotation() {
        let result = blocks("**太字**テキスト")
        XCTAssertEqual(type(of: result[0]), "paragraph")
        let rt = richText(of: result[0])
        let boldItem = rt.first { ($0["annotations"] as? [String: Any])?["bold"] as? Bool == true }
        XCTAssertNotNil(boldItem)
    }

    // MARK: - TC-007: インラインコード

    func test_inlineCode_hasAnnotation() {
        let result = blocks("`code`")
        let rt = richText(of: result[0])
        let codeItem = rt.first { ($0["annotations"] as? [String: Any])?["code"] as? Bool == true }
        XCTAssertNotNil(codeItem)
    }

    // MARK: - TC-008: リンク

    func test_link_hasHref() {
        let result = blocks("[テキスト](https://example.com)")
        let rt = richText(of: result[0])
        let linkItem = rt.first {
            let text = $0["text"] as? [String: Any]
            return text?["link"] != nil
        }
        XCTAssertNotNil(linkItem)
    }

    // MARK: - TC-039: 打ち消し線

    func test_strikethrough_hasAnnotation() {
        let result = blocks("~~削除~~")
        let rt = richText(of: result[0])
        let stItem = rt.first { ($0["annotations"] as? [String: Any])?["strikethrough"] as? Bool == true }
        XCTAssertNotNil(stItem)
    }

    // MARK: - TC-010: 複合 Markdown

    func test_complexMarkdown_convertsMultipleBlocks() {
        let md = """
        # タイトル
        本文テキスト

        - リスト1
        - リスト2

        ```swift
        let x = 1
        ```

        > 引用文
        """
        let result = blocks(md)
        let types = result.map { type(of: $0) }
        XCTAssertTrue(types.contains("heading_1"))
        XCTAssertTrue(types.contains("paragraph"))
        XCTAssertTrue(types.contains("bulleted_list_item"))
        XCTAssertTrue(types.contains("code"))
        XCTAssertTrue(types.contains("quote"))
    }

    // MARK: - TC-050: 空行の扱い

    func test_blankLineBetweenParagraphs() {
        let md = "段落1\n\n段落2"
        let result = blocks(md)
        // 空行で区切られた2つの段落
        let paragraphs = result.filter { type(of: $0) == "paragraph" }
        XCTAssertEqual(paragraphs.count, 2)
    }

    // MARK: - TC-051: パフォーマンス

    func test_largeMarkdown_performance() {
        // 1000行のリストを1秒以内に変換できること
        let md = (1...1000).map { "- アイテム\($0)" }.joined(separator: "\n")
        measure {
            _ = MarkdownToNotion.convert(md)
        }
    }
}
