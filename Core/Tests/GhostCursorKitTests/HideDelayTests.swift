import Foundation
import Testing
@testable import GhostCursorKit

@Test func allowedValuesMatchSpecification() {
    #expect(HideDelay.allowedValues == [1, 2, 3, 5, 10, 15, 30, 60])
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
    #expect(HideDelay.clamped(0) == 1)
    #expect(HideDelay.clamped(-5) == 1)
}

@Test func clampedHandlesAboveRange() {
    #expect(HideDelay.clamped(9999) == 60)
}

@Test func clampedRejectsNonFinite() {
    #expect(HideDelay.clamped(.nan) == 3)
    #expect(HideDelay.clamped(.infinity) == 3)
}

@Test func labelsReadNaturally() {
    #expect(HideDelay.label(for: 1) == "1 second")
    #expect(HideDelay.label(for: 3) == "3 seconds")
    #expect(HideDelay.label(for: 60) == "1 minute")
    #expect(HideDelay.label(for: 120) == "2 minutes")
}
