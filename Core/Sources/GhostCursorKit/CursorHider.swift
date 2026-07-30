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

    /// Why a repair was requested. Carried only so the log can show which system
    /// event actually fired — coverage of Mission Control and App Exposé is not
    /// documented by Apple, so this is how gaps are detected.
    public enum ReassertTrigger: String, Sendable {
        case spaceChanged
        case appDeactivated
    }

    /// Delays, measured from the last triggering notification, at which repairs are
    /// attempted.
    ///
    /// A ladder rather than a single delay because the system finishes resetting
    /// cursor state at an unknown point after the notification, and success cannot
    /// be detected — cursor visibility is not readable, so a repair cannot report
    /// whether it actually took effect. The last rung is a delay already proven to
    /// work by manual QA, so the ladder cannot fail outright; the earlier rungs
    /// exist to make the repair feel immediate when the reset lands sooner.
    ///
    /// Every rung that runs while the hide is still intact costs a roughly
    /// one-frame flash, so rungs are not free and this list should not grow without
    /// evidence.
    public static let reassertLadder: [Duration] = [
        .milliseconds(150),
        .milliseconds(600),
        .milliseconds(1500),
        .milliseconds(3000),
        .milliseconds(5000),
    ]

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

    /// Hides the cursor, repairing first if the system reset our hide state.
    ///
    /// Normalises rather than incrementing: `CGDisplayShowCursor` drives the
    /// reference count to 0 (it clamps there rather than underflowing) and
    /// `CGDisplayHideCursor` then takes it to exactly 1. That makes this method
    /// idempotent and, crucially, effective even when a previous hide was silently
    /// discarded by a space transition — the state this method used to refuse to
    /// act on, because it returned early whenever `wantsHidden` was already true.
    ///
    /// No flash results in normal use: callers hide from a state where the cursor is
    /// already visible, so the leading show is a no-op the user cannot see.
    public func hide() {
        guard canHide else { return }

        // The display argument is not meaningful for cursor visibility — the cursor
        // is a single global entity, so this affects every display, which is the
        // specified behavior.
        let showResult = CGDisplayShowCursor(CGMainDisplayID())
        let hideResult = CGDisplayHideCursor(CGMainDisplayID())

        guard hideResult == .success else {
            // The count is 0 here, so the cursor is visible. Leaving `wantsHidden`
            // unchanged lets the next idle period try again.
            Log.cursor.error(
                "Hide failed: show \(showResult.rawValue, privacy: .public), hide \(hideResult.rawValue, privacy: .public)"
            )
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

    /// Re-establishes a hidden cursor after the system reset this process's hide
    /// reference count.
    ///
    /// The count cannot be read, so this normalises instead of incrementing:
    /// `CGDisplayShowCursor` drives the count to 0 (it clamps there rather than
    /// underflowing) and `CGDisplayHideCursor` then takes it to exactly 1. A bare
    /// extra hide would take an un-reset count to 2, and the single `show()` on
    /// quit would then leave the user with no cursor — which is why this must
    /// never be "optimised" into one call.
    ///
    /// If the hide was in fact still intact, the cursor flashes for roughly one
    /// frame. That is accepted: on the path this exists for, the cursor is already
    /// visible and nothing flashes.
    public func reassert(trigger: ReassertTrigger) {
        guard canHide, wantsHidden else { return }

        let showResult = CGDisplayShowCursor(CGMainDisplayID())
        let hideResult = CGDisplayHideCursor(CGMainDisplayID())

        guard hideResult == .success else {
            // Intent is unchanged, so the next event will try again. The count is
            // 0 here, meaning the cursor is visible while we intend it hidden —
            // the one state this method can leave behind, and it is self-healing.
            Log.cursor.error(
                "Reassert failed for \(trigger.rawValue, privacy: .public): show \(showResult.rawValue, privacy: .public), hide \(hideResult.rawValue, privacy: .public)"
            )
            return
        }

        EmergencyCursorRestore.setCursorHidden(true)
        Log.cursor.info("Reasserted hidden cursor after \(trigger.rawValue, privacy: .public)")
    }
}

#if DEBUG
/// Debug-only helper for manual QA. `#if DEBUG` so it cannot ship; plan 008
/// removes the debug menu entirely.
extension CursorHider {
    /// Hides the cursor five seconds after being called, so a tester can close
    /// the menu first. This matters: clicking a menu item makes GhostCursor
    /// frontmost, and a hide issued while frontmost is discarded the moment the
    /// app deactivates — so an immediate hide from the menu does not reproduce
    /// the state the product actually runs in.
    public func debugHideAfterDelay() {
        Log.cursor.info("debug: hide scheduled in 5s")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            hide()
        }
    }

    /// Repairs five seconds after being called, long after any space transition
    /// has settled.
    ///
    /// Owner QA showed `reassert` reporting success on `spaceChanged` while the
    /// cursor stayed visible, which has two possible causes: the repair races the
    /// system and loses, or the repair does not work at all. This separates them —
    /// if a repair this late succeeds, the cause is timing and only timing.
    public func debugReassertAfterDelay() {
        Log.cursor.info("debug: reassert scheduled in 5s")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            reassert(trigger: .spaceChanged)
        }
    }
}
#endif
