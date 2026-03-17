import SwiftUI
import Sparkle

// メニューバーおよび設定ビューから使う「アップデートを確認」ボタン
struct CheckForUpdatesView: View {
    @ObservedObject var updater: SPUUpdater

    var body: some View {
        Button("アップデートを確認...") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
