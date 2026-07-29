import Foundation

/// Polls the idle source, feeds the state machine, and applies its effects.
///
/// Deliberately contains no decision logic — every branch lives in
/// `HideStateMachine`, which is unit-tested. Keep it that way: logic added here
/// is logic that cannot be tested without a real cursor and a real clock.
@MainActor
public final class IdleMonitor {
    public var featureEnabled = false
    public var hideDelay: TimeInterval = HideDelay.defaultValue

    public var state: HideState { machine.state }

    private let idleSource: IdleSource
    private let cursorHider: CursorHider
    private let clock: @Sendable () -> TimeInterval
    private var machine = HideStateMachine()
    private var pollTask: Task<Void, Never>?

    /// - Parameter clock: monotonic seconds. `systemUptime` is used by default
    ///   because it does not advance while the machine is asleep, which is the
    ///   behavior the watchdog wants — a laptop closed for two hours should not
    ///   trip a 30-minute ceiling.
    public init(
        idleSource: IdleSource = SystemIdleSource(),
        cursorHider: CursorHider,
        clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.idleSource = idleSource
        self.cursorHider = cursorHider
        self.clock = clock
    }

    public func start() {
        guard pollTask == nil else { return }
        Log.idle.info("Idle monitor started")
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tickOnce()
                try? await Task.sleep(for: self.machine.pollInterval)
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
        cursorHider.show()
        Log.idle.info("Idle monitor stopped")
    }

    /// Internal rather than private so tests can step the monitor without a timer.
    func tickOnce() {
        let input = HideStateMachine.Input(
            featureEnabled: featureEnabled,
            idleSeconds: idleSource.secondsSinceLastMouseEvent(),
            hideDelay: hideDelay,
            mouseButtonsPressed: idleSource.mouseButtonsPressed,
            now: clock()
        )

        switch machine.tick(input) {
        case .none:
            break
        case .hideCursor:
            cursorHider.hide()
        case .showCursor:
            cursorHider.show()
        }
    }
}
