import GhostCursorKit
import SwiftUI

/// Settings › Shortcut. Writes `AppState.hotKey`, which owns persistence and
/// Carbon registration — this view must not touch `UserDefaults` or
/// `HotKeyManager`.
struct ShortcutSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var isRecording = false
    @State private var showsModifierHint = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Toggle auto-hide") {
                    recorderField
                }

                HStack {
                    Button(isRecording ? "Cancel" : "Record Shortcut…") {
                        isRecording.toggle()
                        showsModifierHint = false
                    }

                    Button("Clear") {
                        appState.hotKey = nil
                        isRecording = false
                        showsModifierHint = false
                    }
                    .disabled(appState.hotKey == nil)
                }
            } footer: {
                Text("Press the shortcut anywhere to switch auto-hide on and off. Escape cancels, Delete clears.")
            }

            if showsModifierHint {
                Label(
                    "A shortcut needs at least one of ⌘, ⌥ or ⌃, so it can't fire while you type.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.callout)
            }

            if let conflict = conflictOwner {
                // Non-blocking by design: registration is first-come-first-served
                // and the user is allowed to win.
                Label(
                    "macOS already uses this for \(conflict). Yours may not work, or may take priority.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.callout)
            }

            if let message = appState.hotKeyManager.lastErrorMessage {
                Label(message, systemImage: "xmark.octagon")
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        // The spec's first-run flow wants the recorder ready to accept keys. Doing
        // it whenever nothing is assigned covers first run without a separate
        // one-shot flag, and is harmless — Escape cancels.
        .onAppear {
            if appState.hotKey == nil {
                isRecording = true
            }
        }
    }

    private var recorderField: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isRecording ? Color.accentColor : Color.secondary.opacity(0.5))

            Text(fieldLabel)
                .foregroundStyle(appState.hotKey == nil && !isRecording ? .secondary : .primary)

            ShortcutRecorderView(
                isRecording: $isRecording,
                onCapture: { combination in
                    appState.hotKey = combination
                    showsModifierHint = false
                },
                onClear: {
                    appState.hotKey = nil
                    showsModifierHint = false
                },
                onRejected: {
                    showsModifierHint = true
                }
            )
        }
        .frame(width: 180, height: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keyboard shortcut")
        .accessibilityValue(appState.hotKey?.displayString ?? "None")
        .accessibilityHint("Click, then press the key combination you want.")
    }

    private var fieldLabel: String {
        if isRecording { return "Press keys…" }
        return appState.hotKey?.displayString ?? "None"
    }

    private var conflictOwner: String? {
        appState.hotKey.flatMap(ShortcutConflicts.owner(of:))
    }
}
