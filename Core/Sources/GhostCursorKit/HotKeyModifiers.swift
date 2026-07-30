/// The modifier keys a shortcut can carry.
///
/// Defined with our own bit values rather than Carbon's because this is the
/// **persisted** format — a number written into `UserDefaults` and read back on
/// every launch. Tying it to `cmdKey` and friends would mean a Carbon header
/// change silently reinterpreted every user's saved shortcut.
/// `HotKeyManager` translates these to Carbon masks explicitly at the boundary.
public struct HotKeyModifiers: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = HotKeyModifiers(rawValue: 1 << 0)
    public static let option = HotKeyModifiers(rawValue: 1 << 1)
    public static let control = HotKeyModifiers(rawValue: 1 << 2)
    public static let shift = HotKeyModifiers(rawValue: 1 << 3)

    /// A shortcut needs at least one of these to be safe as a *global* binding.
    ///
    /// Shift is excluded on purpose: ⇧A is just a capital A, so a shift-only
    /// global shortcut would fire while the user typed, system-wide, with no way
    /// to escape it except quitting the app.
    public static let required: HotKeyModifiers = [.command, .option, .control]

    /// Glyphs in the order macOS renders them in menus: ⌃⌥⇧⌘.
    public var displayString: String {
        var glyphs = ""
        if contains(.control) { glyphs += "⌃" }
        if contains(.option) { glyphs += "⌥" }
        if contains(.shift) { glyphs += "⇧" }
        if contains(.command) { glyphs += "⌘" }
        return glyphs
    }
}
