/// Why the cursor was force-revealed. Carried for the log only, so a support
/// log shows which system event stood hiding down — the events differ wildly in
/// how reliably macOS delivers them, and this is how that gets diagnosed.
public enum RevealReason: String, Sendable {
    case screensSlept
    case screensWoke
    case systemWoke
    case screenLocked
    case screenUnlocked
    case sessionResigned
    case sessionBecameActive
    case displayReconfigured
}
