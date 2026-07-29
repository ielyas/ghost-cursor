import AppKit
import GhostCursorKit

/// Watches the system events that reset this process's cursor hide state and asks
/// `CursorHider` to repair itself.
///
/// This lives in the app target rather than in `GhostCursorKit` because the `Core`
/// package is deliberately free of AppKit — keeping the testable logic independent
/// of the application lifecycle.
@MainActor
final class CursorReassertionCoordinator {
    private let cursorHider: CursorHider
    private var observers: [NSObjectProtocol] = []
    private var pendingRepair: Task<Void, Never>?

    init(cursorHider: CursorHider) {
        self.cursorHider = cursorHider
    }

    func start() {
        // Space transitions are the confirmed cause: Mission Control, App Exposé
        // and Spaces switching all reset the hide count. These notifications post
        // on NSWorkspace's OWN notification center, not the default one — using
        // NotificationCenter.default here silently never fires.
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        observe(workspaceCenter, NSWorkspace.activeSpaceDidChangeNotification, .spaceChanged)
        observe(workspaceCenter, NSWorkspace.didWakeNotification, .systemWoke)
        observe(workspaceCenter, NSWorkspace.sessionDidBecomeActiveNotification, .sessionBecameActive)

        // GhostCursor's own deactivation matters because a hide issued while it is
        // frontmost — which is what happens when the user picks a menu item — is
        // discarded when it stops being frontmost. This one posts on the default
        // center.
        observe(NotificationCenter.default, NSApplication.didResignActiveNotification, .appDeactivated)

        Log.cursor.info("Cursor reassertion coordinator started with \(self.observers.count, privacy: .public) observers")
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        _ trigger: CursorHider.ReassertTrigger
    ) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.scheduleRepair(trigger: trigger)
            }
        }
        observers.append(observer)
    }

    /// Schedules repairs at each rung of `CursorHider.reassertLadder`.
    ///
    /// Repairing inline on the notification does not work: macOS posts the
    /// notification when a space transition begins and finishes resetting cursor
    /// state afterwards, so an immediate repair reports success and is then thrown
    /// away. Verified by manual QA — the identical repair 5s later works.
    ///
    /// Debounced, because each gesture posts two notifications about 2s apart and
    /// overlapping ladders would multiply the redundant flashes.
    private func scheduleRepair(trigger: CursorHider.ReassertTrigger) {
        pendingRepair?.cancel()
        pendingRepair = Task { @MainActor [weak self] in
            var elapsed = Duration.zero
            for rung in CursorHider.reassertLadder {
                do {
                    try await Task.sleep(for: rung - elapsed)
                } catch {
                    // Cancelled by a newer notification, whose ladder supersedes
                    // this one.
                    return
                }
                elapsed = rung
                guard let self else { return }
                self.cursorHider.reassert(trigger: trigger)
            }
        }
    }
}
