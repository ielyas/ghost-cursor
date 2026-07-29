import OSLog

/// Centralised `OSLog` loggers. Categories match the diagnostic areas in the
/// specification so `log stream --predicate 'subsystem == "sa.ni.GhostCursor"'`
/// produces useful output for bug reports.
public enum Log {
    public static let subsystem = "sa.ni.GhostCursor"

    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    public static let cursor = Logger(subsystem: subsystem, category: "cursor")
    public static let idle = Logger(subsystem: subsystem, category: "idle")
    public static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
}
