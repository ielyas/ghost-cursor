import Foundation
import Testing
@testable import GhostCursorKit

private func input(
    enabled: Bool = true,
    idle: TimeInterval,
    delay: TimeInterval = 3,
    buttons: Bool = false,
    now: TimeInterval = 0
) -> HideStateMachine.Input {
    HideStateMachine.Input(
        featureEnabled: enabled,
        idleSeconds: idle,
        hideDelay: delay,
        mouseButtonsPressed: buttons,
        now: now
    )
}

@Test func hidesOnceIdleReachesTheDelay() {
    var machine = HideStateMachine()
    #expect(machine.tick(input(idle: 0)) == .none)
    #expect(machine.state == .watching)
    #expect(machine.tick(input(idle: 3)) == .hideCursor)
    #expect(machine.state == .hidden)
}

@Test func revealsWhenIdleTimeDrops() {
    var machine = HideStateMachine()
    _ = machine.tick(input(idle: 0))
    _ = machine.tick(input(idle: 3))
    #expect(machine.tick(input(idle: 0)) == .showCursor)
    #expect(machine.state == .watching)
}

@Test func pollsFasterWhileHidden() {
    var machine = HideStateMachine()
    _ = machine.tick(input(idle: 0))
    #expect(machine.pollInterval == .milliseconds(250))
    _ = machine.tick(input(idle: 3))
    #expect(machine.pollInterval == .milliseconds(16))
}
