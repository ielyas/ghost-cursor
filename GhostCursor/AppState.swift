import Foundation
import GhostCursorKit
import Observation

/// Single source of truth for app-wide state.
///
/// A singleton because this is an agent app with exactly one instance, and
/// because `AppDelegate` — which SwiftUI constructs independently via
/// `@NSApplicationDelegateAdaptor` — needs the same instance the scenes use.
@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    let cursorHider: CursorHider
    let idleMonitor: IdleMonitor
    /// Retained for the same reason as `reassertionCoordinator`: it owns the
    /// observers and the display callback. Dropping it silently removes the
    /// safety net.
    private let systemEventMonitor: SystemEventMonitor
    /// Retained, not optional: it owns the notification observers that partially
    /// cover the one drift case the idle loop cannot see — a system reveal with no
    /// mouse movement afterwards. Dropping it silently regresses that.
    private let reassertionCoordinator: CursorReassertionCoordinator

    let loginItemManager = LoginItemManager()

    var autoHideEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoHideEnabled, forKey: Defaults.Key.autoHideEnabled)
            idleMonitor.featureEnabled = autoHideEnabled
        }
    }

    var hideDelaySeconds: TimeInterval {
        didSet {
            UserDefaults.standard.set(hideDelaySeconds, forKey: Defaults.Key.hideDelaySeconds)
            idleMonitor.hideDelay = hideDelaySeconds
        }
    }

    private init() {
        Defaults.register()

        let hider = CursorHider()
        cursorHider = hider
        idleMonitor = IdleMonitor(cursorHider: hider)
        systemEventMonitor = SystemEventMonitor(idleMonitor: idleMonitor)
        reassertionCoordinator = CursorReassertionCoordinator(cursorHider: hider)
        reassertionCoordinator.start()

        autoHideEnabled = UserDefaults.standard.bool(forKey: Defaults.Key.autoHideEnabled)
        // Clamped because a stored value may predate a change to the allowed
        // set, or have been edited by hand with `defaults write`.
        hideDelaySeconds = HideDelay.clamped(
            UserDefaults.standard.double(forKey: Defaults.Key.hideDelaySeconds)
        )

        idleMonitor.featureEnabled = autoHideEnabled
        idleMonitor.hideDelay = hideDelaySeconds
    }

    func start() {
        idleMonitor.start()
        loginItemManager.start()
        systemEventMonitor.start()
    }
}
