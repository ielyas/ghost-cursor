import AppKit
import GhostCursorKit

/// Opens the Settings scene and brings it to the front.
///
/// `LSUIElement` apps stay accessory, so a Settings window opened via
/// `SettingsLink` lands behind whatever is frontmost. Temporarily switching to
/// `.regular` (same approach Sparkle uses) lets the window take focus; restore
/// `.accessory` when Settings closes.
///
/// Prefer `SettingsLink` for the menu-bar path — `showSettingsWindow:` is a
/// no-op on newer macOS. The selector overload remains for first-run only.
enum SettingsWindowOpener {
    private static let settingsWindowIdentifier = "com.apple.SwiftUI.Settings"

    /// First-run and other non-SwiftUI call sites.
    @MainActor
    static func open() {
        prepareToPresent()

        for name in ["showSettingsWindow:", "showPreferencesWindow:"] {
            let selector = NSSelectorFromString(name)
            if NSApp.sendAction(selector, to: nil, from: nil) {
                Log.lifecycle.info("Opened Settings via \(name, privacy: .public)")
                scheduleBringForward()
                return
            }
        }

        Log.lifecycle.error("Could not open the Settings window programmatically")
        restoreAccessoryPolicyIfIdle()
    }

    @MainActor
    static func prepareToPresent() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    @MainActor
    static func bringSettingsWindowForward() {
        prepareToPresent()
        for window in NSApp.windows where isSettingsWindow(window) {
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    /// Call from Settings `.onDisappear`. Leaves `.regular` alone if another
    /// titled window (e.g. Sparkle) is still up.
    @MainActor
    static func noteSettingsClosed() {
        // Defer so the closing window is gone from `NSApp.windows` before we look.
        DispatchQueue.main.async {
            restoreAccessoryPolicyIfIdle()
        }
    }

    @MainActor
    private static func scheduleBringForward() {
        DispatchQueue.main.async {
            bringSettingsWindowForward()
        }
    }

    @MainActor
    private static func restoreAccessoryPolicyIfIdle() {
        let hasTitledWindow = NSApp.windows.contains { window in
            window.isVisible && window.styleMask.contains(.titled)
        }
        guard !hasTitledWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        if window.identifier?.rawValue == settingsWindowIdentifier {
            return true
        }
        guard window.styleMask.contains(.titled) else { return false }
        let title = window.title
        return title.localizedCaseInsensitiveContains("settings")
            || title.localizedCaseInsensitiveContains("preferences")
            || title.localizedCaseInsensitiveContains("ghostcursor")
    }
}
