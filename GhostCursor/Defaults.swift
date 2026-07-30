import Foundation
import GhostCursorKit

/// `UserDefaults` keys and their registered defaults.
///
/// Registration means a fresh install behaves correctly with no stored values,
/// so reads never need `??` fallbacks scattered around the app.
enum Defaults {
    enum Key {
        static let autoHideEnabled = "autoHideEnabled"
        static let hideDelaySeconds = "hideDelaySeconds"
        static let launchAtLogin = "launchAtLogin"
        /// Records that the first-run registration attempt happened, so the user
        /// turning the login item off in System Settings is never overridden.
        static let hasRequestedLoginItem = "hasRequestedLoginItem"
        /// Absent when no shortcut is assigned, which is a supported state — so
        /// these are deliberately left out of `register()`.
        static let hotKeyKeyCode = "hotKeyKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        /// Gates the one-time "open Settings so the user can pick a shortcut"
        /// flow. Deliberately unregistered: absent means "not yet run".
        static let hasCompletedFirstRun = "hasCompletedFirstRun"
    }

    static func register() {
        UserDefaults.standard.register(defaults: [
            Key.autoHideEnabled: true,
            Key.hideDelaySeconds: HideDelay.defaultValue,
            Key.launchAtLogin: true
        ])
    }
}
