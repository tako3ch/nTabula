import SwiftUI
import AppKit

// MARK: - MarkdownPreviewView

struct MarkdownPreviewView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        let attrStr = MarkdownRenderer.render(markdown)
        textView.textStorage?.setAttributedString(attrStr)
    }
}

// MARK: - MarkdownRenderer

private enum MarkdownRenderer {

    static func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // フェンスコードブロック
            if line.hasPrefix("```") {
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                result.append(codeBlock(codeLines.joined(separator: "\n")))
                i += 1
                continue
            }

            // テーブル
            if line.hasPrefix("|") && line.contains("|") {
                var tableLines: [String] = []
                while i < lines.count && lines[i].hasPrefix("|") {
                    tableLines.append(lines[i])
                    i += 1
                }
                result.append(tableBlock(tableLines))
                continue
            }

            result.append(parseLine(line))
            i += 1
        }

        return result
    }

    // MARK: - Line parsers

    private static func parseLine(_ line: String) -> NSAttributedString {
        if line.hasPrefix("### ") { return heading(String(line.dropFirst(4)), size: 15, weight: .semibold) }
        if line.hasPrefix("## ")  { return heading(String(line.dropFirst(3)), size: 18, weight: .bold) }
        if line.hasPrefix("# ")   { return heading(String(line.dropFirst(2)), size: 22, weight: .bold, underline: true) }
        if line.hasPrefix("> ")   { return blockquote(String(line.dropFirst(2))) }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "---" || trimmed == "***" || trimmed == "___" { return hr() }

        if line.hasPrefix("- [ ] ") || line.hasPrefix("* [ ] ") {
            return todo(String(line.dropFirst(6)), checked: false)
        }
        if line.lowercased().hasPrefix("- [x] ") || line.lowercased().hasPrefix("* [x] ") {
            return todo(String(line.dropFirst(6)), checked: true)
        }
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return bullet(String(line.dropFirst(2)))
        }
        if line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
            let text = line.replacingOccurrences(of: #"^\d+\.\s"#, with: "", options: .regularExpression)
            return bullet(text, marker: "• ")
        }
        if trimmed.isEmpty { return newline() }
        return paragraph(line)
    }

    // MARK: - Block builders

    private static func heading(_ text: String, size: CGFloat, weight: NSFont.Weight, underline: Bool = false) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: spacedParagraph(before: 12, after: 4)
        ]
        if underline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            attrs[.underlineColor] = NSColor.separatorColor
        }
        let result = NSMutableAttributedString(attributedString: parseInline(text, baseFont: font))
        result.addAttributes(attrs, range: NSRange(location: 0, length: result.length))
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    private static func paragraph(_ text: String) -> NSAttributedString {
        let font = bodyFont()
        let result = NSMutableAttributedString(attributedString: parseInline(text, baseFont: font))
        result.addAttributes([
            .paragraphStyle: spacedParagraph(before: 0, after: 2)
        ], range: NSRange(location: 0, length: result.length))
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    private static func bullet(_ text: String, marker: String = "• ") -> NSAttributedString {
        let font = bodyFont()
        let result = NSMutableAttributedString(string: marker, attributes: [
            .font: font,
            .foregroundColor: NSColor.systemBlue
        ])
        result.append(parseInline(text, baseFont: font))
        result.addAttribute(.paragraphStyle, value: bulletParagraph(),
                            range: NSRange(location: 0, length: result.length))
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    private static func todo(_ text: String, checked: Bool) -> NSAttributedString {
        let font = bodyFont()
        let marker = checked ? "☑ " : "☐ "
        let result = NSMutableAttributedString(string: marker, attributes: [
            .font: font,
            .foregroundColor: checked ? NSColor.secondaryLabelColor : NSColor.labelColor
        ])
        let inline = parseInline(text, baseFont: font)
        if checked {
            let mutable = NSMutableAttributedString(attributedString: inline)
            mutable.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.secondaryLabelColor
            ], range: NSRange(location: 0, length: mutable.length))
            result.append(mutable)
        } else {
            result.append(inline)
        }
        result.addAttribute(.paragraphStyle, value: bulletParagraph(),
                            range: NSRange(location: 0, length: result.length))
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    private static func blockquote(_ text: String) -> NSAttributedString {
        let font = bodyFont()
        let result = NSMutableAttributedString(attributedString: parseInline(text, baseFont: font))
        result.addAttributes([
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: quoteParagraph()
        ], range: NSRange(location: 0, length: result.length))
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    private static func codeBlock(_ text: String) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = 6
        para.paragraphSpacing = 6
        let result = NSMutableAttributedString(string: text + "\n", attributes: [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: NSColor(white: 0.5, alpha: 0.1),
            .paragraphStyle: para
        ])
        return result
    }

    private static func tableBlock(_ lines: [String]) -> NSAttributedString {
        guard lines.count >= 2 else { return NSAttributedString(string: lines.joined(separator: "\n") + "\n") }

        let result = NSMutableAttributedString()
        let headers = tableRow(lines[0])
        let bodyLines = lines.dropFirst(2)

        // ヘッダー行
        let headerText = headers.joined(separator: "  |  ")
        let headerAttr = NSMutableAttributedString(string: headerText + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ])
        result.append(headerAttr)

        // セパレーター
        result.append(NSAttributedString(string: String(repeating: "─", count: 40) + "\n", attributes: [
            .foregroundColor: NSColor.separatorColor,
            .font: bodyFont()
        ]))

        // ボディ行
        for row in bodyLines {
            let cells = tableRow(row)
            let rowText = cells.joined(separator: "  |  ")
            result.append(NSAttributedString(string: rowText + "\n", attributes: [
                .font: bodyFont(),
                .foregroundColor: NSColor.labelColor
            ]))
        }
        result.append(newline())
        return result
    }

    private static func hr() -> NSAttributedString {
        NSAttributedString(string: String(repeating: "─", count: 60) + "\n", attributes: [
            .foregroundColor: NSColor.separatorColor,
            .font: bodyFont(),
            .paragraphStyle: spacedParagraph(before: 8, after: 8)
        ])
    }

    private static func newline() -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: [.font: bodyFont()])
    }

    // MARK: - Inline parser

    private static func parseInline(_ text: String, baseFont: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var current = ""
        var idx = text.startIndex

        func flush() {
            guard !current.isEmpty else { return }
            result.append(NSAttributedString(string: current, attributes: [
                .font: baseFont, .foregroundColor: NSColor.labelColor
            ]))
            current = ""
        }

        while idx < text.endIndex {
            if text[idx...].hasPrefix("**"), let end = text.range(of: "**", range: text.index(idx, offsetBy: 2)..<text.endIndex) {
                flush()
                let bold = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
                result.append(NSAttributedString(string: String(text[text.index(idx, offsetBy: 2)..<end.lowerBound]),
                    attributes: [.font: bold, .foregroundColor: NSColor.labelColor]))
                idx = end.upperBound; continue
            }
            if text[idx...].hasPrefix("~~"), let end = text.range(of: "~~", range: text.index(idx, offsetBy: 2)..<text.endIndex) {
                flush()
                result.append(NSAttributedString(string: String(text[text.index(idx, offsetBy: 2)..<end.lowerBound]),
                    attributes: [.font: baseFont, .foregroundColor: NSColor.secondaryLabelColor,
                                 .strikethroughStyle: NSUnderlineStyle.single.rawValue]))
                idx = end.upperBound; continue
            }
            if text[idx...].hasPrefix("`"), let end = text.range(of: "`", range: text.index(idx, offsetBy: 1)..<text.endIndex) {
                flush()
                let mono = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular)
                result.append(NSAttributedString(string: String(text[text.index(idx, offsetBy: 1)..<end.lowerBound]),
                    attributes: [.font: mono, .foregroundColor: NSColor.systemOrange,
                                 .backgroundColor: NSColor(white: 0.5, alpha: 0.08)]))
                idx = end.upperBound; continue
            }
            if text[idx...].hasPrefix("["), let link = parseLink(text, from: idx) {
                flush()
                result.append(NSAttributedString(string: link.text, attributes: [
                    .font: baseFont, .foregroundColor: NSColor.linkColor,
                    .link: link.url as AnyObject
                ]))
                idx = link.end; continue
            }
            current.append(text[idx])
            idx = text.index(after: idx)
        }
        flush()
        return result
    }

    // MARK: - Paragraph styles

    private static func spacedParagraph(before: CGFloat, after: CGFloat) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacingBefore = before
        p.paragraphSpacing = after
        return p
    }

    private static func bulletParagraph() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.headIndent = 16
        p.firstLineHeadIndent = 0
        p.paragraphSpacing = 2
        return p
    }

    private static func quoteParagraph() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.headIndent = 12
        p.firstLineHeadIndent = 12
        p.paragraphSpacing = 2
        return p
    }

    // MARK: - Helpers

    private static func bodyFont() -> NSFont {
        NSFont.systemFont(ofSize: 14, weight: .regular)
    }

    private static func tableRow(_ line: String) -> [String] {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        let inner = stripped.hasPrefix("|") ? String(stripped.dropFirst()) : stripped
        var cells = inner.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        if cells.last?.isEmpty == true { cells.removeLast() }
        return cells
    }

    private struct LinkResult { let text: String; let url: String; let end: String.Index }

    private static func parseLink(_ text: String, from start: String.Index) -> LinkResult? {
        let textStart = text.index(start, offsetBy: 1)
        guard let textEnd = text.range(of: "]", range: textStart..<text.endIndex) else { return nil }
        let linkText = String(text[textStart..<textEnd.lowerBound])
        let afterBracket = textEnd.upperBound
        guard afterBracket < text.endIndex, text[afterBracket...].hasPrefix("(") else { return nil }
        let urlStart = text.index(afterBracket, offsetBy: 1)
        guard let urlEnd = text.range(of: ")", range: urlStart..<text.endIndex) else { return nil }
        return LinkResult(text: linkText, url: String(text[urlStart..<urlEnd.lowerBound]), end: urlEnd.upperBound)
    }
}
