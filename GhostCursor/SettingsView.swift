import SwiftUI

/// The Settings scene's root.
///
/// Deliberately not a `TabView` yet — a single-tab tab bar looks like a bug. The
/// `TabView` arrives with the Shortcut tab, alongside About.
struct SettingsView: View {
    var body: some View {
        GeneralSettingsView()
    }
}
