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
    }

    static func register() {
        UserDefaults.standard.register(defaults: [
            Key.autoHideEnabled: true,
            Key.hideDelaySeconds: HideDelay.defaultValue,
            Key.launchAtLogin: true
        ])
    }
}
