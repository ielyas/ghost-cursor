import CoreGraphics
import Foundation

/// The sole owner of cursor visibility for this process.
///
/// `CGDisplayHideCursor` and `CGDisplayShowCursor` are reference-counted per
/// process connection: two hides need two shows, and an imbalance leaves the
/// cursor permanently invisible. `isHidden` enforces a strict 0-or-1 count, so
/// a double hide is impossible by construction. Nothing outside this type may
/// call those two functions.
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
    public private(set) var isHidden = false

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
        guard canHide, !isHidden else { return }

        // The display argument is not meaningful for cursor visibility — the
        // cursor is a single global entity, so this hides it on every display,
        // which is the specified behavior.
        let result = CGDisplayHideCursor(CGMainDisplayID())
        guard result == .success else {
            Log.cursor.error("CGDisplayHideCursor failed: \(result.rawValue, privacy: .public)")
            return
        }

        isHidden = true
        EmergencyCursorRestore.setCursorHidden(true)
        Log.cursor.debug("Cursor hidden")
    }

    public func show() {
        guard isHidden else { return }

        let result = CGDisplayShowCursor(CGMainDisplayID())
        guard result == .success else {
            // `isHidden` stays true on purpose. The reference count was not
            // decremented, so the cursor really is still hidden, and the
            // termination and watchdog paths must keep trying.
            Log.cursor.error("CGDisplayShowCursor failed: \(result.rawValue, privacy: .public)")
            return
        }

        isHidden = false
        EmergencyCursorRestore.setCursorHidden(false)
        Log.cursor.debug("Cursor shown")
    }
}
