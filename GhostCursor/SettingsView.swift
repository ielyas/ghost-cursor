import SwiftUI

/// The Settings scene's root.
///
/// The `.frame(width:)` lives here rather than on each pane so that switching
/// tabs does not resize the window — the spec's fixed ~460 pt width with
/// content-driven height.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: SettingsTab = .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            ShortcutSettingsView()
                .tabItem { Label("Shortcut", systemImage: "keyboard") }
                .tag(SettingsTab.shortcut)
        }
        .frame(width: 460)
        .onAppear {
            // Consumed rather than observed, so re-opening Settings later returns
            // to whichever tab the user last chose.
            if let pending = appState.pendingSettingsTab {
                selection = pending
                appState.pendingSettingsTab = nil
            }
        }
    }
}
