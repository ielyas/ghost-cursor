import Foundation

/// The delay values the UI offers, and clamping for persisted values.
public enum HideDelay {
    public static let allowedValues: [TimeInterval] = [1, 2, 3, 5, 10, 15, 30, 60]
    public static let defaultValue: TimeInterval = 3

    /// Snaps an arbitrary value to the nearest allowed one. Used when reading
    /// `UserDefaults`, which may hold a stale or hand-edited value.
    public static func clamped(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return defaultValue }
        return allowedValues.min { abs($0 - value) < abs($1 - value) } ?? defaultValue
    }

    /// Short label for menus, e.g. "3 seconds", "1 minute".
    public static func label(for value: TimeInterval) -> String {
        if value >= 60 {
            let minutes = Int(value / 60)
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }
        let seconds = Int(value)
        return seconds == 1 ? "1 second" : "\(seconds) seconds"
    }
}
