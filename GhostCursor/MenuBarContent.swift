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
