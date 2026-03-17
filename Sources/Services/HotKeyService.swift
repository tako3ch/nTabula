import Carbon.HIToolbox

// MARK: - GlobalHotKeyPreset

/// グローバルホットキーのプリセット。Settings から変更可能。
enum GlobalHotKeyPreset: String, CaseIterable, Codable {
    case ctrlShiftN   // ⌃⇧N  デフォルト・他アプリと競合しにくい
    case cmdShiftN    // ⌘⇧N  Finder・Chrome 等と競合する可能性あり
    case ctrlOptionN  // ⌃⌥N  競合しにくい代替

    var label: String {
        switch self {
        case .ctrlShiftN:  "⌃⇧N  (Ctrl+Shift+N)"
        case .cmdShiftN:   "⌘⇧N  (Cmd+Shift+N)"
        case .ctrlOptionN: "⌃⌥N  (Ctrl+Option+N)"
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .ctrlShiftN:  UInt32(controlKey | shiftKey)
        case .cmdShiftN:   UInt32(cmdKey | shiftKey)
        case .ctrlOptionN: UInt32(controlKey | optionKey)
        }
    }
}

// MARK: - HotKeyService

/// Carbon の RegisterEventHotKey を使ってグローバルホットキーを登録する
final class HotKeyService {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onHotKeyPressed: (() -> Void)?

    deinit { unregister() }

    func register(preset: GlobalHotKeyPreset = .ctrlShiftN) {
        // グローバル参照をセット（コールバックからアクセスするため）
        globalHotKeyService = self

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // C 関数ポインタとして渡せる static クロージャ
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(
                event,
                UInt32(kEventParamDirectObject),
                UInt32(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )
            if hotkeyID.id == 1 {
                DispatchQueue.main.async { globalHotKeyService?.onHotKeyPressed?() }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1, &eventSpec,
            nil, &eventHandlerRef
        )

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x6E546162) // 'nTab'
        hotKeyID.id = 1

        RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            preset.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )
    }

    /// プリセット変更時に呼ぶ（登録解除 → 再登録）
    func reconfigure(preset: GlobalHotKeyPreset) {
        unregister()
        register(preset: preset)
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
        globalHotKeyService = nil
    }
}

// コールバックから参照するためのグローバル（1インスタンスのみ想定）
private var globalHotKeyService: HotKeyService?
