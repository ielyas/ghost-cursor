import AppKit
import CoreGraphics
import Foundation

/// Reads real mouse activity from the system.
///
/// Uses `CGEventSource.secondsSinceLastEventType`, a public API that needs no
/// Accessibility or Input Monitoring permission — unlike `CGEventTap`, which is
/// the conventional approach and would force a permission prompt on first run.
/// This is the reason GhostCursor installs with zero prompts, so do not replace
/// this with an event tap or a global `NSEvent` monitor.
public struct SystemIdleSource: IdleSource {
    /// Every event type that counts as mouse activity. Mouse-up types are
    /// included so that releasing a button resets the idle counter, which is
    /// what makes the `suspended` state exit cleanly without extra bookkeeping.
    static let watchedEventTypes: [CGEventType] = [
        .mouseMoved,
        .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseUp, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        .scrollWheel
    ]

    public init() {}

    public func secondsSinceLastMouseEvent() -> TimeInterval {
        // The most recent event across all watched types is the minimum of their
        // individual idle times.
        Self.watchedEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .min() ?? .greatestFiniteMagnitude
    }

    public var mouseButtonsPressed: Bool {
        NSEvent.pressedMouseButtons != 0
    }
}
