import Carbon.HIToolbox
import GhostCursorKit
import Observation

/// Registers one global hotkey with Carbon and reports what happened.
///
/// Carbon's `RegisterEventHotKey` is used rather than
/// `NSEvent.addGlobalMonitorForEvents` because it needs **no Accessibility
/// permission**, which is the product's headline constraint. Do not replace it.
///
/// Lives in the app target because `GetApplicationEventTarget()` is an
/// app-lifecycle API and `Core` stays free of those.
@Observable
@MainActor
final class HotKeyManager {
    /// Set when registration failed, for the recorder to display inline. Nil when
    /// the last attempt succeeded or when no shortcut is assigned.
    private(set) var lastErrorMessage: String?

    /// Invoked on the main actor when the registered combination is pressed.
    var onTrigger: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    /// Identifies our hotkey inside the Carbon callback. Any four-character code
    /// works as long as it is ours; 'GHCS' is GhostCursor.
    private static let signature: OSType = 0x47484353
    private static let hotKeyID: UInt32 = 1

    /// The Carbon callback is a bare C function pointer and cannot capture
    /// context, so it reaches the live manager through this. There is exactly one
    /// `HotKeyManager`, owned by `AppState` for the process lifetime.
    private nonisolated(unsafe) static var trigger: (@Sendable () -> Void)?

    /// Applies a combination, replacing any previous one. Pass `nil` to unbind.
    func apply(_ combination: HotKeyCombination?) {
        lastErrorMessage = nil
        unregister()

        guard let combination else {
            Log.hotkey.info("No shortcut assigned")
            return
        }

        installHandlerIfNeeded()

        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combination.keyCode),
            carbonModifiers(from: combination.modifiers),
            EventHotKeyID(signature: Self.signature, id: Self.hotKeyID),
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else {
            // Verified 2026-07-29: Carbon returns success even for combinations
            // macOS itself owns (⌘Space registered fine), so this only catches
            // our own duplicates and outright failures. Conflicts with other apps
            // are undetectable here by design — the recorder warns from a static
            // list instead.
            lastErrorMessage = status == eventHotKeyExistsErr
                ? "That shortcut is already registered."
                : "macOS refused this shortcut (error \(status))."
            Log.hotkey.error("RegisterEventHotKey failed: \(status, privacy: .public)")
            return
        }

        hotKeyRef = reference
        Log.hotkey.info("Registered shortcut \(combination.displayString, privacy: .public)")
    }

    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private func carbonModifiers(from modifiers: HotKeyModifiers) -> UInt32 {
        // Explicit translation, so our persisted bit values and Carbon's masks
        // stay independent. Do not "simplify" this by storing Carbon masks.
        var mask: UInt32 = 0
        if modifiers.contains(.command) { mask |= UInt32(cmdKey) }
        if modifiers.contains(.option) { mask |= UInt32(optionKey) }
        if modifiers.contains(.control) { mask |= UInt32(controlKey) }
        if modifiers.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        Self.trigger = { [weak self] in
            MainActor.assumeIsolated {
                self?.onTrigger?()
            }
        }

        var specification = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var firedID = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &firedID
                )
                guard parameterStatus == noErr else { return parameterStatus }

                // Carbon delivers application-target events on the main thread,
                // but hopping explicitly costs nothing measurable for a toggle and
                // removes the need to assume it — an assumption that would trap
                // rather than degrade if it were ever wrong.
                DispatchQueue.main.async {
                    HotKeyManager.trigger?()
                }
                return noErr
            },
            1,
            &specification,
            nil,
            &eventHandler
        )

        if status != noErr {
            Log.hotkey.error("InstallEventHandler failed: \(status, privacy: .public)")
        }
    }
}
