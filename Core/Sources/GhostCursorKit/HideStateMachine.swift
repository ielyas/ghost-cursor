import Foundation

/// Decides when the cursor should be hidden. Pure: no timers, no AppKit, no
/// CoreGraphics. Every input arrives via `Input` and every output is a returned
/// `HideEffect`, which is what lets plan 004 test it with a fake clock.
public struct HideStateMachine: Sendable {
    public struct Input: Equatable, Sendable {
        /// Whether the user has auto-hide switched on.
        public var featureEnabled: Bool
        /// Seconds since the most recent watched mouse event.
        public var idleSeconds: TimeInterval
        /// Configured delay before hiding.
        public var hideDelay: TimeInterval
        /// Whether any mouse button is currently held down.
        public var mouseButtonsPressed: Bool
        /// Monotonic clock reading, used only for the watchdog.
        public var now: TimeInterval

        public init(
            featureEnabled: Bool,
            idleSeconds: TimeInterval,
            hideDelay: TimeInterval,
            mouseButtonsPressed: Bool,
            now: TimeInterval
        ) {
            self.featureEnabled = featureEnabled
            self.idleSeconds = idleSeconds
            self.hideDelay = hideDelay
            self.mouseButtonsPressed = mouseButtonsPressed
            self.now = now
        }
    }

    /// Upper bound on continuous hiding. Exceeding it implies a stuck timer or a
    /// missed input event rather than genuine idleness, so the cursor is
    /// force-revealed as a safety measure.
    public static let maxHiddenDuration: TimeInterval = 30 * 60

    public private(set) var state: HideState = .disabled

    /// Idle reading captured when the cursor was hidden. Absent input, idle time
    /// only ever grows, so any smaller reading proves new input arrived.
    private var idleSecondsAtHide: TimeInterval = 0
    private var hiddenSince: TimeInterval = 0
    /// Idle reading captured at the last force-reveal, used the same way.
    private var idleSecondsAtReveal: TimeInterval = 0

    public init() {}

    /// How often the caller should invoke `tick`. Fast only while hidden, where
    /// reveal latency is perceptible; slow otherwise to keep the CPU asleep.
    public var pollInterval: Duration {
        state == .hidden ? .milliseconds(16) : .milliseconds(250)
    }

    public mutating func tick(_ input: Input) -> HideEffect {
        // Disabling wins over every other transition, from any state.
        guard input.featureEnabled else {
            let needsReveal = state == .hidden
            state = .disabled
            return needsReveal ? .showCursor : .none
        }

        switch state {
        case .disabled:
            state = .watching
            return .none

        case .watching:
            if input.mouseButtonsPressed {
                state = .suspended
                return .none
            }
            if input.idleSeconds >= input.hideDelay {
                state = .hidden
                idleSecondsAtHide = input.idleSeconds
                hiddenSince = input.now
                return .hideCursor
            }
            return .none

        case .hidden:
            if input.mouseButtonsPressed || input.idleSeconds < idleSecondsAtHide {
                state = .watching
                return .showCursor
            }
            if input.now - hiddenSince >= Self.maxHiddenDuration {
                state = .revealHeld
                idleSecondsAtReveal = input.idleSeconds
                return .showCursor
            }
            return .none

        case .suspended:
            guard !input.mouseButtonsPressed else { return .none }
            state = .watching
            return .none

        case .revealHeld:
            if input.mouseButtonsPressed || input.idleSeconds < idleSecondsAtReveal {
                state = .watching
            }
            return .none
        }
    }
}
