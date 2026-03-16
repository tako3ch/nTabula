import SwiftUI
import AppKit

// MARK: - EditorView (NSViewRepresentable)

struct EditorView: NSViewRepresentable {
    @Environment(AppState.self) private var appState

    func makeNSView(context: Context) -> NSScrollView {
        // テキストスタックを構築
        let textStorage = MarkdownTextStorage()
        textStorage.editorFont = resolvedFont

        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = true

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = NTTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        context.coordinator.textView = textView
        // 新しい NSView を作成した場合は currentTabID をリセットして
        // updateNSView でコンテンツを強制的に再ロードさせる
        context.coordinator.currentTabID = nil
        textStorage.textView = textView  // IME 検出用

        // タイトルフィールドの Enter でエディタにフォーカスを移す
        // dismantleNSView で削除するため coordinator に保持する
        context.coordinator.focusObserver = NotificationCenter.default.addObserver(
            forName: .ntFocusEditor, object: nil, queue: .main
        ) { [weak textView] _ in
            textView?.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        if let obs = coordinator.focusObserver {
            NotificationCenter.default.removeObserver(obs)
            coordinator.focusObserver = nil
        }
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NTTextView,
              let storage = textView.textStorage as? MarkdownTextStorage else { return }

        let font = resolvedFont
        if storage.editorFont != font {
            storage.editorFont = font
            storage.rehighlight()
        }

        // タブが切り替わった時のみ textView.string を更新する。
        // 同一タブ内の入力中に呼ぶと IME マーキングが破壊されカーソルがリセットされるため。
        let activeTabID = appState.activeTabID
        if context.coordinator.currentTabID != activeTabID {
            context.coordinator.currentTabID = activeTabID
            let newContent = appState.activeTab?.content ?? ""
            // コンテンツが変わっていなければ string を再セットしない（カーソル位置を保持）
            if textView.string != newContent {
                textView.string = newContent
            }
            storage.rehighlight()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    private var resolvedFont: NSFont {
        let size = appState.editorFontSize
        if !appState.editorFontName.isEmpty,
           let font = NSFont(name: appState.editorFontName, size: size) {
            return font
        }
        // PlemolJP をデフォルトフォントとして試みる（バリアント順に検索）
        let plemolCandidates = [
            "PlemolJP35Console-Regular",
            "PlemolJPConsole-Regular",
            "PlemolJP35-Regular",
            "PlemolJP-Regular",
        ]
        for name in plemolCandidates {
            if let font = NSFont(name: name, size: size) { return font }
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

// MARK: - Coordinator

extension EditorView {
    final class Coordinator: NSObject, NSTextViewDelegate {
        var appState: AppState
        weak var textView: NSTextView?
        private var saveWorkItem: DispatchWorkItem?
        /// 最後に updateNSView でセットしたタブID。変化した時のみコンテンツを差し替える
        var currentTabID: UUID?
        /// ntFocusEditor observer。dismantleNSView で削除する
        var focusObserver: (any NSObjectProtocol)?

        init(appState: AppState) {
            self.appState = appState
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NTTextView,
                  let tabID = appState.activeTabID else { return }
            // IME 変換中（マーキング中）はコンテンツ更新をスキップ
            guard !tv.hasMarkedText() else { return }
            appState.updateContent(tv.string, for: tabID)
            scheduleAutoSave()
        }

        private func scheduleAutoSave() {
            guard appState.autoSaveEnabled else { return }
            saveWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                PersistenceManager.shared.saveTabs(self.appState.tabs)
            }
            saveWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
        }
    }
}

// MARK: - NTTextView (Cmd+S + マークダウンリスト継続)

final class NTTextView: NSTextView {

    // MARK: IME 状態管理

    /// IME 確定直後フラグ。
    /// insertText 時点で hasMarkedText() が true なら IME 確定。その直後に
    /// insertNewline が同期呼び出しされた場合（二重改行）をブロックするために使う。
    /// DispatchQueue.main.async で次のランループ後に自動クリアするため、
    /// insertNewline が呼ばれなくても次の Enter で詰まらない。
    private var justConfirmedIME = false

    /// NSTextInputClient: テキスト確定（IME 確定 Enter or 直接入力）
    /// hasMarkedText() で IME 確定かどうかを判定する（isIMEComposing フラグ不要）
    override func insertText(_ string: Any, replacementRange: NSRange) {
        let wasComposing = hasMarkedText()
        super.insertText(string, replacementRange: replacementRange)
        if wasComposing {
            justConfirmedIME = true
            // 同じランループ内で insertNewline が呼ばれなかった場合（IME が Enter を
            // 消費して insertNewline を発行しないケース）は次の Runloop でクリアする。
            // これにより「次の Enter が2回必要」バグを防ぐ。
            DispatchQueue.main.async { [weak self] in
                self?.justConfirmedIME = false
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "s" {
            NotificationCenter.default.post(name: .ntSaveDocument, object: nil)
            return
        }
        super.keyDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        // IME 確定直後に呼ばれた場合は二重改行なのでスキップ
        if justConfirmedIME {
            justConfirmedIME = false
            return
        }
        guard !currentModifierFlags.contains(.shift) else {
            super.insertNewline(sender)
            return
        }
        if handleSlashCommand() { return }
        if handleListContinuation() { return }
        super.insertNewline(sender)
    }

    /// Shift+Tab: 行頭のインデント（スペース最大4文字 or タブ1文字）を削除
    override func insertBacktab(_ sender: Any?) {
        let cursor = selectedRange()
        let nsString = string as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: cursor.location, length: 0))
        let line = nsString.substring(with: lineRange)

        var charsToRemove = 0
        for ch in line {
            if ch == "\t" { charsToRemove = 1; break }
            else if ch == " " { charsToRemove += 1; if charsToRemove == 4 { break } }
            else { break }
        }
        guard charsToRemove > 0 else { return }

        let removeRange = NSRange(location: lineRange.location, length: charsToRemove)
        insertText("", replacementRange: removeRange)
        let newLoc = max(lineRange.location, cursor.location - charsToRemove)
        setSelectedRange(NSRange(location: newLoc, length: 0))
    }

    /// 現在行がスラッシュコマンドなら展開して true を返す
    private func handleSlashCommand() -> Bool {
        let cursor = selectedRange()
        let nsString = string as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: cursor.location, length: 0))
        let line = nsString.substring(with: lineRange)
        let trimmed = line.hasSuffix("\n") ? String(line.dropLast()) : line

        switch trimmed {
        case "/table":
            let table = "| 列1 | 列2 | 列3 |\n| --- | --- | --- |\n|  |  |  |"
            // 行全体をテーブルで置き換える
            let replaceRange = NSRange(location: lineRange.location,
                                      length: lineRange.length - (line.hasSuffix("\n") ? 1 : 0))
            insertText(table, replacementRange: replaceRange)
            return true
        default:
            return false
        }
    }

    // insertNewline 内で Shift キーを判定するために使用
    private var currentModifierFlags: NSEvent.ModifierFlags {
        NSApp.currentEvent?.modifierFlags ?? []
    }

    /// 現在行がリスト記法なら改行後に同じプレフィックスを挿入。処理した場合 true を返す。
    private func handleListContinuation() -> Bool {
        let cursor = selectedRange()
        let nsString = string as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: cursor.location, length: 0))
        let line = nsString.substring(with: lineRange)
        // 行末の改行を除いた内容
        let trimmed = line.hasSuffix("\n") ? String(line.dropLast()) : line

        // ToDo リスト（"- [ ] " / "- [x] "）を箇条書きより先にチェック
        for todo in ["- [ ] ", "- [x] "] {
            guard trimmed.hasPrefix(todo) else { continue }
            let rest = String(trimmed.dropFirst(todo.count))
            if rest.isEmpty {
                // 空の ToDo 行: プレフィックスを削除して通常改行
                let delRange = NSRange(location: lineRange.location,
                                      length: lineRange.length - (line.hasSuffix("\n") ? 1 : 0))
                insertText("\n", replacementRange: delRange)
            } else {
                insertText("\n- [ ] ", replacementRange: cursor)
            }
            return true
        }

        // 箇条書き "- " / "* " / "+ "
        for b in ["- ", "* ", "+ "] {
            guard trimmed.hasPrefix(b) else { continue }
            let rest = String(trimmed.dropFirst(b.count))
            if rest.isEmpty {
                let delRange = NSRange(location: lineRange.location,
                                      length: lineRange.length - (line.hasSuffix("\n") ? 1 : 0))
                insertText("\n", replacementRange: delRange)
            } else {
                insertText("\n\(b)", replacementRange: cursor)
            }
            return true
        }

        // 番号付きリスト "1. ", "2. " ...
        if let matchRange = trimmed.range(of: #"^(\d+)\. "#, options: .regularExpression) {
            let prefix = String(trimmed[matchRange])
            let numStr = String(prefix.dropLast(2))
            let rest = String(trimmed.dropFirst(prefix.count))
            if !rest.isEmpty, let num = Int(numStr) {
                insertText("\n\(num + 1). ", replacementRange: cursor)
                return true
            }
        }

        return false
    }
}

// MARK: - MarkdownTextStorage

final class MarkdownTextStorage: NSTextStorage {
    private let storage = NSMutableAttributedString()
    var editorFont: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    /// IME 検出用（makeNSView でセットする）
    weak var textView: NSTextView?

    // MARK: NSTextStorage 必須実装

    override var string: String { storage.string }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        guard location < storage.length else { return [:] }
        return storage.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        storage.replaceCharacters(in: range, with: str)
        // NSTextStorage は UTF-16 単位で長さを管理するため (str as NSString).length を使う。
        // str.count（Swift スカラー数）は BMP 外文字（絵文字等）で UTF-16 長と異なる。
        edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        guard range.location + range.length <= storage.length else { return }
        storage.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
    }

    override func processEditing() {
        let editedRange = self.editedRange
        // IME 変換中（markedRange が有効）はハイライトをスキップしてマーキング属性を保護する
        let isIMEActive = (textView?.markedRange().length ?? 0) > 0
        if editedRange.location != NSNotFound && !isIMEActive {
            let paragraphRange = (string as NSString).paragraphRange(for: editedRange)
            applyHighlighting(in: paragraphRange)
            // 内部ストレージへの属性変更（applyHighlighting）を NSLayoutManager へ通知する。
            // これがないと段落全体の再描画が行われず、IME確定後の日本語テキストが不可視になる。
            edited(.editedAttributes, range: paragraphRange, changeInLength: 0)
        }
        super.processEditing()
    }

    /// 全文を再ハイライト（コンテンツ差し替え時に呼ぶ）
    func rehighlight() {
        guard storage.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        beginEditing()
        applyHighlighting(in: fullRange)
        edited(.editedAttributes, range: fullRange, changeInLength: 0)
        endEditing()
    }

    // MARK: - Highlighting

    private func applyHighlighting(in range: NSRange) {
        guard range.location + range.length <= storage.length, range.length > 0 else { return }

        // ベーススタイルにリセット
        storage.setAttributes(baseAttrs(), range: range)

        // 行ごとのハイライト（enumerateSubstrings は同期実行なので循環参照なし）
        (string as NSString).enumerateSubstrings(in: range, options: [.byLines, .substringNotRequired]) { [self] _, lineRange, _, _ in
            highlightLine(lineRange)
        }

        // インラインハイライト（bold, code, link など）
        applyInlineHighlighting(in: range)
    }

    private func highlightLine(_ range: NSRange) {
        guard range.length > 0 else { return }
        let line = (string as NSString).substring(with: range)

        if line.hasPrefix("# ") {
            let font = NSFont.systemFont(ofSize: editorFont.pointSize * 1.6, weight: .bold)
            storage.addAttributes([.font: font], range: range)
            dimRange(in: range, length: 2)
        } else if line.hasPrefix("## ") {
            let font = NSFont.systemFont(ofSize: editorFont.pointSize * 1.35, weight: .bold)
            storage.addAttributes([.font: font], range: range)
            dimRange(in: range, length: 3)
        } else if line.hasPrefix("### ") {
            let font = NSFont.systemFont(ofSize: editorFont.pointSize * 1.15, weight: .semibold)
            storage.addAttributes([.font: font], range: range)
            dimRange(in: range, length: 4)
        } else if line.hasPrefix("> ") {
            storage.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: italicFont(editorFont.pointSize)
            ], range: range)
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            let markerLen = min(2, range.length)
            storage.addAttribute(.foregroundColor, value: NSColor.systemBlue,
                                 range: NSRange(location: range.location, length: markerLen))
        } else if line.hasPrefix("```") {
            storage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: range)
        } else {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
            }
        }
    }

    // インラインパターン用のコンパイル済み正規表現（毎回生成せずキャッシュ）
    private enum InlineRegex {
        static let bold          = try! NSRegularExpression(pattern: #"\*\*([^*\n]+)\*\*"#)
        static let code          = try! NSRegularExpression(pattern: #"`([^`\n]+)`"#)
        static let link          = try! NSRegularExpression(pattern: #"\[[^\]\n]+\]\([^)\n]+\)"#)
        static let strikethrough = try! NSRegularExpression(pattern: #"~~([^~\n]+)~~"#)
    }

    private func applyInlineHighlighting(in range: NSRange) {
        // Bold **text**
        applyPattern(InlineRegex.bold, in: range,
                     attrs: [.font: NSFont.boldSystemFont(ofSize: editorFont.pointSize)])

        // Inline code `text`
        applyPattern(InlineRegex.code, in: range, attrs: [
            .foregroundColor: NSColor.systemOrange,
            .font: editorFont
        ])

        // Links [text](url)
        applyPattern(InlineRegex.link, in: range,
                     attrs: [.foregroundColor: NSColor.systemBlue])

        // Strikethrough ~~text~~
        applyPattern(InlineRegex.strikethrough, in: range, attrs: [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: NSColor.secondaryLabelColor
        ])
    }

    private func applyPattern(_ regex: NSRegularExpression, in range: NSRange,
                               attrs: [NSAttributedString.Key: Any]) {
        let str = string as NSString
        let substring = str.substring(with: range)
        let matches = regex.matches(in: substring, range: NSRange(substring.startIndex..., in: substring))
        for match in matches {
            let absRange = NSRange(location: range.location + match.range.location, length: match.range.length)
            guard absRange.location + absRange.length <= storage.length else { continue }
            storage.addAttributes(attrs, range: absRange)
        }
    }

    private func dimRange(in lineRange: NSRange, length: Int) {
        let markerRange = NSRange(location: lineRange.location, length: min(length, lineRange.length))
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: markerRange)
    }

    private func baseAttrs() -> [NSAttributedString.Key: Any] {
        [.font: editorFont, .foregroundColor: NSColor.labelColor]
    }

    private func italicFont(_ size: CGFloat) -> NSFont {
        NSFontManager.shared.font(
            withFamily: editorFont.familyName ?? "SF Mono",
            traits: .italicFontMask, weight: 5, size: size
        ) ?? editorFont
    }
}

extension Notification.Name {
    static let ntSaveDocument = Notification.Name("nTabula.saveDocument")
    static let ntFocusEditor  = Notification.Name("nTabula.focusEditor")
    static let ntSwitchTab    = Notification.Name("nTabula.switchTab")
}
