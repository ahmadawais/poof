import AppKit
import Carbon.HIToolbox

/// Global hotkey via Carbon RegisterEventHotKey: the only one that needs no Accessibility / Input Monitoring.
final class HotKey {
    /// The suggested shortcut: ⌃⌥K.
    static let keyCode = UInt32(kVK_ANSI_K)
    static let modifiers = UInt32(controlKey | optionKey)
    static let display = ["⌃", "⌥", "K"]

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?
    private static weak var shared: HotKey?

    init() {
        HotKey.shared = self
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.shared?.action?() }
            return noErr
        }, 1, &spec, nil, &handler)
    }

    /// False when this process already holds it. Another app holding ⌃⌥K still succeeds; both then fire.
    @discardableResult
    func register() -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x504F_4F46), id: 1) // 'POOF'
        let status = RegisterEventHotKey(Self.keyCode, Self.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status != noErr { ref = nil; log.error("Hotkey ⌃⌥K: \(status, privacy: .public)") }
        return status == noErr
    }

    var isRegistered: Bool { ref != nil }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}
