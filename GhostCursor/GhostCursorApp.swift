import GhostCursorKit
import SwiftUI

@main
struct GhostCursorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("GhostCursor", systemImage: "cursorarrow") {
            MenuBarContent()
        }

        Settings {
            SettingsView()
        }
    }
}
