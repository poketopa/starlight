import AppKit
import Carbon.HIToolbox

@MainActor
final class KeyboardShortcutController {
    enum Action: UInt32 {
        case toggle = 1
        case intensityUp = 2
        case intensityDown = 3
    }

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?
    private let onAction: (Action) -> Void

    init(onAction: @escaping (Action) -> Void) {
        self.onAction = onAction
    }

    func setShortcutsEnabled(_ enabled: Bool) {
        if enabled {
            registerDefaultShortcuts()
        } else {
            unregisterShortcuts()
        }
    }

    func shutdown() {
        unregisterShortcuts()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    func registerDefaultShortcuts() {
        unregisterShortcuts()

        let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        if handlerRef == nil {
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData in
                    guard let event, let userData else { return noErr }
                    var hotKeyID = EventHotKeyID()
                    let status = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )
                    guard status == noErr, let action = Action(rawValue: hotKeyID.id) else { return noErr }
                    let controller = Unmanaged<KeyboardShortcutController>
                        .fromOpaque(userData)
                        .takeUnretainedValue()
                    controller.onAction(action)
                    return noErr
                },
                1,
                [eventSpec],
                selfPointer,
                &handlerRef
            )
        }

        register(action: .toggle, keyCode: UInt32(kVK_ANSI_F))
        register(action: .intensityUp, keyCode: UInt32(kVK_ANSI_Equal))
        register(action: .intensityDown, keyCode: UInt32(kVK_ANSI_Minus))
    }

    private func unregisterShortcuts() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }

    private func register(action: Action, keyCode: UInt32) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType("FTRL".fourCharCode), id: action.rawValue)
        let status = RegisterEventHotKey(
            keyCode,
            UInt32(cmdKey | optionKey | controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKeyRefs[action.rawValue] = ref
        }
    }
}

private extension String {
    var fourCharCode: UInt32 {
        utf16.reduce(0) { ($0 << 8) + UInt32($1) }
    }
}
