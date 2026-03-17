import SwiftUI
import UniformTypeIdentifiers

// MARK: - TabBarView（横タブ）

struct TabBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            // ピン留めタブ（固定エリア）
            let pinned = appState.sortedTabs.filter(\.isPinned)
            if !pinned.isEmpty {
                HStack(spacing: 1) {
                    ForEach(pinned) { tab in
                        TabItemButton(tab: tab)
                    }
                }
                .padding(.horizontal, 4)

                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, 4)
            }

            // スクロール可能な通常タブ
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(appState.sortedTabs.filter({ !$0.isPinned })) { tab in
                        TabItemButton(tab: tab)
                    }
                }
                .padding(.horizontal, 4)
            }

            // 新規タブボタン
            Button {
                appState.addNewTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .frame(height: 38)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - 個別タブボタン

struct TabItemButton: View {
    @Environment(AppState.self) private var appState
    let tab: TabItem
    @State private var isHovering = false

    private var isActive: Bool { appState.activeTabID == tab.id }
    // AppState から常に最新値を取得する（TabItem.== は id のみ比較のため SwiftUI が再描画をスキップする問題を回避）
    private var currentTab: TabItem { appState.tabs.first(where: { $0.id == tab.id }) ?? tab }

    var body: some View {
        HStack(spacing: 4) {
            if currentTab.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }

            Text(currentTab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 160)

            // 未保存インジケーター / 閉じるボタン
            ZStack {
                if currentTab.isDirty {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .opacity(isHovering && !currentTab.isPinned ? 0 : 1)
                }
                if isHovering && !currentTab.isPinned {
                    Button {
                        appState.closeTab(tab)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive
                      ? Color(.controlBackgroundColor)
                      : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { appState.activeTabID = tab.id }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(currentTab.isPinned ? "ピン解除" : "ピン留め") {
                appState.togglePin(tab)
            }
            Divider()
            Button("タブを閉じる", role: .destructive) {
                appState.closeTab(tab)
            }
            .disabled(currentTab.isPinned)
        }
        .onDrag {
            NSItemProvider(object: tab.id.uuidString as NSString)
        }
        .onDrop(of: [.plainText], delegate: TabDropDelegate(tab: tab, appState: appState))
    }
}

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
