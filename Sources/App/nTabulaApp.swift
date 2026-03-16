import SwiftUI

// Sendable クロージャ内で observer を自己参照するためのラッパー
// nonisolated(unsafe) はローカル変数に適用不可のため final class + @unchecked Sendable を使用
private final class ObserverToken: @unchecked Sendable {
    var value: (any NSObjectProtocol)?
}

@main
struct nTabulaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appState)
                .onAppear {
                    // キーウィンドウが確定してから AppDelegate に渡す
                    if let window = NSApplication.shared.keyWindow {
                        appDelegate.configure(with: appState, window: window)
                    } else {
                        // ObserverToken: Sendable クロージャ内で observer を自己参照するパターン
                        // クロージャが observer を capture した後に変異させる必要があるため
                        // final class ラッパーで参照型のセマンティクスを利用する
                        let token = ObserverToken()
                        token.value = NotificationCenter.default.addObserver(
                            forName: NSWindow.didBecomeKeyNotification,
                            object: nil,
                            queue: .main
                        ) { [token] notification in
                            guard let window = notification.object as? NSWindow else { return }
                            appDelegate.configure(with: appState, window: window)
                            if let obs = token.value { NotificationCenter.default.removeObserver(obs) }
                        }
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 960, height: 640)
        .commands {
            // 新規タブ
            CommandGroup(replacing: .newItem) {
                Button("新規タブ") {
                    appState.addNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            // 保存（Notion 同期）
            CommandGroup(replacing: .saveItem) {
                Button("Notion に保存") {
                    NotificationCenter.default.post(name: .ntSaveDocument, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.selectedDatabaseID.isEmpty)
            }
            // タブを閉じる
            CommandGroup(replacing: .windowList) {
                Button("タブを閉じる") {
                    if let tab = appState.activeTab {
                        appState.closeTab(tab)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.activeTab == nil)
            }
        }

        // 設定ウィンドウ
        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
