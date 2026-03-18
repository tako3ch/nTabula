import SwiftUI
import UniformTypeIdentifiers

/// TabBarView・VerticalSidebarView 両方で使うタブ移動 DropDelegate
struct TabMoveDropDelegate: DropDelegate {
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
