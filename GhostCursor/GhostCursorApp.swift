import GhostCursorKit
import SwiftUI

@main
struct GhostCursorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environment(appState)
        } label: {
            // Shape, not tint: the spec's accessibility rule forbids state shown
            // by colour alone, and the menu bar renders template images in a
            // single colour anyway.
            Image(systemName: appState.autoHideEnabled ? "cursorarrow.slash" : "cursorarrow")
                .accessibilityLabel(
                    appState.autoHideEnabled
                        ? "GhostCursor, auto-hide on"
                        : "GhostCursor, auto-hide off"
                )
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
