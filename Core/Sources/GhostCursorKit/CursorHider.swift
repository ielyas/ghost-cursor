import CoreGraphics
import Foundation

/// The sole owner of cursor visibility for this process.
///
/// `CGDisplayHideCursor` and `CGDisplayShowCursor` are reference-counted per
/// process connection: two hides need two shows, and an imbalance leaves the
/// cursor permanently invisible. `wantsHidden` records intent only; together
/// with `reassert(trigger:)` it enforces a strict 0-or-1 count in practice. Nothing
/// outside this type may call those two functions.
@MainActor
public final class CursorHider {
    public enum Availability: Equatable, Sendable {
        /// Private symbols resolved and background cursor control was granted.
        case available
        /// A required private symbol is gone. Hiding cannot work at all.
        case privateAPIMissing
        /// Symbols resolved but the property call failed. Hiding may only work
        /// while GhostCursor is frontmost, which makes it near-useless — but it
        /// is not a reason to disable the feature outright.
        case backgroundControlFailed(CGError)
    }

    public private(set) var availability: Availability
    /// What the app wants, not what the system currently shows.
    ///
    /// macOS resets this process's hide reference count on space transitions
    /// without notifying anyone, so there is no way to know the live system state
    /// — cursor visibility is not readable on macOS 27. This flag is therefore
    /// intent only, and `reassert(trigger:)` is what reconciles intent with
    /// reality. Anything that needs to know "should the cursor be hidden right
    /// now" must read this; nothing may keep its own copy.
    public private(set) var wantsHidden = false

    /// False only when hiding is fundamentally impossible.
    public var canHide: Bool { availability != .privateAPIMissing }

    public init() {
        // Installed before anything can hide the cursor, so that even a crash
        // during this initialiser cannot leave the cursor hidden.
        EmergencyCursorRestore.install()

        guard CGSPrivate.isAvailable else {
            availability = .privateAPIMissing
            Log.cursor.error("Private CGS symbols unavailable; cursor hiding disabled")
            return
        }

        let result = CGSPrivate.enableBackgroundCursorControl()
        switch result {
        case .none:
            availability = .privateAPIMissing
            Log.cursor.error("Private CGS symbols vanished between checks")
        case .some(.success):
            availability = .available
            Log.cursor.info("Background cursor control enabled")
        case .some(let error):
            availability = .backgroundControlFailed(error)
            Log.cursor.error("SetsCursorInBackground failed: \(error.rawValue, privacy: .public)")
        }
    }

    public func hide() {
        guard canHide, !wantsHidden else { return }

        // The display argument is not meaningful for cursor visibility — the
        // cursor is a single global entity, so this hides it on every display,
        // which is the specified behavior.
        let result = CGDisplayHideCursor(CGMainDisplayID())
        guard result == .success else {
            Log.cursor.error("CGDisplayHideCursor failed: \(result.rawValue, privacy: .public)")
            return
        }

        wantsHidden = true
        EmergencyCursorRestore.setCursorHidden(true)
        Log.cursor.debug("Cursor hidden")
    }

    public func show() {
        guard wantsHidden else { return }

        let result = CGDisplayShowCursor(CGMainDisplayID())
        guard result == .success else {
            // `wantsHidden` stays true on purpose. The reference count was not
            // decremented, so the cursor really is still hidden, and the
            // termination and repair paths must keep trying.
            Log.cursor.error("CGDisplayShowCursor failed: \(result.rawValue, privacy: .public)")
            return
        }

        wantsHidden = false
        EmergencyCursorRestore.setCursorHidden(false)
        Log.cursor.debug("Cursor shown")
    }
}

#if DEBUG
/// Diagnostic hooks for plan 005's re-assertion experiment. These exist to
/// distinguish "the connection property was revoked" from "the hide reference
/// count was reset" — a question no API can answer by inspection. They are
/// `#if DEBUG` so they cannot ship, and plan 006 is expected to delete them.
///
/// Each hook fires after a five-second delay. That delay is the whole point:
/// these are triggered from the menu bar menu, and menu tracking itself reveals
/// the cursor, so a diagnostic that ran immediately would be measured while the
/// screen was still in the state the diagnostic is trying to change. Waiting
/// until the menu has closed and the app is back in the background makes the
/// observation unambiguous.
extension CursorHider {
    private static let debugDelay: Duration = .seconds(5)

    /// Re-applies `SetsCursorInBackground` after a delay, without touching the
    /// hide reference count. Safe: it cannot create an imbalance.
    public func debugReapplyBackgroundControlAfterDelay() {
        Log.cursor.info("debug: re-apply scheduled in 5s")
        Task { @MainActor in
            try? await Task.sleep(for: Self.debugDelay)
            let result = CGSPrivate.enableBackgroundCursorControl()
            switch result {
            case .none:
                Log.cursor.error("debug: FIRED re-apply — private symbols unavailable")
            case .some(.success):
                Log.cursor.info("debug: FIRED re-apply — SetsCursorInBackground returned success")
            case .some(let error):
                Log.cursor.error("debug: FIRED re-apply — failed: \(error.rawValue, privacy: .public)")
            }
        }
    }

    /// Calls `CGDisplayHideCursor` a second time after a delay, deliberately
    /// bypassing the `isHidden` guard.
    ///
    /// **This can leave the cursor permanently invisible.** If the reference
    /// count was *not* reset by the system, this raises it to 2, and the single
    /// `show()` on quit will not be enough to bring the cursor back. Recovery
    /// is `pkill -9 -x GhostCursor`, which relies on WindowServer releasing the
    /// count when the process connection is torn down. Only use this after that
    /// recovery path has been confirmed to work — see the plan's Owner QA
    /// ordering.
    public func debugForceHideAgainAfterDelay() {
        Log.cursor.info("debug: forced extra hide scheduled in 5s")
        Task { @MainActor in
            try? await Task.sleep(for: Self.debugDelay)
            let result = CGDisplayHideCursor(CGMainDisplayID())
            Log.cursor.info("debug: FIRED forced extra hide, result \(result.rawValue, privacy: .public)")
        }
    }
}
#endif
