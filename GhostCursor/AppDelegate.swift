import AppKit
import GhostCursorKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.lifecycle.info("GhostCursor launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.lifecycle.info("GhostCursor terminating")
    }
}
