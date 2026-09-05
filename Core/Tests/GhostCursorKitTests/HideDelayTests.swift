import Foundation
import Testing
@testable import GhostCursorKit

@Test func allowedValuesMatchSpecification() {
    #expect(HideDelay.allowedValues == [0.5, 1, 2, 3, 5, 10, 15, 30, 60])
}

@Test func defaultIsThreeSeconds() {
    #expect(HideDelay.defaultValue == 3)
}

@Test func clampedPassesThroughAllowedValues() {
    for value in HideDelay.allowedValues {
        #expect(HideDelay.clamped(value) == value)
    }
}

@Test func clampedSnapsToNearestBelow() {
    #expect(HideDelay.clamped(7) == 5)
}

@Test func clampedSnapsToNearestAbove() {
    #expect(HideDelay.clamped(12) == 10)
}

@Test func clampedResolvesTiesDownward() {
    #expect(HideDelay.clamped(4) == 3)
}

@Test func clampedHandlesBelowRange() {
    #expect(HideDelay.clamped(0) == 0.5)
    #expect(HideDelay.clamped(-5) == 0.5)
}

@Test func clampedHandlesAboveRange() {
    #expect(HideDelay.clamped(9999) == 60)
}

@Test func clampedRejectsNonFinite() {
    #expect(HideDelay.clamped(.nan) == 3)
    #expect(HideDelay.clamped(.infinity) == 3)
}

@Test func labelsReadNaturally() {
    #expect(HideDelay.label(for: 0.5) == "0.5 seconds")
    #expect(HideDelay.label(for: 1) == "1 second")
    #expect(HideDelay.label(for: 3) == "3 seconds")
    #expect(HideDelay.label(for: 60) == "1 minute")
    #expect(HideDelay.label(for: 120) == "2 minutes")
}

@Test func indexOfEachAllowedValueMatchesItsPosition() {
    for (position, value) in HideDelay.allowedValues.enumerated() {
        #expect(HideDelay.index(of: value) == position)
    }
}

@Test func indexSnapsUnalignedValues() {
    // 7 snaps to 5, which is at position 4.
    #expect(HideDelay.index(of: 7) == 4)
}

@Test func indexHandlesOffScaleValues() {
    #expect(HideDelay.index(of: -100) == 0)
    #expect(HideDelay.index(of: 9999) == HideDelay.allowedValues.count - 1)
    #expect(HideDelay.index(of: .nan) == HideDelay.allowedValues.firstIndex(of: HideDelay.defaultValue))
}

@Test func valueAtIndexReturnsTheAllowedValue() {
    for (position, value) in HideDelay.allowedValues.enumerated() {
        #expect(HideDelay.value(atIndex: position) == value)
    }
}

@Test func valueAtIndexClampsOutOfRange() {
    // The slider binding converts a Double to Int, so rounding at either end can
    // produce an out-of-range position. It must not trap.
    #expect(HideDelay.value(atIndex: -1) == HideDelay.allowedValues.first)
    #expect(HideDelay.value(atIndex: 999) == HideDelay.allowedValues.last)
}

@Test func indexAndValueRoundTrip() {
    for value in HideDelay.allowedValues {
        #expect(HideDelay.value(atIndex: HideDelay.index(of: value)) == value)
    }
}
