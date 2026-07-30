import AppKit
import GhostCursorKit
import SwiftUI

/// A transparent overlay that captures one key combination while recording.
///
/// It draws nothing — the surrounding SwiftUI view renders the box and the label
/// — and exists only because SwiftUI has no way to observe a raw key event
/// together with its modifiers. Keeping the AppKit surface to "capture and
/// report" means all the state lives in SwiftUI, where it is visible.
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool

    /// A valid combination was captured.
    var onCapture: (HotKeyCombination) -> Void
    /// Delete or Backspace was pressed: unassign.
    var onClear: () -> Void
    /// A key was pressed with no Command, Option or Control. The combination is
    /// rejected — reported so the UI can explain why rather than appearing dead.
    var onRejected: () -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: KeyCaptureView, context: Context) {
        context.coordinator.parent = self

        // Driving first responder from `updateNSView` keeps SwiftUI's
        // `isRecording` the single source of truth; the view never decides for
        // itself that it is recording.
        if isRecording, view.window?.firstResponder !== view {
            view.window?.makeFirstResponder(view)
        } else if !isRecording, view.window?.firstResponder === view {
            view.window?.makeFirstResponder(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator {
        var parent: ShortcutRecorderView

        init(parent: ShortcutRecorderView) {
            self.parent = parent
        }

        /// - Returns: true when the event was consumed and must not travel on.
        func handle(_ event: NSEvent) -> Bool {
            guard parent.isRecording else { return false }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var modifiers: HotKeyModifiers = []
            if flags.contains(.command) { modifiers.insert(.command) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.shift) { modifiers.insert(.shift) }

            let keyCode = Int(event.keyCode)

            // Escape cancels and Delete clears, but only unmodified — otherwise
            // ⌥⌘Escape could never be recorded even though it is a legal choice.
            if modifiers.isEmpty, keyCode == 53 {
                parent.isRecording = false
                return true
            }
            if modifiers.isEmpty, keyCode == 51 {
                parent.onClear()
                parent.isRecording = false
                return true
            }

            guard let combination = HotKeyCombination(keyCode: keyCode, modifiers: modifiers) else {
                parent.onRejected()
                return true
            }

            parent.onCapture(combination)
            parent.isRecording = false
            return true
        }

        func endRecording() {
            parent.isRecording = false
        }
    }

    /// The `NSView` that actually receives the events.
    final class KeyCaptureView: NSView {
        weak var coordinator: Coordinator?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard coordinator?.handle(event) == true else {
                super.keyDown(with: event)
                return
            }
        }

        /// Command combinations are offered as key equivalents before `keyDown`,
        /// so without this ⌘Q would quit the app while the user was trying to
        /// record it.
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            coordinator?.handle(event) == true
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
        }

        override func resignFirstResponder() -> Bool {
            coordinator?.endRecording()
            return super.resignFirstResponder()
        }
    }
}
