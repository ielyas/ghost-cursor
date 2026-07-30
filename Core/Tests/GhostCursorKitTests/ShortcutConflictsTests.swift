import Testing
@testable import GhostCursorKit

@Test func listIsFullyConstructible() {
    // The list is built with `compactMap`, so a row with a bad key code or no
    // required modifier would vanish silently instead of failing the build.
    #expect(ShortcutConflicts.known.count == 17)
}

@Test func findsAKnownSystemShortcut() {
    let spotlight = HotKeyCombination(keyCode: 49, modifiers: .command)!
    #expect(ShortcutConflicts.owner(of: spotlight) == "Spotlight")
}

@Test func returnsNilForAnUnclaimedCombination() {
    let free = HotKeyCombination(keyCode: 5, modifiers: [.command, .option, .control])!
    #expect(ShortcutConflicts.owner(of: free) == nil)
}

@Test func matchIsModifierExact() {
    // ⇧⌘Space is not Spotlight, and warning about it would train the user to
    // ignore the warning.
    let shifted = HotKeyCombination(keyCode: 49, modifiers: [.command, .shift])!
    #expect(ShortcutConflicts.owner(of: shifted) == nil)
}

@Test func everyEntryHasANonEmptyOwner() {
    #expect(ShortcutConflicts.known.allSatisfy { !$0.owner.isEmpty })
}

@Test func noDuplicateCombinations() {
    // A duplicate would make `owner(of:)` return whichever came first, silently.
    let combinations = ShortcutConflicts.known.map(\.combination)
    #expect(Set(combinations).count == combinations.count)
}
