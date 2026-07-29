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

    #expect(hider.isHidden == false)
    hider.hide()
    #expect(hider.isHidden == true)
}

@Test @MainActor func repeatedHideDoesNotUnbalanceTheReferenceCount() {
    let hider = CursorHider()
    defer { hider.show() }

    hider.hide()
    hider.hide()
    hider.hide()
    #expect(hider.isHidden == true)

    // A single show must be enough. If hide() had incremented the WindowServer
    // count three times, the cursor would stay invisible after this line — the
    // exact bug this test exists to prevent.
    hider.show()
    #expect(hider.isHidden == false)
}

@Test @MainActor func showWhenAlreadyVisibleIsANoOp() {
    let hider = CursorHider()

    hider.show()
    hider.show()
    #expect(hider.isHidden == false)
}

@Test @MainActor func emergencyFlagTracksHiddenState() {
    let hider = CursorHider()
    defer { hider.show() }

    hider.hide()
    #expect(EmergencyCursorRestore.isCursorHiddenForTesting == true)
    hider.show()
    #expect(EmergencyCursorRestore.isCursorHiddenForTesting == false)
}
