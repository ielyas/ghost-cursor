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

    /// Position of a value in `allowedValues`, for binding a `Slider` whose travel
    /// must be evenly divided between snap points.
    ///
    /// The snap points are not evenly spaced — 30→60 is half the numeric range —
    /// so a slider bound to seconds would give that one gap most of its travel and
    /// land on values like 7.4 in between. Sliding over the index instead gives
    /// every option equal width. Off-scale input is snapped by `clamped(_:)` first,
    /// so this always returns a valid index.
    public static func index(of value: TimeInterval) -> Int {
        let snapped = clamped(value)
        return allowedValues.firstIndex(of: snapped) ?? allowedValues.firstIndex(of: defaultValue) ?? 0
    }

    /// Value at a slider position, clamping out-of-range positions to the ends.
    ///
    /// Clamps rather than trapping because the caller converts a `Double` slider
    /// reading to `Int`, and rounding at the extremes can produce -1 or `count`.
    public static func value(atIndex index: Int) -> TimeInterval {
        guard !allowedValues.isEmpty else { return defaultValue }
        return allowedValues[min(max(index, 0), allowedValues.count - 1)]
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
