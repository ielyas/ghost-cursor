import AppKit
import SwiftUI

/// Settings › About. Version, the privacy statement, and — the part that matters
/// — how to recover a cursor that is stuck hidden.
///
/// The recovery text is not boilerplate: a hidden cursor with no running process
/// to restore it is this app's worst failure mode, and this window is where a
/// confused user will look first.
struct AboutSettingsView: View {
    @State private var didCopyRecoveryCommand = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                        .resizable()
                        .frame(width: 128, height: 128)
                        .accessibilityHidden(true)

                    Text(Self.appName)
                        .font(.title2.weight(.semibold))

                    Text(Self.versionString)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("Privacy") {
                Text("GhostCursor makes no network requests, stores no data, and needs no system permissions. It reads only how long ago a mouse event happened — never what the event was.")
            }

            Section("Recover a stuck cursor") {
                Text("If the pointer ever stays invisible, quit GhostCursor. macOS restores the cursor as soon as the app's connection to the window server closes.")

                Text("If the menu bar icon is unreachable, run this in Terminal:")

                HStack {
                    Text(verbatim: Self.recoveryCommand)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)

                    Spacer(minLength: 8)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.recoveryCommand, forType: .string)
                        didCopyRecoveryCommand = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.5))
                            didCopyRecoveryCommand = false
                        }
                    } label: {
                        Image(systemName: didCopyRecoveryCommand ? "checkmark" : "doc.on.clipboard")
                    }
                    .buttonStyle(.borderless)
                    .help(didCopyRecoveryCommand ? "Copied" : "Copy")
                    .accessibilityLabel(
                        didCopyRecoveryCommand ? "Copied recovery command" : "Copy recovery command"
                    )
                }

                Text("A script that only \"shows the cursor\" cannot help: the hide belongs to GhostCursor's own window server connection, so nothing else can undo it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Link("© 2026 National Idea LLC", destination: URL(string: "https://ni.sa")!)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
    }

    private static let recoveryCommand = "pkill -x GhostCursor"

    private static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "GhostCursor"
    }

    private static var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }
}
