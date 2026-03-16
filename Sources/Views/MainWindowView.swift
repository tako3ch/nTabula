import SwiftUI

struct MainWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            if appState.tabLayoutMode == .horizontal {
                horizontalLayout
            } else {
                verticalLayout
            }
        }
        .frame(minWidth: 650, minHeight: 400)
        // Cmd+S → Notion 保存
        .onReceive(NotificationCenter.default.publisher(for: .ntSaveDocument)) { _ in
            Task { await appState.syncActiveTab() }
        }
    }

    // MARK: - Layouts

    private var horizontalLayout: some View {
        VStack(spacing: 0) {
            TabBarView()
            titleField
            editorOrPreview
            statusBar
        }
        .toolbar { toolbarItems }
    }

    private var verticalLayout: some View {
        HStack(spacing: 0) {
            VerticalSidebarView()
                .frame(width: 210)
            Divider()
            VStack(spacing: 0) {
                titleField
                editorOrPreview
                statusBar
            }
        }
        .toolbar { toolbarItems }
    }

    @ViewBuilder
    private var editorOrPreview: some View {
        if appState.isPreviewVisible {
            MarkdownPreviewView(markdown: appState.activeTab?.content ?? "")
                .background(Color(.textBackgroundColor))
        } else {
            EditorView()
                .background(Color(.textBackgroundColor))
        }
    }

    private var titleField: some View {
        TextField(
            "タイトル",
            text: Binding(
                get: { appState.activeTab?.title ?? "" },
                set: { title in
                    if let tabID = appState.activeTabID {
                        appState.updateTitle(title, for: tabID)
                    }
                }
            )
        )
        .onSubmit {
            NotificationCenter.default.post(name: .ntFocusEditor, object: nil)
        }
        .textFieldStyle(.plain)
        .font(.system(size: 18, weight: .semibold))
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(Color(.textBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            // DB 切り替えメニュー
            dbSelectorMenu

            // 文字数・行数カウント
            if let tab = appState.activeTab {
                let charCount = tab.content.count
                let lineCount = tab.content.isEmpty ? 0 : tab.content.components(separatedBy: .newlines).count
                Text("\(lineCount) 行  \(charCount) 文字")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // 同期ステータス
            if appState.isSyncing {
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    Text("同期中...").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            } else if let tab = appState.activeTab {
                HStack(spacing: 4) {
                    if tab.isDirty {
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                    }
                    Text(tab.isDirty ? "未保存" : "保存済み")
                        .font(.system(size: 11))
                        .foregroundStyle(tab.isDirty ? .orange : .secondary)
                }
            }

            // エラー表示
            if let err = appState.syncError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .help(err)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 8) {
                // タブレイアウト切り替え
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let next: TabLayoutMode = appState.tabLayoutMode == .horizontal ? .vertical : .horizontal
                        appState.tabLayoutMode = next
                        PersistenceManager.shared.saveTabLayoutMode(next)
                    }
                } label: {
                    Image(systemName: appState.tabLayoutMode == .horizontal
                          ? "sidebar.left" : "rectangle.grid.1x2")
                }
                .help(appState.tabLayoutMode == .horizontal ? "縦タブに切り替え" : "横タブに切り替え")

                // Notion 保存
                Button {
                    Task { await appState.syncActiveTab() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .disabled(appState.isSyncing || !appState.hasValidSaveTarget)
                .help("Notion に保存 (⌘S)")
            }
        }
    }
}
