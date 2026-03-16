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
            // プレビュー切り替え（Cmd+P）
            CommandGroup(replacing: .textEditing) {
                Button(appState.isPreviewVisible ? "エディタを表示" : "プレビューを表示") {
                    appState.isPreviewVisible.toggle()
                }
                .keyboardShortcut("p", modifiers: .command)
            }
            // 設定（Cmd+,）
            CommandGroup(replacing: .appSettings) {
                SettingsLink {
                    Text("設定...")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
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

                Button("Markdown としてエクスポート...") {
                    exportActiveTab(appState)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appState.activeTab == nil)
            }
            // タブを閉じる + 復元 + Cmd+1〜9 でタブ切り替え
            CommandGroup(replacing: .windowList) {
                Button("タブを閉じる") {
                    if let tab = appState.activeTab {
                        appState.closeTab(tab)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.activeTab == nil)

                Button("閉じたタブを復元") {
                    appState.restoreLastClosedTab()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(!appState.canRestoreTab)

                Divider()

                ForEach(Array(appState.sortedTabs.prefix(9).enumerated()), id: \.element.id) { index, tab in
                    Button(tab.title.isEmpty ? "タブ \(index + 1)" : tab.title) {
                        appState.switchToTab(at: index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }

        // 設定ウィンドウ
        Settings {
            SettingsView()
                .environment(appState)
        }
    }

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
}
