import SwiftUI
import AppKit
import Sparkle

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var tokenInput: String = ""
    @State private var isLoadingDBs = false
    @State private var isLoadingPages = false
    @State private var dbError: String? = nil
    @State private var pagesError: String? = nil

    private var updater: SPUUpdater {
        (NSApp.delegate as! AppDelegate).updaterController.updater
    }

    var body: some View {
        @Bindable var state = appState

        TabView {
            // MARK: アップデート
            UpdateSettingsTab(updater: updater)
                .tabItem { Label("アップデート", systemImage: "arrow.down.circle") }

            // MARK: 一般設定
            Form {
                Section("エディタ") {
                    Picker("フォント", selection: $state.editorFontName) {
                        Text("SF Mono（デフォルト）").tag("")
                        Divider()
                        ForEach(monospacedFonts, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    HStack {
                        Text("フォントサイズ")
                        Slider(value: $state.editorFontSize, in: 10...28, step: 1)
                            .onChange(of: appState.editorFontSize) {
                                PersistenceManager.shared.saveFontSize(appState.editorFontSize)
                            }
                        Text("\(Int(appState.editorFontSize))pt")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                Section("タブ") {
                    Picker("レイアウト", selection: $state.tabLayoutMode) {
                        ForEach(TabLayoutMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appState.tabLayoutMode) {
                        PersistenceManager.shared.saveTabLayoutMode(appState.tabLayoutMode)
                    }
                }

                Section("保存") {
                    Toggle("自動保存（入力後 3 秒）", isOn: $state.autoSaveEnabled)
                        .onChange(of: appState.autoSaveEnabled) {
                            PersistenceManager.shared.saveAutoSaveEnabled(appState.autoSaveEnabled)
                        }
                }

                Section("グローバルホットキー") {
                    Picker("ウィンドウ表示切り替え", selection: Binding(
                        get: { appState.globalHotKeyPreset },
                        set: { appState.updateHotKeyPreset($0) }
                    )) {
                        ForEach(GlobalHotKeyPreset.allCases, id: \.self) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    if appState.globalHotKeyPreset == .cmdShiftN {
                        Label("⌘⇧N は Finder・Chrome 等のショートカットと競合する可能性があります", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("一般", systemImage: "gear") }

            // MARK: Notion 設定
            Form {
                Section("Notion 接続") {
                    SecureField("Integration Token", text: $tokenInput)
                        .font(.system(.body, design: .monospaced))

                    HStack {
                        Button("保存して接続") {
                            appState.updateNotionToken(tokenInput)
                            Task { await loadDatabases() }
                        }
                        .disabled(tokenInput.isEmpty)

                        Spacer()

                        Link("Token を取得",
                             destination: URL(string: "https://www.notion.so/my-integrations")!)
                            .font(.footnote)
                    }
                }

                Section("保存先") {
                    Picker("タイプ", selection: Binding(
                        get: { appState.notionSaveTarget },
                        set: {
                            appState.notionSaveTarget = $0
                            PersistenceManager.shared.saveNotionSaveTarget($0)
                        }
                    )) {
                        Text("データベース").tag(NotionSaveTarget.database)
                        Text("ページ（子ページ）").tag(NotionSaveTarget.page)
                    }
                    .pickerStyle(.segmented)
                }

                if appState.notionSaveTarget == .database {
                    Section("データベース") {
                        if isLoadingDBs {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("読み込み中...").foregroundStyle(.secondary)
                            }
                        } else if appState.databases.isEmpty {
                            Text("データベースが見つかりません")
                                .foregroundStyle(.secondary)
                            Button("再読み込み") {
                                Task { await loadDatabases() }
                            }
                            .disabled(appState.notionToken.isEmpty)
                        } else {
                            Picker("接続先 DB", selection: Binding(
                                get: { appState.selectedDatabaseID },
                                set: {
                                    appState.selectedDatabaseID = $0
                                    PersistenceManager.shared.saveSelectedDatabaseID($0)
                                }
                            )) {
                                Text("未選択").tag("")
                                ForEach(appState.databases) { db in
                                    Text(db.displayTitle).tag(db.id)
                                }
                            }
                        }

                        if let err = dbError {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    Section("親ページ") {
                        if isLoadingPages {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("読み込み中...").foregroundStyle(.secondary)
                            }
                        } else if appState.pages.isEmpty {
                            Text("ページが見つかりません")
                                .foregroundStyle(.secondary)
                            Button("ページ一覧を取得") {
                                Task { await loadPages() }
                            }
                            .disabled(appState.notionToken.isEmpty)
                        } else {
                            Picker("親ページ", selection: Binding(
                                get: { appState.selectedParentPageID },
                                set: {
                                    appState.selectedParentPageID = $0
                                    PersistenceManager.shared.saveSelectedParentPageID($0)
                                }
                            )) {
                                Text("未選択").tag("")
                                ForEach(appState.pages) { page in
                                    Text(page.displayTitle).tag(page.id)
                                }
                            }
                            Button("再読み込み") {
                                Task { await loadPages() }
                            }
                            .font(.footnote)
                        }

                        if let err = pagesError {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Notion", systemImage: "doc.richtext") }
            .onAppear {
                tokenInput = appState.notionToken
                if appState.databases.isEmpty && !appState.notionToken.isEmpty {
                    Task { await loadDatabases() }
                }
            }
            // MARK: ショートカット一覧
            List {
                Section("タブ操作") {
                    ShortcutRow(keys: "⌘T", description: "新規タブ")
                    ShortcutRow(keys: "⌘W", description: "タブを閉じる")
                    ShortcutRow(keys: "⌘⇧T", description: "閉じたタブを復元")
                    ShortcutRow(keys: "⌘1〜9", description: "タブを番号で切り替え")
                }
                Section("ファイル") {
                    ShortcutRow(keys: "⌘S", description: "Notion に保存")
                    ShortcutRow(keys: "⌘⇧E", description: "Markdown としてエクスポート")
                }
                Section("表示") {
                    ShortcutRow(keys: "⌘P", description: "プレビュー表示切り替え")
                    ShortcutRow(keys: "⌘,", description: "設定を開く")
                }
                Section("グローバル") {
                    ShortcutRow(keys: appState.globalHotKeyPreset.label.components(separatedBy: " ").first ?? "⌃⇧N",
                                description: "ウィンドウ表示 / 非表示")
                }
            }
            .tabItem { Label("ショートカット", systemImage: "keyboard") }
        }
        .frame(width: 500, height: 440)
    }

    private func loadDatabases() async {
        isLoadingDBs = true
        dbError = nil
        await appState.fetchDatabases()
        if let err = appState.syncError { dbError = err }
        isLoadingDBs = false
    }

    private func loadPages() async {
        isLoadingPages = true
        pagesError = nil
        defer { isLoadingPages = false }
        await appState.fetchPages()
        if let err = appState.syncError { pagesError = err }
    }

    private var monospacedFonts: [String] {
        NSFontManager.shared.availableFontFamilies
            .filter { name in
                guard let font = NSFont(name: name, size: 12) else { return false }
                return font.isFixedPitch
            }
            .sorted()
    }
}

// MARK: - UpdateSettingsTab

private struct UpdateSettingsTab: View {
    @ObservedObject var updater: SPUUpdater

    var body: some View {
        Form {
            Section {
                CheckForUpdatesView(updater: updater)

                Toggle("自動的にアップデートを確認", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))

                Toggle("統計情報を送信（匿名）", isOn: Binding(
                    get: { updater.sendsSystemProfile },
                    set: { updater.sendsSystemProfile = $0 }
                ))
            }

            Section {
                LabeledContent("現在のバージョン") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                        .foregroundStyle(.secondary)
                }
                if let lastCheck = updater.lastUpdateCheckDate {
                    LabeledContent("最後に確認した日時") {
                        Text(lastCheck, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - ShortcutRow

private struct ShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack {
            Text(description)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
