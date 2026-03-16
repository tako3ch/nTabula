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
        return scrollView
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
        // 同一タブ内の入力中に呼ぶと IME マーキングが破壊されるため。
        let activeTabID = appState.activeTabID
        if context.coordinator.currentTabID != activeTabID {
            // 同一タブへの非同期モデル更新が pending 中なら遅延させる。
            // （makeNSView 再実行→currentTabID=nil の直後に古いモデル内容で上書きするのを防ぐ）
            // タブが切り替わった場合（pendingTabID ≠ activeTabID）は遅延しない。
            if context.coordinator.pendingTabID == activeTabID && context.coordinator.pendingCount > 0 {
                return
            }
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
        /// 非同期モデル更新が pending の tabID と件数。
        /// updateNSView が古いモデル内容で NSTextView を上書きするのを防ぐ。
        var pendingTabID: UUID? = nil
        var pendingCount: Int = 0

        init(appState: AppState) {
            self.appState = appState
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NTTextView,
                  let tabID = appState.activeTabID else { return }
            // IME 変換中（マーキング中）はコンテンツ更新をスキップ
            // Zed パターン: 明示的フラグ + hasMarkedText() の二重ガード
            guard !tv.isIMEComposing && !tv.hasMarkedText() else { return }
            // @Observable の同期再レンダリングが IME イベントチェーンを妨害しないよう
            // 次のランループサイクルで model を更新する（Enter #1→Enter #2 の間に
            // updateNSView が割り込まないようにする）。
            // pending カウントで「最後の非同期更新が完了するまで updateNSView の
            // コンテンツリセットを遅延させる」ガードを管理する。
            let content = tv.string
            pendingTabID = tabID
            pendingCount += 1
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingCount -= 1
                if self.pendingCount == 0 { self.pendingTabID = nil }
                self.appState.updateContent(content, for: tabID)
                self.scheduleAutoSave()
            }
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

    // MARK: IME 状態管理（Zed パターン）

    /// IME 変換中フラグ。hasMarkedText() より細粒度で状態を追跡する。
    /// setMarkedText で true、insertText で false にリセットされる。
    private(set) var isIMEComposing = false

    /// NSTextInputClient: IME 変換開始（候補ウィンドウ表示中）
    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        isIMEComposing = true
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    /// NSTextInputClient: テキスト確定（IME 確定 Enter #1 or 直接入力）
    /// isIMEComposing を先にリセットし、super.insertText 内で発火する textDidChange がモデルを更新できるようにする。
    override func insertText(_ string: Any, replacementRange: NSRange) {
        isIMEComposing = false
        super.insertText(string, replacementRange: replacementRange)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "s" {
            NotificationCenter.default.post(name: .ntSaveDocument, object: nil)
            return
        }
        super.keyDown(with: event)
    }

    // insertNewline は IME が Enter を消費しない（純粋な改行挿入）場合のみ呼ばれる。
    // keyDown と異なり、日本語確定の Enter とは自動的に区別されるため IME 問題が起きない。
    override func insertNewline(_ sender: Any?) {
        guard !currentModifierFlags.contains(.shift) else {
            super.insertNewline(sender)
            return
        }
        if handleListContinuation() { return }
        super.insertNewline(sender)
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

        // 行ごとのハイライト
        (string as NSString).enumerateSubstrings(in: range, options: [.byLines, .substringNotRequired]) { [weak self] _, lineRange, _, _ in
            self?.highlightLine(lineRange)
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

    private func applyInlineHighlighting(in range: NSRange) {
        // Bold **text**
        applyPattern(#"\*\*([^*\n]+)\*\*"#, in: range,
                     attrs: [.font: NSFont.boldSystemFont(ofSize: editorFont.pointSize)])

        // Inline code `text`
        applyPattern(#"`([^`\n]+)`"#, in: range, attrs: [
            .foregroundColor: NSColor.systemOrange,
            .font: editorFont
        ])

        // Links [text](url)
        applyPattern(#"\[[^\]\n]+\]\([^)\n]+\)"#, in: range,
                     attrs: [.foregroundColor: NSColor.systemBlue])

        // Strikethrough ~~text~~
        applyPattern(#"~~([^~\n]+)~~"#, in: range, attrs: [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: NSColor.secondaryLabelColor
        ])
    }

    private func applyPattern(_ pattern: String, in range: NSRange,
                               attrs: [NSAttributedString.Key: Any]) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
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
}
