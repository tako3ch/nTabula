# nTabula P0/P1 改善 実装計画

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** P0 バグ修正・技術的負債の解消 + P1 UX 改善（文字数カウント・エクスポート・タブドラッグ並び替え）

**Architecture:** 既存の AppState-central 設計を踏襲。新機能は既存ファイルへの最小追加で実装する。ドラッグ並び替えは SwiftUI の `.onDrag`/`.onDrop` + `DropDelegate` API を使い、AppState に `moveTab` メソッドを追加する。

**Tech Stack:** Swift / SwiftUI / AppKit, macOS 14+, NSSavePanel（エクスポート）

---

## Chunk 1: P0 — バグ修正・技術的負債

### Task 1: 重複ファイル削除

**Files:**
- Delete: `Sources/Views/MarkdownPreviewView 2.swift`

- [ ] `Sources/Views/MarkdownPreviewView 2.swift` を削除する
  - ターミナルで `rm "Sources/Views/MarkdownPreviewView 2.swift"` を実行
  - Xcode の Project Navigator に表示されている場合は参照も削除する
- [ ] ビルド確認: `⌘B` でエラーがないことを確認
- [ ] コミット:
  ```bash
  git add -A
  git commit -m "chore: MarkdownPreviewView 2.swift 重複ファイル削除"
  ```

---

### Task 2: ステータスバー・サイドバーの page モード対応

**Files:**
- Modify: `Sources/Views/MainWindowView.swift`（`dbSelectorMenu` プロパティ）
- Modify: `Sources/Views/VerticalSidebarView.swift`（フッター部分）

**`MainWindowView.swift` — `dbSelectorMenu` を以下で置き換える:**

```swift
@ViewBuilder
private var dbSelectorMenu: some View {
    switch appState.notionSaveTarget {
    case .database:
        if let db = appState.selectedDatabase {
            Menu {
                ForEach(appState.databases) { database in
                    Button(database.displayTitle) {
                        appState.selectedDatabaseID = database.id
                        PersistenceManager.shared.saveSelectedDatabaseID(database.id)
                    }
                }
                Divider()
                Button("設定を開く") { openSettings() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.green)
                    Text(db.displayTitle)
                        .font(.system(size: 11))
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        } else {
            Button { openSettings() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                    Text("未接続 — 設定を開く")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    case .page:
        if let page = appState.pages.first(where: { $0.id == appState.selectedParentPageID }) {
            Button { openSettings() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.green)
                    Text(page.displayTitle)
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
        } else {
            Button { openSettings() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                    Text("未接続 — 設定を開く")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}
```

**`VerticalSidebarView.swift` — フッターの `HStack` 内を以下で置き換える:**

現在のコード（72〜81行目付近）:
```swift
if appState.isSyncing {
    ProgressView()
        .scaleEffect(0.6)
        .frame(width: 16, height: 16)
}
if let db = appState.selectedDatabase {
    Image(systemName: "circle.fill")
        .font(.system(size: 6))
        .foregroundStyle(.green)
    Text(db.displayTitle)
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
}
```

置き換え後:
```swift
if appState.isSyncing {
    ProgressView()
        .scaleEffect(0.6)
        .frame(width: 16, height: 16)
}
if appState.notionSaveTarget == .database, let db = appState.selectedDatabase {
    Image(systemName: "circle.fill")
        .font(.system(size: 6))
        .foregroundStyle(.green)
    Text(db.displayTitle)
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
} else if appState.notionSaveTarget == .page,
          let page = appState.pages.first(where: { $0.id == appState.selectedParentPageID }) {
    Image(systemName: "circle.fill")
        .font(.system(size: 6))
        .foregroundStyle(.green)
    Text(page.displayTitle)
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
}
```

- [ ] `MainWindowView.swift` の `dbSelectorMenu` を上記コードで置き換える
- [ ] `VerticalSidebarView.swift` のフッター部分を上記コードで置き換える
- [ ] ビルド確認（`⌘B`）
- [ ] コミット:
  ```bash
  git add Sources/Views/MainWindowView.swift Sources/Views/VerticalSidebarView.swift
  git commit -m "fix: ステータスバーとサイドバーを page モードに対応"
  ```

---

### Task 3: 未使用コード削除

**Files:**
- Modify: `Sources/Utilities/MarkdownToNotion.swift`

`MarkdownToNotion.convert()` とそれ専用のヘルパーをすべて削除する。
削除対象: `convert()`, `parseLine()`, `block()`, `todoBlock()`, `parseInline()`, `plainRT()`, `styledRT()`, `linkRT()`, `defaultAnnotations()`, `flush()`, `findSingleMarker()`, `LinkResult` struct, `parseLink()`
**残すもの**: `convertToMarkdownBlock()` と `codeBlock()` のみ。

削除後のファイル全体:
```swift
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
```

- [ ] `Sources/Utilities/MarkdownToNotion.swift` を上記内容で置き換える
- [ ] ビルド確認（`⌘B`）
- [ ] コミット:
  ```bash
  git add Sources/Utilities/MarkdownToNotion.swift
  git commit -m "refactor: 未使用の MarkdownToNotion.convert() を削除"
  ```

---

## Chunk 2: P1 — 文字数カウント・エクスポート

### Task 4: ステータスバーに文字数・行数カウント

**Files:**
- Modify: `Sources/Views/MainWindowView.swift`（`statusBar` プロパティ）

`statusBar` の `Spacer()` の直前に以下を追加する（84〜121行目の `HStack` 内）:

```swift
// 文字数・行数カウント
if let tab = appState.activeTab {
    let charCount = tab.content.count
    let lineCount = tab.content.isEmpty ? 0 : tab.content.components(separatedBy: .newlines).count
    Text("\(lineCount) 行  \(charCount) 文字")
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.tertiary)
}
```

挿入位置: `dbSelectorMenu` の後、`Spacer()` の前。

- [ ] `statusBar` に文字数・行数表示を追加する
- [ ] ビルド確認（`⌘B`）
- [ ] 動作確認: エディタで文字を入力・削除してカウントが即時更新されることを確認
- [ ] コミット:
  ```bash
  git add Sources/Views/MainWindowView.swift
  git commit -m "feat: ステータスバーに文字数・行数カウントを追加"
  ```

---

### Task 5: Markdown エクスポート（Cmd+Shift+E）

**Files:**
- Modify: `Sources/App/nTabulaApp.swift`

**変更1**: `body` の外（`nTabulaApp` struct 内）に関数を追加:

```swift
private func exportActiveTab(_ appState: AppState) {
    guard let tab = appState.activeTab else { return }
    let panel = NSSavePanel()
    panel.title = "Markdown としてエクスポート"
    panel.allowedContentTypes = [.plainText]
    panel.nameFieldStringValue = (tab.title.isEmpty ? "Untitled" : tab.title) + ".md"
    // content を先に取り出すことで、クロージャ内での @MainActor 参照を回避
    let content = tab.content
    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}
```

**変更2**: `saveItem` の `CommandGroup` 内、既存ボタンの後に追加:

```swift
Button("Markdown としてエクスポート...") {
    exportActiveTab(appState)
}
.keyboardShortcut("e", modifiers: [.command, .shift])
.disabled(appState.activeTab == nil)
```

- [ ] `nTabulaApp.swift` に `exportActiveTab` 関数を追加する
- [ ] `saveItem` CommandGroup にエクスポートボタンを追加する
- [ ] ビルド確認（`⌘B`）
- [ ] 動作確認: Cmd+Shift+E でパネルが開き、.md ファイルとして内容が書き込まれることを確認
- [ ] コミット:
  ```bash
  git add Sources/App/nTabulaApp.swift
  git commit -m "feat: Markdown エクスポート機能を追加 (Cmd+Shift+E)"
  ```

---

## Chunk 3: P1 — タブのドラッグ並び替え

### Task 6: AppState に moveTab メソッドを追加

**Files:**
- Modify: `Sources/App/AppState.swift`（Tab Management セクション）

`switchToTab(at:)` の後に追加:

```swift
/// ピン留め状態が同じタブ間でのみ並び替えを許可する
func moveTab(from sourceID: UUID, to destinationID: UUID) {
    guard sourceID != destinationID,
          let srcIdx = tabs.firstIndex(where: { $0.id == sourceID }),
          let dstIdx = tabs.firstIndex(where: { $0.id == destinationID }),
          tabs[srcIdx].isPinned == tabs[dstIdx].isPinned
    else { return }
    tabs.move(fromOffsets: IndexSet(integer: srcIdx), toOffset: dstIdx > srcIdx ? dstIdx + 1 : dstIdx)
    saveTabs()
}
```

- [ ] `AppState.swift` に `moveTab(from:to:)` を追加する
- [ ] ビルド確認（`⌘B`）
- [ ] コミット:
  ```bash
  git add Sources/App/AppState.swift
  git commit -m "feat: AppState に moveTab メソッドを追加"
  ```

---

### Task 7: 横タブ（TabBarView）にドラッグ並び替えを追加

**Files:**
- Modify: `Sources/Views/TabBarView.swift`

**変更1**: `TabItemButton` の `.contextMenu { ... }` の後に追加:

```swift
.onDrag {
    NSItemProvider(object: tab.id.uuidString as NSString)
}
.onDrop(of: [.plainText], delegate: TabDropDelegate(tab: tab, appState: appState))
```

**変更2**: `TabBarView.swift` の末尾（`TabItemButton` struct の後）に追加:

```swift
// MARK: - TabDropDelegate

private struct TabDropDelegate: DropDelegate {
    let tab: TabItem
    let appState: AppState

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.plainText]).first else { return false }
        item.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { data, _ in
            guard let data = data as? Data,
                  let uuidString = String(data: data, encoding: .utf8),
                  let sourceID = UUID(uuidString: uuidString)
            else { return }
            Task { @MainActor in
                appState.moveTab(from: sourceID, to: tab.id)
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
```

- [ ] `TabItemButton` に `.onDrag` / `.onDrop` を追加する
- [ ] `TabDropDelegate` struct を追加する
- [ ] ビルド確認（`⌘B`）
- [ ] 動作確認: 横タブをドラッグして並び替えができること、ピン留めタブをまたいだ移動が無効なことを確認
- [ ] コミット:
  ```bash
  git add Sources/Views/TabBarView.swift
  git commit -m "feat: 横タブのドラッグ並び替えを実装"
  ```

---

### Task 8: 縦タブ（VerticalSidebarView）にドラッグ並び替えを追加

**Files:**
- Modify: `Sources/Views/VerticalSidebarView.swift`

**変更1**: `SidebarTabRow` の `.contextMenu { ... }` の後に追加:

```swift
.onDrag {
    NSItemProvider(object: tab.id.uuidString as NSString)
}
.onDrop(of: [.plainText], delegate: SidebarDropDelegate(tab: tab, appState: appState))
```

**変更2**: `VerticalSidebarView.swift` の末尾に追加:

```swift
// MARK: - SidebarDropDelegate

private struct SidebarDropDelegate: DropDelegate {
    let tab: TabItem
    let appState: AppState

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.plainText]).first else { return false }
        item.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { data, _ in
            guard let data = data as? Data,
                  let uuidString = String(data: data, encoding: .utf8),
                  let sourceID = UUID(uuidString: uuidString)
            else { return }
            Task { @MainActor in
                appState.moveTab(from: sourceID, to: tab.id)
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
```

- [ ] `SidebarTabRow` に `.onDrag` / `.onDrop` を追加する
- [ ] `SidebarDropDelegate` struct を追加する
- [ ] ビルド確認（`⌘B`）
- [ ] 動作確認: 縦タブもドラッグ並び替えができること、ピン留めタブをまたいだ移動が無効なことを確認
- [ ] コミット:
  ```bash
  git add Sources/Views/VerticalSidebarView.swift
  git commit -m "feat: 縦タブのドラッグ並び替えを実装"
  ```
