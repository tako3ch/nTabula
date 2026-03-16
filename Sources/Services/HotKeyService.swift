import Carbon.HIToolbox

/// Carbon の RegisterEventHotKey を使ってグローバルホットキー (Ctrl+Shift+N) を登録する
final class HotKeyService {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onHotKeyPressed: (() -> Void)?

    deinit { unregister() }

    func register() {
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

        // Ctrl+Shift+N を登録
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x6E546162) // 'nTab'
        hotKeyID.id = 1

        RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            UInt32(controlKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
        globalHotKeyService = nil
    }
}

// コールバックから参照するためのグローバル（1インスタンスのみ想定）
private var globalHotKeyService: HotKeyService?
