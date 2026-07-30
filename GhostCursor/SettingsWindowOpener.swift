import AppKit
import GhostCursorKit

/// Opens the Settings scene from code.
///
/// `LSUIElement` breaks the normal path: with no dock icon the app is not
/// activated, so the Settings window would open behind everything or not at all.
/// The selector is the only supported way to reach a SwiftUI `Settings` scene
/// programmatically, and its name changed in macOS 13, hence the fallback.
enum SettingsWindowOpener {
    @MainActor
    static func open() {
        NSApp.activate()

        for name in ["showSettingsWindow:", "showPreferencesWindow:"] {
            let selector = NSSelectorFromString(name)
            if NSApp.sendAction(selector, to: nil, from: nil) {
                Log.lifecycle.info("Opened Settings via \(name, privacy: .public)")
                return
            }
        }

        Log.lifecycle.error("Could not open the Settings window programmatically")
    }
}
