import CoreGraphics
import Testing
@testable import GhostCursorKit

/// These tests hide the real cursor for a few microseconds. Every test restores
/// it with `defer`, and `EmergencyCursorRestore` — installed by `CursorHider.init`
/// — covers the case where the test process dies mid-test.
@Test @MainActor func privateAPIIsAvailableOnThisSystem() {
    #expect(CGSPrivate.isAvailable, "Private CGS symbols missing — see STOP conditions in plan 002")
}

@Test @MainActor func startsVisibleAndHidesOnce() {
    let hider = CursorHider()
    defer { hider.show() }

    #expect(hider.wantsHidden == false)
    hider.hide()
    #expect(hider.wantsHidden == true)
}

@Test @MainActor func repeatedHideDoesNotUnbalanceTheReferenceCount() {
    let hider = CursorHider()
    defer { hider.show() }

    hider.hide()
    hider.hide()
    hider.hide()
    #expect(hider.wantsHidden == true)

    hider.show()
    #expect(hider.wantsHidden == false)
}

@Test @MainActor func showWhenAlreadyVisibleIsANoOp() {
    let hider = CursorHider()

    hider.show()
    hider.show()
    #expect(hider.wantsHidden == false)
}

@Test @MainActor func emergencyFlagTracksHiddenState() {
    let hider = CursorHider()
    defer { hider.show() }

    hider.hide()
    #expect(EmergencyCursorRestore.isCursorHiddenForTesting == true)
    hider.show()
    #expect(EmergencyCursorRestore.isCursorHiddenForTesting == false)
}

@Test @MainActor func reassertDoesNothingWhenCursorIsNotWanted() {
    let hider = CursorHider()

    hider.reassert(trigger: .spaceChanged)
    #expect(hider.wantsHidden == false)
    #expect(EmergencyCursorRestore.isCursorHiddenForTesting == false)
}

@Test @MainActor func reassertPreservesIntent() {
    let hider = CursorHider()
    defer { hider.show() }

    hider.hide()
    hider.reassert(trigger: .spaceChanged)
    #expect(hider.wantsHidden == true)
    #expect(EmergencyCursorRestore.isCursorHiddenForTesting == true)
}

/// The invariant that protects the user: however many repairs happened, exactly
/// one `show()` must return to the visible state. If `reassert` ever incremented
/// the reference count instead of normalising it, real usage would strand the
/// cursor. A unit test cannot read the count, so this asserts the state-machine
/// half; Owner QA item 6 checks the visible half.
@Test @MainActor func manyReassertsStillNeedOnlyOneShow() {
    let hider = CursorHider()
    defer { hider.show() }

    hider.hide()
    for _ in 0..<5 {
        hider.reassert(trigger: .spaceChanged)
    }

    hider.show()
    #expect(hider.wantsHidden == false)
    #expect(EmergencyCursorRestore.isCursorHiddenForTesting == false)
}

@Test @MainActor func everyTriggerIsLoggable() {
    // Guards against a case being added with an empty or duplicated rawValue,
    // which would make the log evidence in Owner QA unreadable.
    let triggers: [CursorHider.ReassertTrigger] = [
        .spaceChanged, .appDeactivated, .systemWoke, .sessionBecameActive
    ]
    #expect(Set(triggers.map(\.rawValue)).count == triggers.count)
    #expect(triggers.allSatisfy { !$0.rawValue.isEmpty })
}

/// The ladder's contract: strictly increasing, so the coordinator's
/// `rung - elapsed` arithmetic never produces a negative sleep, and ending at a
/// delay manual QA proved works.
@Test @MainActor func reassertLadderIsIncreasingAndEndsAtAProvenDelay() {
    let ladder = CursorHider.reassertLadder

    #expect(ladder.count >= 2)
    #expect(zip(ladder, ladder.dropFirst()).allSatisfy { $0 < $1 })
    #expect(ladder.first! > .zero)
    #expect(ladder.last! >= .milliseconds(5000))
}
