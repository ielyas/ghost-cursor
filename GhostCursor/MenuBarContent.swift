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

        Button("Check for Updates…") {
            appState.updaterManager.checkForUpdates()
        }
        .disabled(!appState.updaterManager.canCheckForUpdates)

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
