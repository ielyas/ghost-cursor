import Testing
@testable import GhostCursorKit

@Test func rejectsCombinationsWithoutARequiredModifier() {
    // A global hotkey with no ⌘/⌥/⌃ fires while the user types, everywhere, with
    // no way out from inside the app.
    #expect(HotKeyCombination(keyCode: 5, modifiers: []) == nil)
    #expect(HotKeyCombination(keyCode: 5, modifiers: .shift) == nil)
}

@Test func acceptsAnySingleRequiredModifier() {
    #expect(HotKeyCombination(keyCode: 5, modifiers: .command) != nil)
    #expect(HotKeyCombination(keyCode: 5, modifiers: .option) != nil)
    #expect(HotKeyCombination(keyCode: 5, modifiers: .control) != nil)
}

@Test func acceptsShiftAlongsideARequiredModifier() {
    #expect(HotKeyCombination(keyCode: 5, modifiers: [.command, .shift]) != nil)
}

@Test func rejectsOutOfRangeKeyCodes() {
    #expect(HotKeyCombination(keyCode: -1, modifiers: .command) == nil)
    #expect(HotKeyCombination(keyCode: 128, modifiers: .command) == nil)
}

@Test func displayStringOrdersModifiersLikeMacOS() {
    let combination = HotKeyCombination(
        keyCode: 5,
        modifiers: [.command, .shift, .option, .control]
    )
    #expect(combination?.displayString == "⌃⌥⇧⌘G")
}

@Test func displayStringNamesLetterKeys() {
    #expect(HotKeyCombination(keyCode: 5, modifiers: .command)?.displayString == "⌘G")
    #expect(HotKeyCombination(keyCode: 0, modifiers: .command)?.displayString == "⌘A")
}

@Test func displayStringNamesSpecialKeys() {
    #expect(HotKeyCombination.keyName(for: 49) == "Space")
    #expect(HotKeyCombination.keyName(for: 53) == "Escape")
    #expect(HotKeyCombination.keyName(for: 36) == "Return")
    #expect(HotKeyCombination.keyName(for: 51) == "Delete")
    #expect(HotKeyCombination.keyName(for: 122) == "F1")
    #expect(HotKeyCombination.keyName(for: 80) == "F19")
}

@Test func unknownKeyCodeStillProducesALabel() {
    // Better a useless-but-present label than a shortcut that renders as just its
    // modifiers, which reads as a broken UI.
    #expect(HotKeyCombination.keyName(for: 127) == "Key 127")
    #expect(!HotKeyCombination.keyName(for: 127).isEmpty)
}

@Test func keyNamesAreUnique() {
    // Two codes sharing a label would make two different shortcuts render
    // identically in the recorder.
    let names = HotKeyCombination.keyNames.values
    #expect(Set(names).count == names.count)
}

@Test func modifiersRoundTripThroughRawValue() {
    // The raw value is the persisted format, so this is the storage contract.
    let original: HotKeyModifiers = [.command, .control]
    #expect(HotKeyModifiers(rawValue: original.rawValue) == original)
    #expect(original.rawValue == 5)
}
