/// A validated global shortcut: a virtual key code plus its modifiers.
///
/// Failable on purpose — an unmodified global hotkey is a trap the user cannot
/// escape from inside the app, so an invalid combination must be impossible to
/// construct rather than merely discouraged.
public struct HotKeyCombination: Equatable, Sendable, Hashable {
    /// Carbon virtual key code. Note that `0` is a real key (`A`), which is why
    /// callers reading this out of `UserDefaults` must use `object(forKey:)` and
    /// not `integer(forKey:)`.
    public let keyCode: Int
    public let modifiers: HotKeyModifiers

    /// - Returns: `nil` when the combination carries no Command, Option or
    ///   Control, or when the key code is outside the range Carbon uses.
    public init?(keyCode: Int, modifiers: HotKeyModifiers) {
        guard (0...127).contains(keyCode) else { return nil }
        guard !modifiers.intersection(.required).isEmpty else { return nil }
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Menu-style rendering, e.g. "⌃⌥⌘G".
    public var displayString: String {
        modifiers.displayString + Self.keyName(for: keyCode)
    }

    /// Human label for a virtual key code.
    ///
    /// A literal table rather than `UCKeyTranslate`, which would respect
    /// non-QWERTY layouts but costs ~40 lines of `UnsafePointer` work against
    /// Text Input Services. Deferred deliberately; the fallback below keeps an
    /// unmapped key usable rather than blank.
    ///
    /// Codes are the stable ANSI virtual key codes from `Carbon/HIToolbox/Events.h`.
    public static func keyName(for keyCode: Int) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }

    static let keyNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
        50: "`", 51: "Delete", 53: "Escape",
        64: "F17", 65: "Keypad .", 67: "Keypad *", 69: "Keypad +",
        71: "Clear", 75: "Keypad /", 76: "Enter", 78: "Keypad -",
        79: "F18", 80: "F19", 81: "Keypad =", 82: "Keypad 0",
        83: "Keypad 1", 84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4",
        87: "Keypad 5", 88: "Keypad 6", 89: "Keypad 7", 90: "F20",
        91: "Keypad 8", 92: "Keypad 9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10",
        111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
        117: "Forward Delete", 118: "F4", 119: "End", 120: "F2",
        121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}
