import GhostCursorKit
import SwiftUI

/// Settings › General. Binds straight to `AppState`, which owns persistence — the
/// view must not touch `UserDefaults`, or the menu and the window would drift.
struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section {
                Toggle("Auto-Hide Cursor", isOn: Binding(
                    get: { appState.autoHideEnabled },
                    set: { appState.autoHideEnabled = $0 }
                ))

                if appState.autoHideEnabled {
                    Slider(
                        value: Binding(
                            // Travels over the index, not seconds: the snap points are
                            // unevenly spaced, so binding to seconds would give the
                            // 30→60 gap most of the slider and allow values like 7.4.
                            get: { Double(HideDelay.index(of: appState.hideDelaySeconds)) },
                            set: { appState.hideDelaySeconds = HideDelay.value(atIndex: Int($0.rounded())) }
                        ),
                        in: 0...Double(HideDelay.allowedValues.count - 1),
                        step: 1
                    ) {
                        Text("Hide after")
                    } minimumValueLabel: {
                        Text(HideDelay.label(for: HideDelay.allowedValues.first ?? HideDelay.defaultValue))
                    } maximumValueLabel: {
                        Text(HideDelay.label(for: HideDelay.allowedValues.last ?? HideDelay.defaultValue))
                    }

                    LabeledContent("Current delay") {
                        Text(HideDelay.label(for: appState.hideDelaySeconds))
                            .monospacedDigit()
                    }
                }
            } footer: {
                Text("Hides the pointer after you stop moving the mouse, and brings it back the moment you move it again.")
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { appState.loginItemManager.isEnabled },
                    set: { appState.loginItemManager.setEnabled($0) }
                ))

                if appState.loginItemManager.requiresApproval {
                    Label(
                        "Approve GhostCursor in System Settings › General › Login Items to launch it at login.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.callout)
                }

                if let message = appState.loginItemManager.lastErrorMessage {
                    Label(message, systemImage: "xmark.octagon")
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        // The login item can be revoked in System Settings while this window is
        // open, so re-read the truth whenever the pane appears.
        .onAppear { appState.loginItemManager.refresh() }
    }
}
