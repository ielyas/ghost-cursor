/// Identifies a Settings pane, so the first-run flow can open a specific one.
enum SettingsTab: Hashable {
    case general
    case shortcut
    case about
}
