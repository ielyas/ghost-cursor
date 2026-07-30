import SwiftUI

/// Settings › About. Version, the privacy statement, and — the part that matters
/// — how to recover a cursor that is stuck hidden.
///
/// The recovery text is not boilerplate: a hidden cursor with no running process
/// to restore it is this app's worst failure mode, and this window is where a
/// confused user will look first.
struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: Self.versionString)
            }

            Section("Privacy") {
                Text("GhostCursor makes no network requests, stores no data, and needs no system permissions. It reads only how long ago a mouse event happened — never what the event was.")
            }

            Section("Recover a stuck cursor") {
                Text("If the pointer ever stays invisible, quit GhostCursor. macOS restores the cursor as soon as the app's connection to the window server closes.")

                Text("If the menu bar icon is unreachable, run this in Terminal:")

                Text(verbatim: "pkill -x GhostCursor")
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)

                Text("A script that only \"shows the cursor\" cannot help: the hide belongs to GhostCursor's own window server connection, so nothing else can undo it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private static var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }
}
