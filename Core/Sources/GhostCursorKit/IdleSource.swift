import Foundation

/// Supplies the input the state machine needs about mouse activity.
/// Abstracted so tests can drive the machine from a fake.
public protocol IdleSource: Sendable {
    /// Seconds since the most recent watched mouse event.
    func secondsSinceLastMouseEvent() -> TimeInterval
    /// Whether any mouse button is currently held down.
    var mouseButtonsPressed: Bool { get }
}
