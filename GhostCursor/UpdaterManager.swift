import AppKit
import GhostCursorKit
import Observation
import Sparkle

/// Owns Sparkle's updater and exposes the one operation the UI needs.
///
/// Checks are **user-initiated only**: `SUEnableAutomaticChecks` is `false` in
/// `Info.plist`, so Sparkle never polls on a schedule and never asks the user
/// for permission to. This is the whole reason the app is allowed to make a
/// network request at all — do not add a background check without revisiting
/// the privacy wording in the About tab and the README.
///
/// Lives in the app target because Sparkle updates an enclosing `.app` bundle,
/// which does not exist in a `swift test` process.
@Observable
@MainActor
final class UpdaterManager {
    /// False while a check is already running, so the menu item can disable
    /// itself instead of queueing a second one.
    private(set) var canCheckForUpdates = true

    private let controller: SPUStandardUpdaterController
    private let activationDelegate = UpdaterActivationDelegate()
    private var canCheckObservation: NSKeyValueObservation?

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: activationDelegate
        )
        observeCanCheckForUpdates()
    }

    /// The menu item's action.
    ///
    /// `NSApp.activate()` first for the same reason `SettingsWindowOpener` does
    /// it: with `LSUIElement` the app is never frontmost, so Sparkle's alert —
    /// including the "you're up to date" one — would open behind whatever the
    /// user is looking at.
    func checkForUpdates() {
        NSApp.activate()
        Log.lifecycle.info("User initiated an update check")
        controller.checkForUpdates(nil)
    }

    private func observeCanCheckForUpdates() {
        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let value = change.newValue else { return }
            // KVO fires on whichever thread changed the property, which Sparkle
            // does not document, so hop explicitly rather than assume.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.canCheckForUpdates = value
                }
            }
        }
    }
}

/// Puts GhostCursor in the Dock for the duration of an update session.
///
/// `LSUIElement` apps have no Dock icon and cannot be reached with ⌘Tab, so
/// Sparkle's update window would be a stranded window the user cannot get back
/// to once it loses focus. Sparkle's own guidance for dockless apps is to switch
/// activation policy for the session and switch back afterwards.
private final class UpdaterActivationDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        }
    }

    func standardUserDriverWillFinishUpdateSession() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
