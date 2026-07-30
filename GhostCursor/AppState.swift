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
    let hotKeyManager = HotKeyManager()
    let updaterManager = UpdaterManager()

    /// Nil means unassigned, which is fully supported — the menu bar item is the
    /// primary control and the shortcut is an accelerator.
    var hotKey: HotKeyCombination? {
        didSet {
            UserDefaults.standard.set(hotKey?.keyCode, forKey: Defaults.Key.hotKeyKeyCode)
            UserDefaults.standard.set(hotKey?.modifiers.rawValue, forKey: Defaults.Key.hotKeyModifiers)
            hotKeyManager.apply(hotKey)
        }
    }

    /// Set by the first-run flow so `SettingsView` opens on the right pane. Not
    /// persisted — it is a one-shot request, not a setting.
    var pendingSettingsTab: SettingsTab?

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

        // `object(forKey:)` rather than `integer(forKey:)`: a missing key reads as
        // 0 from `integer`, and 0 is a real key code (`A`), so the unassigned
        // state would silently become ⌘A.
        let storedKeyCode = UserDefaults.standard.object(forKey: Defaults.Key.hotKeyKeyCode) as? Int
        let storedModifiers = UserDefaults.standard.object(forKey: Defaults.Key.hotKeyModifiers) as? Int
        hotKey = storedKeyCode.flatMap { keyCode in
            HotKeyCombination(
                keyCode: keyCode,
                modifiers: HotKeyModifiers(rawValue: storedModifiers ?? 0)
            )
        }

        idleMonitor.featureEnabled = autoHideEnabled
        idleMonitor.hideDelay = hideDelaySeconds
    }

    /// The global shortcut's only job.
    ///
    /// Flipping `autoHideEnabled` is sufficient to reveal a hidden cursor: the
    /// state machine returns `.showCursor` for any tick with the feature off, and
    /// the poll interval while hidden is 16 ms — inside the spec's 33 ms reveal
    /// target. Do not add a direct `cursorHider.show()` here; the one owner of
    /// cursor calls is the idle loop.
    func toggleAutoHide() {
        autoHideEnabled.toggle()
        Log.hotkey.info("Shortcut toggled auto-hide to \(self.autoHideEnabled, privacy: .public)")
    }

    func start() {
        idleMonitor.start()
        loginItemManager.start()
        systemEventMonitor.start()

        hotKeyManager.onTrigger = { [weak self] in
            self?.toggleAutoHide()
        }
        hotKeyManager.apply(hotKey)
    }
}
