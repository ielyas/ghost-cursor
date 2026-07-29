import GhostCursorKit
import SwiftUI

struct MenuBarContent: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        #if DEBUG
        Button("Hide Cursor Now (debug)") {
            appState.cursorHider.hide()
        }

        Button("Show Cursor (debug)") {
            appState.cursorHider.show()
        }

        Divider()

        Button("Re-apply Background Control in 5s (debug)") {
            appState.cursorHider.debugReapplyBackgroundControlAfterDelay()
        }

        Button("Force Extra Hide in 5s — DANGEROUS (debug)") {
            appState.cursorHider.debugForceHideAgainAfterDelay()
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
