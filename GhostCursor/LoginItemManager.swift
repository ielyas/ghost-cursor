import Foundation
import GhostCursorKit
import Observation
import ServiceManagement

/// Wraps `SMAppService.mainApp` so the UI can show and change the login-item state.
///
/// Lives in the app target rather than in `GhostCursorKit` because
/// `SMAppService.mainApp` resolves against the enclosing app bundle and is
/// meaningless in a `swift test` process, which has none.
///
/// The invariant: `SMAppService.mainApp.status` is the truth and the stored
/// preference is only a record of intent. The user can revoke the login item in
/// System Settings without telling the app, so the UI always reflects the status.
@Observable
@MainActor
final class LoginItemManager {
    /// True only when macOS confirms the login item is active.
    private(set) var isEnabled = false

    /// Set when macOS reports the item needs the user's approval in System
    /// Settings. Distinct from plain "off" because the fix is different — the user
    /// has to go approve it, and toggling here will not help.
    private(set) var requiresApproval = false

    /// Human-readable failure from the last register/unregister, for inline
    /// display. Nil when the last operation succeeded.
    private(set) var lastErrorMessage: String?

    func start() {
        refresh()
        registerOnFirstRunIfNeeded()
    }

    /// Re-reads the live status. Call on appear as well as at launch, so returning
    /// from System Settings shows the truth without a relaunch.
    func refresh() {
        let status = SMAppService.mainApp.status

        switch status {
        case .enabled:
            isEnabled = true
            requiresApproval = false
        case .requiresApproval:
            isEnabled = false
            requiresApproval = true
        case .notRegistered:
            isEnabled = false
            requiresApproval = false
        case .notFound:
            // The bundle is somewhere macOS will not register from, which is normal
            // when running out of Xcode's DerivedData. Report it rather than
            // pretending the toggle works.
            isEnabled = false
            requiresApproval = false
            lastErrorMessage = "macOS can't find this app bundle to register it. This is expected when running from Xcode."
        @unknown default:
            // `SMAppService.Status` is a non-frozen Apple enum, so a future OS may
            // add a case. Treat unknown as off and leave a trace rather than
            // asserting something untrue in the UI.
            isEnabled = false
            requiresApproval = false
            Log.lifecycle.error("Unhandled SMAppService status: \(status.rawValue, privacy: .public)")
        }
    }

    func setEnabled(_ enabled: Bool) {
        lastErrorMessage = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: Defaults.Key.launchAtLogin)
            Log.lifecycle.info("Login item \(enabled ? "registered" : "unregistered", privacy: .public)")
        } catch {
            // Do not flip `isEnabled` optimistically — `refresh()` below restores
            // the UI to whatever macOS actually thinks, which is the spec's
            // "revert the toggle to its true status and surface the error inline".
            lastErrorMessage = error.localizedDescription
            Log.lifecycle.error("Login item change failed: \(error.localizedDescription, privacy: .public)")
        }

        refresh()
    }

    /// Honors the spec's "ON by default" exactly once.
    ///
    /// Deliberately not a reconcile-toward-true on every launch: that would
    /// re-register the login item every time the user turned it off in System
    /// Settings, making their choice impossible to keep. After the first attempt
    /// the status is the only truth.
    private func registerOnFirstRunIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Defaults.Key.hasRequestedLoginItem) else { return }
        UserDefaults.standard.set(true, forKey: Defaults.Key.hasRequestedLoginItem)

        guard SMAppService.mainApp.status == .notRegistered else { return }
        Log.lifecycle.info("Requesting login item registration on first run")
        setEnabled(true)
    }
}
