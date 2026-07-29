import GhostCursorKit
import SwiftUI

@main
struct GhostCursorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("GhostCursor", systemImage: "cursorarrow") {
            MenuBarContent()
                .environment(appState)
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
