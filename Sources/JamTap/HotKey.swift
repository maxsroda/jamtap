import Carbon.HIToolbox

/// One system-wide keyboard shortcut. Registered through Carbon, which, unlike watching all key
/// presses, needs no Accessibility permission.
final class HotKey {
    /// Control-Option-Command-J.
    static let toggleRecordingKeyCode = UInt32(kVK_ANSI_J)
    static let toggleRecordingModifiers = UInt32(controlKey | optionKey | cmdKey)
    static let toggleRecordingKeyEquivalent = "j"

    private static var actionsByIdentifier: [UInt32: () -> Void] = [:]
    private static var handlerIsInstalled = false

    private var registration: EventHotKeyRef?

    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        HotKey.installHandlerOnce()
        let identifier = UInt32(HotKey.actionsByIdentifier.count + 1)
        let fourCharacterCodeJamT: OSType = 0x4A61_6D54  // "JamT"
        let status = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: fourCharacterCodeJamT, id: identifier),
                                         GetApplicationEventTarget(), 0, &registration)
        guard status == noErr else { return nil }  // for instance, another app already owns the shortcut
        HotKey.actionsByIdentifier[identifier] = action
    }

    private static func installHandlerOnce() {
        guard !handlerIsInstalled else { return }
        handlerIsInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            HotKey.actionsByIdentifier[pressed.id]?()
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
