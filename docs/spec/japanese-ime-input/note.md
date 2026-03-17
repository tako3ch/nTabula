# 日本語 IME 入力 コンテキストノート

**作成日**: 2026-03-16
**用途**: kairo-requirements 参照用ノート（japanese-ime-input）

---

## 1. 技術スタック

| 項目 | 内容 |
|------|------|
| 言語 | Swift 6 |
| UI フレームワーク | SwiftUI + AppKit（NSViewRepresentable） |
| エディタコア | NSTextView（NTTextView サブクラス） |
| テキストストレージ | MarkdownTextStorage（NSTextStorage サブクラス） |
| IME 検出 API | `NSTextView.hasMarkedText()` |
| テスト | XCTest（Unit Test は可能、IME の動作は XCUITest 必須） |
| 最小 OS | macOS 14.0 (Sonoma) |

参照元: `CLAUDE.md`, `Sources/Views/EditorView.swift`

---

## 2. 開発ルール

- ソースコードの編集は `Sources/` のみ
- Swift 6 準拠（Sendable、actor）
- IME 変換中はテキストストレージ・AppState を一切変更しない方針
- `hasMarkedText()` チェックは防御的に入れる（複数箇所）

参照元: `CLAUDE.md`, `Sources/Views/EditorView.swift`

---

## 3. 関連実装

### EditorView.Coordinator.textDidChange（L105-112）

```swift
func textDidChange(_ notification: Notification) {
    guard let tv = notification.object as? NSTextView,
          let tabID = appState.activeTabID else { return }
    // IME 変換中（マーキング中）はコンテンツ更新をスキップ
    guard !tv.hasMarkedText() else { return }
    appState.updateContent(tv.string, for: tabID)
    scheduleAutoSave()
}
```

- IME 変換中は `appState.updateContent()` および `scheduleAutoSave()` を呼ばない
- 確定後（hasMarkedText() == false）に次の textDidChange で正常に処理

### MarkdownTextStorage.processEditing（L227-234）

```swift
override func processEditing() {
    let edited = self.editedRange
    if edited.location != NSNotFound && textView?.hasMarkedText() != true {
        // IME 変換中はハイライトをスキップ（マーキング属性を上書きしないため）
        let paragraphRange = (string as NSString).paragraphRange(for: edited)
        applyHighlighting(in: paragraphRange)
    }
    super.processEditing()
}
```

- IME 変換中はシンタックスハイライトの再計算をスキップ
- textView 弱参照（`weak var textView: NSTextView?`）でタイミング依存を回避

### EditorView.updateNSView（L56-75）

```swift
func updateNSView(_ nsView: NSScrollView, context: Context) {
    // ...
    // タブが切り替わった時のみ textView.string を更新する。
    // 同一タブ内の入力中に呼ぶと IME マーキングが破壊されるため。
    let activeTabID = appState.activeTabID
    if context.coordinator.currentTabID != activeTabID {
        context.coordinator.currentTabID = activeTabID
        let newContent = appState.activeTab?.content ?? ""
        textView.string = newContent
        storage.rehighlight()
    }
}
```

- `currentTabID` と `activeTabID` を比較して差し替えは**タブ切り替え時のみ**
- 同一タブ内では `textView.string` を上書きしない → IME マーキングを保護

**実装ファイル**: `Sources/Views/EditorView.swift`

---

## 4. 設計文書

- `docs/spec/ntabula/requirements.md` — REQ-113（IME 要件の既存定義）
- `docs/spec/ntabula/user-stories.md` — US-006（日本語でストレスなく書く）
- `docs/spec/ntabula/acceptance-criteria.md` — AC-005（日本語 IME 入力）
- `docs/design/ntabula/architecture.md` — エディタアーキテクチャ概要

---

## 5. テスト関連情報

- **XCTest Unit**: IME の実際の動作は Unit Test では検証不可（OS IME の起動が必要）
- **XCUITest**: IME 入力フローは XCUITest でのみ自動テスト可能
- **テストターゲット**: `nTabulaTests`（現在未追加 → TASK-0009 で構築予定）
- **現状**: AC-005 の4項目すべて ⚠️（未テスト）

参照元: `docs/spec/ntabula/acceptance-criteria.md`

---

## 6. 注意事項

- `textView.string` への代入は **NSTextView のマーキングを即座に破壊**するため、IME 変換中は絶対に行わない
- `processEditing()` はシステムから頻繁に呼ばれる。`hasMarkedText()` を nil チェックを兼ねて `!= true` で評価している
- `Cmd+S`（NTTextView.keyDown）は IME 変換中でも `ntSaveDocument` 通知を送信する → AppState はその時点の `textView.string` を使って同期
- 対象 IME: **日本語のみ**。中国語・韓国語は明示的にスコープ外
