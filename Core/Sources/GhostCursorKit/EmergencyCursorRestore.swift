import CoreGraphics
import Foundation

/// Last-resort cursor restoration for paths that bypass normal cleanup.
///
/// Correctness note: `CGDisplayShowCursor` is **not** async-signal-safe, so
/// calling it from a signal handler is technically undefined. It is accepted
/// here because the alternative — a user left with no visible cursor — is worse
/// than a small risk of a hang while the process is already terminating. Only
/// signals that arrive while the process is in a sane state are handled;
/// crash signals are deliberately not (see the plan's Maintenance notes).
public enum EmergencyCursorRestore {
    /// Mirrors `CursorHider.isHidden` in a form a signal handler may legally
    /// read. `sig_atomic_t` is the only integer type guaranteed safe here.
    private nonisolated(unsafe) static var cursorIsHidden: sig_atomic_t = 0

    private nonisolated(unsafe) static var isInstalled = false

    /// Installs the `atexit` hook and termination signal handlers. Idempotent.
    public static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        atexit {
            EmergencyCursorRestore.restoreIfNeeded()
        }

        for signalNumber in [SIGTERM, SIGINT, SIGHUP] {
            signal(signalNumber) { received in
                EmergencyCursorRestore.restoreIfNeeded()
                // Restore the default disposition and re-raise, so the process
                // still dies the way the sender intended. Without this the app
                // would silently ignore SIGTERM and refuse to quit.
                signal(received, SIG_DFL)
                raise(received)
            }
        }
    }

    /// Records whether the cursor is currently hidden by this process.
    public static func setCursorHidden(_ hidden: Bool) {
        cursorIsHidden = hidden ? 1 : 0
    }

    private static func restoreIfNeeded() {
        guard cursorIsHidden != 0 else { return }
        CGDisplayShowCursor(CGMainDisplayID())
        cursorIsHidden = 0
    }
}
