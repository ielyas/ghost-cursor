import GhostCursorKit
import Observation

/// Single source of truth for app-wide state.
///
/// A singleton because this is an agent app with exactly one instance, and
/// because `AppDelegate` — which SwiftUI constructs independently via
/// `@NSApplicationDelegateAdaptor` — needs the same instance the scenes use.
@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    let cursorHider = CursorHider()

    private init() {}
}
