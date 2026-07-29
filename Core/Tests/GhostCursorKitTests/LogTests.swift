import Testing
@testable import GhostCursorKit

@Test func subsystemMatchesBundleIdentifier() {
    #expect(Log.subsystem == "sa.ni.GhostCursor")
}
