import AppKit
import GhostCursorKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.lifecycle.info("GhostCursor launched")
        presentDegradationAlertIfNeeded()
        AppState.shared.start()
        openSettingsOnFirstRunIfNeeded()
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        // First line of the three-layer safety net. `EmergencyCursorRestore`
        // covers signals and abnormal exits; this covers an ordinary quit.
        AppState.shared.cursorHider.show()
        Log.lifecycle.info("GhostCursor terminating")
    }

    @MainActor
    private func presentDegradationAlertIfNeeded() {
        switch AppState.shared.cursorHider.availability {
        case .available:
            return

        case .backgroundControlFailed(let error):
            // Not fatal: hiding may still work while frontmost. Log and carry
            // on rather than interrupting the user on every launch.
            Log.cursor.error("Degraded: background cursor control unavailable (\(error.rawValue, privacy: .public))")

        case .privateAPIMissing:
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "GhostCursor can't hide the cursor on this version of macOS"
            alert.informativeText = """
                GhostCursor relies on a system interface that is no longer \
                available. Cursor hiding has been disabled. Everything else \
                still works, but the app can't do its main job until it is \
                updated.
                """
            alert.addButton(withTitle: "Continue Disabled")
            alert.addButton(withTitle: "Quit")

            if alert.runModal() == .alertSecondButtonReturn {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    /// The spec's first-run flow: no shortcut exists by default, so the app asks
    /// for one once. Gated by a flag rather than by "no shortcut assigned",
    /// because leaving the shortcut unassigned is a supported choice and must not
    /// reopen this window on every launch.
    @MainActor
    private func openSettingsOnFirstRunIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Defaults.Key.hasCompletedFirstRun) else { return }
        UserDefaults.standard.set(true, forKey: Defaults.Key.hasCompletedFirstRun)

        Log.lifecycle.info("First run: opening Settings for shortcut assignment")
        AppState.shared.pendingSettingsTab = .shortcut
        SettingsWindowOpener.open()
    }
}
