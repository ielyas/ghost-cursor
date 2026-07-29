import CoreGraphics
import Foundation

/// Runtime-resolved private CoreGraphics Services entry points.
///
/// These symbols are not in the public SDK. They are resolved with `dlsym` and
/// never with `@_silgen_name`: `@_silgen_name` binds at dyld load time, so if a
/// future macOS removes a symbol the app would fail to launch with an opaque
/// dyld error instead of degrading gracefully. `dlsym` returns nil, which is a
/// condition we can detect and report.
public enum CGSPrivate {
    public typealias ConnectionID = UInt32

    private typealias MainConnectionIDFunction = @convention(c) () -> ConnectionID
    private typealias SetConnectionPropertyFunction = @convention(c) (
        ConnectionID, ConnectionID, CFString, CFTypeRef
    ) -> CGError

    // `nonisolated(unsafe)` is correct rather than merely convenient: each value
    // is immutable, initialised once by the lazy-global runtime, and `dlopen`
    // and `dlsym` are themselves thread-safe.
    private nonisolated(unsafe) static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
        RTLD_LAZY
    )

    private nonisolated(unsafe) static let mainConnectionID: MainConnectionIDFunction? =
        function(named: "CGSMainConnectionID")

    private nonisolated(unsafe) static let setConnectionProperty: SetConnectionPropertyFunction? =
        function(named: "CGSSetConnectionProperty")

    private static func function<T>(named name: String) -> T? {
        guard let handle, let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }

    /// True when every private symbol this app needs was found.
    public static var isAvailable: Bool {
        mainConnectionID != nil && setConnectionProperty != nil
    }

    /// Grants this process permission to change cursor visibility while it is
    /// not the frontmost application. Without this, `CGDisplayHideCursor` is
    /// silently ineffective for a background agent.
    ///
    /// - Returns: the `CGError` from the underlying call, or `nil` if the
    ///   private symbols are unavailable.
    public static func enableBackgroundCursorControl() -> CGError? {
        guard let mainConnectionID, let setConnectionProperty else { return nil }
        let connection = mainConnectionID()
        return setConnectionProperty(
            connection,
            connection,
            "SetsCursorInBackground" as CFString,
            kCFBooleanTrue
        )
    }
}
