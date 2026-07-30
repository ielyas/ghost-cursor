import Foundation
import Testing
@testable import GhostCursorKit

/// Builds an `Input` with sensible defaults so each test states only what it cares about.
private func input(
    enabled: Bool = true,
    idle: TimeInterval = 0,
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

/// Drives a machine to `.hidden` and returns it, so hidden-state tests start from
/// a known point without repeating the setup.
private func hiddenMachine(delay: TimeInterval = 3, hiddenAt: TimeInterval = 0) -> HideStateMachine {
    var machine = HideStateMachine()
    _ = machine.tick(input(idle: 0, delay: delay, now: hiddenAt))
    let effect = machine.tick(input(idle: delay, delay: delay, now: hiddenAt))
    precondition(effect == .hideCursor && machine.state == .hidden, "setup failed")
    return machine
}

@Suite("Transitions")
struct TransitionsTests {
    @Test func startsDisabled() {
        let machine = HideStateMachine()
        #expect(machine.state == .disabled)
    }

    @Test func enablingMovesToWatching() {
        var machine = HideStateMachine()
        let effect = machine.tick(input())
        #expect(effect == .none)
        #expect(machine.state == .watching)
    }

    @Test func staysWatchingBelowDelay() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        let effect = machine.tick(input(idle: 2.9, delay: 3))
        #expect(effect == .none)
        #expect(machine.state == .watching)
    }

    @Test func hidesExactlyAtDelayBoundary() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        let effect = machine.tick(input(idle: 3, delay: 3))
        #expect(effect == .hideCursor)
        #expect(machine.state == .hidden)
    }

    @Test func hidesAboveDelay() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        let effect = machine.tick(input(idle: 99, delay: 3))
        #expect(effect == .hideCursor)
        #expect(machine.state == .hidden)
    }

    @Test func buttonPressSuspends() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        let effect = machine.tick(input(buttons: true))
        #expect(effect == .none)
        #expect(machine.state == .suspended)
    }

    @Test func staysSuspendedWhileButtonHeld() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        _ = machine.tick(input(buttons: true))
        for _ in 0..<3 {
            let effect = machine.tick(input(buttons: true))
            #expect(effect == .none)
            #expect(machine.state == .suspended)
        }
    }

    @Test func releasingButtonReturnsToWatching() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        _ = machine.tick(input(buttons: true))
        let effect = machine.tick(input(buttons: false))
        #expect(effect == .none)
        #expect(machine.state == .watching)
    }

    @Test func neverHidesWhileSuspendedRegardlessOfIdle() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        _ = machine.tick(input(buttons: true))
        for _ in 0..<5 {
            let effect = machine.tick(input(idle: 999, buttons: true))
            #expect(effect == .none)
            #expect(machine.state == .suspended)
        }
    }

    @Test func staysHiddenWhileIdleGrows() {
        var machine = hiddenMachine()
        for idle in [3.1, 3.2, 3.3] {
            let effect = machine.tick(input(idle: idle, delay: 3))
            #expect(effect == .none)
            #expect(machine.state == .hidden)
        }
    }

    @Test func droppingIdleReveals() {
        var machine = hiddenMachine()
        let effect = machine.tick(input(idle: 0, delay: 3))
        #expect(effect == .showCursor)
        #expect(machine.state == .watching)
    }

    @Test func buttonPressWhileHiddenReveals() {
        var machine = hiddenMachine()
        let effect = machine.tick(input(buttons: true))
        #expect(effect == .showCursor)
        #expect(machine.state == .watching)
    }

    @Test func hideEffectIsEmittedOnlyOnce() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        var hideCount = 0
        for idle in [3.0, 3.1, 3.2, 3.3, 3.4] {
            if machine.tick(input(idle: idle, delay: 3)) == .hideCursor {
                hideCount += 1
            }
        }
        #expect(hideCount == 1)
    }

    @Test func fullHideRevealHideCycle() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        #expect(machine.tick(input(idle: 3)) == .hideCursor)
        #expect(machine.state == .hidden)
        #expect(machine.tick(input(idle: 0)) == .showCursor)
        #expect(machine.state == .watching)
        #expect(machine.tick(input(idle: 3)) == .hideCursor)
        #expect(machine.state == .hidden)
    }
}

@Suite("Disabling")
struct DisablingTests {
    @Test func disablingFromWatchingEmitsNothing() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        let effect = machine.tick(input(enabled: false))
        #expect(effect == .none)
        #expect(machine.state == .disabled)
    }

    @Test func disablingFromHiddenReveals() {
        var machine = hiddenMachine()
        let effect = machine.tick(input(enabled: false))
        #expect(effect == .showCursor)
        #expect(machine.state == .disabled)
    }

    @Test func disablingFromSuspendedEmitsNothing() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        _ = machine.tick(input(buttons: true))
        let effect = machine.tick(input(enabled: false))
        #expect(effect == .none)
        #expect(machine.state == .disabled)
    }

    @Test func disablingFromRevealHeldEmitsNothing() {
        var machine = hiddenMachine(hiddenAt: 0)
        _ = machine.tick(input(idle: 3, now: HideStateMachine.maxHiddenDuration))
        #expect(machine.state == .revealHeld)
        let effect = machine.tick(input(enabled: false))
        #expect(effect == .none)
        #expect(machine.state == .disabled)
    }

    @Test func reenablingReturnsToWatching() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        _ = machine.tick(input(enabled: false))
        let effect = machine.tick(input())
        #expect(effect == .none)
        #expect(machine.state == .watching)
    }
}

@Suite("Watchdog")
struct WatchdogTests {
    @Test func doesNotFireBeforeCeiling() {
        var machine = hiddenMachine(hiddenAt: 0)
        let effect = machine.tick(input(idle: 3, now: HideStateMachine.maxHiddenDuration - 1))
        #expect(effect == .none)
        #expect(machine.state == .hidden)
    }

    @Test func firesAtCeiling() {
        var machine = hiddenMachine(hiddenAt: 0)
        let effect = machine.tick(input(idle: 3, now: HideStateMachine.maxHiddenDuration))
        #expect(effect == .showCursor)
        #expect(machine.state == .revealHeld)
    }

    @Test func heldStateDoesNotImmediatelyRehide() {
        var machine = hiddenMachine(hiddenAt: 0)
        _ = machine.tick(input(idle: 3, now: HideStateMachine.maxHiddenDuration))
        #expect(machine.state == .revealHeld)
        for _ in 0..<10 {
            let effect = machine.tick(input(idle: 999, delay: 3))
            #expect(effect == .none)
            #expect(machine.state == .revealHeld)
        }
    }

    @Test func heldStateReleasesOnInput() {
        var machine = hiddenMachine(hiddenAt: 0)
        _ = machine.tick(input(idle: 3, now: HideStateMachine.maxHiddenDuration))
        let effect = machine.tick(input(idle: 0))
        #expect(effect == .none)
        #expect(machine.state == .watching)
    }

    @Test func hidesAgainAfterWatchdogRelease() {
        var machine = hiddenMachine(hiddenAt: 0)
        _ = machine.tick(input(idle: 3, now: HideStateMachine.maxHiddenDuration))
        _ = machine.tick(input(idle: 0))
        #expect(machine.state == .watching)
        let effect = machine.tick(input(idle: 3))
        #expect(effect == .hideCursor)
        #expect(machine.state == .hidden)
    }
}

@Suite("Delay changes")
struct DelayChangesTests {
    @Test func increasingDelayWhileHiddenDoesNotReveal() {
        var machine = hiddenMachine()
        let effect = machine.tick(input(idle: 3.1, delay: 30))
        #expect(effect == .none)
        #expect(machine.state == .hidden)
    }

    @Test func decreasingDelayHidesSooner() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        #expect(machine.tick(input(idle: 2, delay: 3)) == .none)
        #expect(machine.state == .watching)
        #expect(machine.tick(input(idle: 2, delay: 1)) == .hideCursor)
        #expect(machine.state == .hidden)
    }
}

@Suite("Poll interval")
struct PollIntervalTests {
    @Test func isSlowWhileWatching() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        #expect(machine.pollInterval == .milliseconds(250))
    }

    @Test func isFastWhileHidden() {
        let machine = hiddenMachine()
        #expect(machine.pollInterval == .milliseconds(16))
    }

    @Test func isSlowWhileSuspended() {
        var machine = HideStateMachine()
        _ = machine.tick(input())
        _ = machine.tick(input(buttons: true))
        #expect(machine.pollInterval == .milliseconds(250))
    }

    @Test func isSlowWhileRevealHeld() {
        var machine = hiddenMachine(hiddenAt: 0)
        _ = machine.tick(input(idle: 3, now: HideStateMachine.maxHiddenDuration))
        #expect(machine.pollInterval == .milliseconds(250))
    }
}
