/// Well-known macOS shortcuts, used to warn a user who is about to bind one of
/// them.
///
/// Static data rather than a runtime query because there is no API that answers
/// "who owns this combination". Carbon's `RegisterEventHotKey` reports success
/// even for shortcuts macOS itself owns — verified 2026-07-29 with ⌘Space, which
/// Spotlight holds — so the registration status cannot do this job.
///
/// This list is therefore **incomplete by construction** and always will be. It
/// is a warning, never a gate: the spec's rule is first-come-first-served and the
/// user decides.
public enum ShortcutConflicts {
    public struct Entry: Sendable, Hashable {
        public let combination: HotKeyCombination
        /// What macOS uses the combination for, phrased for a warning line.
        public let owner: String
    }

    /// Built through the failable initialiser, so a malformed row is dropped
    /// rather than crashing at launch. `listIsFullyConstructible` is the test that
    /// notices a dropped row.
    public static let known: [Entry] = rawEntries.compactMap { row in
        HotKeyCombination(keyCode: row.keyCode, modifiers: row.modifiers)
            .map { Entry(combination: $0, owner: row.owner) }
    }

    /// - Returns: what macOS uses this combination for, or `nil` if it is not in
    ///   the list. Matching is exact — ⇧⌘Space is not Spotlight.
    public static func owner(of combination: HotKeyCombination) -> String? {
        known.first { $0.combination == combination }?.owner
    }

    private static let rawEntries: [(keyCode: Int, modifiers: HotKeyModifiers, owner: String)] = [
        (49, [.command], "Spotlight"),
        (49, [.command, .option], "Finder search window"),
        (48, [.command], "the app switcher"),
        (126, [.control], "Mission Control"),
        (125, [.control], "App Exposé"),
        (123, [.control], "moving one Space left"),
        (124, [.control], "moving one Space right"),
        (20, [.command, .shift], "screenshot of the whole screen"),
        (21, [.command, .shift], "screenshot of a selection"),
        (23, [.command, .shift], "the screenshot options bar"),
        (12, [.command], "Quit in the active app"),
        (13, [.command], "Close Window in the active app"),
        (43, [.command], "Settings in the active app"),
        (4, [.command], "Hide in the active app"),
        (46, [.command], "Minimize in the active app"),
        (53, [.command, .option], "Force Quit"),
        (3, [.command, .control], "Full Screen in the active app")
    ]
}
