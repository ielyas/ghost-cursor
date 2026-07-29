/// States of the cursor auto-hide lifecycle.
///
/// Every `switch` over this type in the codebase omits `default`, so adding a
/// case here deliberately breaks the build until each site handles it.
public enum HideState: Equatable, Sendable {
    /// Feature is off. The cursor must be visible.
    case disabled
    /// Feature is on, cursor visible, idle time accumulating.
    case watching
    /// Cursor is currently hidden by this process.
    case hidden
    /// Temporarily inhibited because a mouse button is held or a drag is active.
    case suspended
    /// The watchdog force-revealed the cursor. Hiding stays inhibited until real
    /// input arrives, which prevents an immediate re-hide: after a watchdog
    /// reveal the idle counter is still far above the delay, so returning
    /// straight to `watching` would flicker the cursor on every poll.
    case watchdogHeld
}

/// The side effect a `tick` requires of the caller. Keeping effects as returned
/// values rather than direct calls is what makes the state machine pure and
/// exhaustively testable without a real cursor.
public enum HideEffect: Equatable, Sendable {
    case none
    case hideCursor
    case showCursor
}
