import AppKit
import GhostCursorKit
import Observation
import Sparkle

/// Owns Sparkle's updater and exposes the settings and operation the UI needs.
///
/// Checks are **automatic and daily by default**: `SUEnableAutomaticChecks` is
/// `true` and `SUScheduledCheckInterval` is `86400` in `Info.plist`, so Sparkle
/// polls the appcast once a day without asking. Silent install is **opt-in and
/// off by default** — `SUAllowsAutomaticUpdates` permits the user to turn it
/// on, but `SUAutomaticallyUpdate` is absent, so a fresh install always asks
/// before installing. The user-facing privacy wording in `README.md` states
/// this cadence and these defaults; keep the two in sync if either changes.
///
/// Lives in the app target because Sparkle updates an enclosing `.app` bundle,
/// which does not exist in a `swift test` process.
@Observable
@MainActor
final class UpdaterManager {
    /// False while a check is already running, so the menu item can disable
    /// itself instead of queueing a second one.
    private(set) var canCheckForUpdates = true

    /// Whether Sparkle checks the appcast on a schedule. The getter mirrors
    /// Sparkle's own `automaticallyChecksForUpdates`, kept in sync via KVO
    /// below; the setter writes straight through to Sparkle so Sparkle stays
    /// the single source of truth. Never mirrored into `UserDefaults` directly.
    var automaticallyChecksForUpdates: Bool {
        get { automaticallyChecksForUpdatesStorage }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Whether Sparkle installs updates without asking. Same mirror-and-write-
    /// through pattern as `automaticallyChecksForUpdates` — Sparkle's own
    /// update dialog can also flip this checkbox, and the Settings toggle must
    /// follow it rather than disagree.
    var automaticallyDownloadsUpdates: Bool {
        get { automaticallyDownloadsUpdatesStorage }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    private let controller: SPUStandardUpdaterController
    private let activationDelegate = UpdaterActivationDelegate()
    private var automaticallyChecksForUpdatesStorage = true
    private var automaticallyDownloadsUpdatesStorage = false
    private var canCheckObservation: NSKeyValueObservation?
    private var automaticallyChecksObservation: NSKeyValueObservation?
    private var automaticallyDownloadsObservation: NSKeyValueObservation?

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: activationDelegate
        )
        observeCanCheckForUpdates()
        observeAutomaticSettings()
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

    /// Same KVO-and-hop pattern as `observeCanCheckForUpdates`, for the two
    /// settings toggles. Sparkle's own update dialog can change
    /// `automaticallyDownloadsUpdates` out from under the Settings window, so
    /// this observation is what makes the toggle follow it.
    private func observeAutomaticSettings() {
        automaticallyChecksObservation = controller.updater.observe(
            \.automaticallyChecksForUpdates,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let value = change.newValue else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.automaticallyChecksForUpdatesStorage = value
                }
            }
        }

        automaticallyDownloadsObservation = controller.updater.observe(
            \.automaticallyDownloadsUpdates,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let value = change.newValue else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.automaticallyDownloadsUpdatesStorage = value
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
        let userInitiated = state.userInitiated
        DispatchQueue.main.async {
            // Always .regular: an LSUIElement app's update window has no Dock
            // icon and no ⌘Tab entry, so without this it is a window the user
            // cannot get back to once it loses focus.
            NSApp.setActivationPolicy(.regular)

            // Only steal focus when the user asked. For a scheduled check
            // Sparkle deliberately shows the alert behind the frontmost app —
            // activating here would undo that and interrupt them once a day.
            if userInitiated {
                NSApp.activate()
            }
        }
    }

    func standardUserDriverWillFinishUpdateSession() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
