import GhostCursorKit
import SwiftUI

struct MenuBarContent: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Toggle("Auto-Hide Cursor", isOn: Binding(
            get: { appState.autoHideEnabled },
            set: { appState.autoHideEnabled = $0 }
        ))

        Picker("Hide After", selection: Binding(
            get: { appState.hideDelaySeconds },
            set: { appState.hideDelaySeconds = $0 }
        )) {
            ForEach(HideDelay.allowedValues, id: \.self) { value in
                Text(HideDelay.label(for: value)).tag(value)
            }
        }

        Divider()

        #if DEBUG
        // Keep all four. They are the only way to reproduce a background hide and
        // a manual repair during QA.
        Button("Hide Cursor Now (debug)") {
            appState.cursorHider.hide()
        }

        Button("Hide Cursor in 5s (debug)") {
            appState.cursorHider.debugHideAfterDelay()
        }

        Button("Reassert in 5s (debug)") {
            appState.cursorHider.debugReassertAfterDelay()
        }

        Button("Show Cursor (debug)") {
            appState.cursorHider.show()
        }

        Divider()
        #endif

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit GhostCursor") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
