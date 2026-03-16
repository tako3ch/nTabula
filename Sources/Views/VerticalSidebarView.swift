import SwiftUI

// MARK: - VerticalSidebarView（Arc 風縦タブサイドバー）

struct VerticalSidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("nTabula")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    appState.addNewTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // ピン留めセクション
            let pinnedTabs = appState.sortedTabs.filter(\.isPinned)
            if !pinnedTabs.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("固定")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 2)

                    ForEach(pinnedTabs) { tab in
                        SidebarTabRow(tab: tab)
                            .padding(.horizontal, 8)
                    }
                }

                Divider()
                    .padding(.vertical, 4)
            }

            // 通常タブリスト
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(appState.sortedTabs.filter({ !$0.isPinned })) { tab in
                        SidebarTabRow(tab: tab)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)
            Divider()

            // フッター：DB 名 + 設定ボタン
            HStack(spacing: 6) {
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
                Spacer()
                Button { openSettings() } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.windowBackground)
    }
}

// MARK: - SidebarTabRow

struct SidebarTabRow: View {
    @Environment(AppState.self) private var appState
    let tab: TabItem
    @State private var isHovering = false

    private var isActive: Bool { appState.activeTabID == tab.id }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.isPinned ? "pin.fill" : "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 16)

            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isActive ? Color.primary : Color.secondary)

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .opacity(tab.isDirty && !isHovering ? 1 : 0)

                if !tab.isPinned {
                    Button {
                        appState.closeTab(tab)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .opacity(isHovering ? 1 : 0)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive
                      ? Color.accentColor.opacity(0.15)
                      : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { appState.activeTabID = tab.id }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(tab.isPinned ? "ピン解除" : "ピン留め") {
                appState.togglePin(tab)
            }
            Divider()
            Button("タブを閉じる", role: .destructive) {
                appState.closeTab(tab)
            }
            .disabled(tab.isPinned)
        }
        .onDrag {
            NSItemProvider(object: tab.id.uuidString as NSString)
        }
        .onDrop(of: [.plainText], delegate: SidebarDropDelegate(tab: tab, appState: appState))
    }
}

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
