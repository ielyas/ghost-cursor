import AppKit
import CoreGraphics
import GhostCursorKit

/// Watches the system events that mean the user is leaving or returning, and
/// force-reveals the cursor so it is never stranded hidden across a sleep, a
/// lock, a user switch, or a display change.
///
/// Deliberately separate from `CursorReassertionCoordinator`, which handles the
/// opposite class of event: a space transition silently drops our hide and we
/// want it back. One coordinator doing both would have to decide, per
/// notification, whether to hide or reveal — and getting that wrong strands the
/// user's cursor. Two objects, one rule each.
///
/// Lives in the app target because `Core` stays free of app-lifecycle APIs.
@MainActor
final class SystemEventMonitor {
    private let idleMonitor: IdleMonitor
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var displayCallbackInstalled = false

    init(idleMonitor: IdleMonitor) {
        self.idleMonitor = idleMonitor
    }

    func start() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        observe(workspaceCenter, NSWorkspace.screensDidSleepNotification, .screensSlept)
        observe(workspaceCenter, NSWorkspace.screensDidWakeNotification, .screensWoke)
        observe(workspaceCenter, NSWorkspace.didWakeNotification, .systemWoke)
        observe(workspaceCenter, NSWorkspace.sessionDidResignActiveNotification, .sessionResigned)
        observe(workspaceCenter, NSWorkspace.sessionDidBecomeActiveNotification, .sessionBecameActive)

        // Screen lock has no public notification. These two names are
        // long-standing but undocumented, so treat a silent failure here as
        // expected rather than as a bug — `sessionDidResignActive` and the idle
        // loop both still cover the user walking away.
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), .screenLocked)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), .screenUnlocked)

        displayReconfigurationHandler = { [weak self] in
            MainActor.assumeIsolated {
                self?.idleMonitor.forceReveal(reason: .displayReconfigured)
            }
        }

        let status = CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, nil)
        displayCallbackInstalled = status == .success
        if !displayCallbackInstalled {
            Log.lifecycle.error(
                "CGDisplayRegisterReconfigurationCallback failed: \(status.rawValue, privacy: .public)"
            )
        }

        Log.lifecycle.info(
            "System event monitor started with \(self.observers.count, privacy: .public) observers, display callback \(self.displayCallbackInstalled, privacy: .public)"
        )
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        _ reason: RevealReason
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.idleMonitor.forceReveal(reason: reason)
            }
        }
        observers.append((center, token))
    }
}

/// The display reconfiguration callback is a bare C function pointer and cannot
/// capture context, so it reaches the instance through a fileprivate hook. There
/// is exactly one `SystemEventMonitor` — `AppState` owns it for the process
/// lifetime — so a single static hook is sufficient and avoids an `Unmanaged`
/// pointer round trip. Lives at file scope because a stored static property on
/// the `@MainActor` class cannot reference `Self` in its initializer.
private nonisolated(unsafe) var displayReconfigurationHandler: (@Sendable () -> Void)?

private let displayReconfigurationCallback: CGDisplayReconfigurationCallBack = { _, flags, _ in
    // `beginConfigurationFlag` is the pre-change warning; the display state has
    // not moved yet, so reacting to it just doubles the work.
    guard !flags.contains(.beginConfigurationFlag) else { return }

    let meaningful: CGDisplayChangeSummaryFlags = [
        .setModeFlag, .addFlag, .removeFlag, .desktopShapeChangedFlag
    ]
    guard !flags.intersection(meaningful).isEmpty else { return }

    // The delivery thread for this callback is not documented, so hop to the
    // main queue explicitly rather than assuming isolation the way the
    // notification observers legitimately can (they specify `queue: .main`).
    DispatchQueue.main.async {
        displayReconfigurationHandler?()
    }
}
