import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var appState: AppState?
    private let hotKeyService = HotKeyService()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKeyService.onHotKeyPressed = { [weak self] in
            self?.toggleMainWindow()
        }
        let preset = PersistenceManager.shared.loadHotKeyPreset()
        hotKeyService.register(preset: preset)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotKeyPresetChanged(_:)),
            name: .ntHotKeyPresetChanged,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let appState {
            PersistenceManager.shared.saveTabs(appState.tabs)
            PersistenceManager.shared.saveActiveTabID(appState.activeTabID)
        }
        hotKeyService.unregister()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Window Management

    /// AppState 注入後にウィンドウを設定する（nTabulaApp.swift の onAppear から呼ぶ）
    func configure(with state: AppState, window: NSWindow?) {
        self.appState = state
        guard let window else { return }
        window.delegate = self
        if let frame = PersistenceManager.shared.loadWindowFrame() {
            window.setFrame(frame, display: false)
        }
    }

    // MARK: - Hot Key

    @objc private func hotKeyPresetChanged(_ notification: Notification) {
        guard let preset = notification.object as? GlobalHotKeyPreset else { return }
        hotKeyService.reconfigure(preset: preset)
    }

    private func toggleMainWindow() {
        let windows = NSApp.windows.filter { $0.canBecomeKey }
        if let window = windows.first {
            if window.isKeyWindow {
                window.orderOut(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
            }
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - NSWindowDelegate（フレーム保存）

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        PersistenceManager.shared.saveWindowFrame(window.frame)
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        PersistenceManager.shared.saveWindowFrame(window.frame)
    }
}
