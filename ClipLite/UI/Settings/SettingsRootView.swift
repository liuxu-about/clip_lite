import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var settingsManager: SettingsManager
    let startupManager: StartupManager

    @State private var startupError: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)

                Picker("Global Shortcut", selection: hotkeyPresetBinding) {
                    ForEach(HotkeyPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                Picker("Theme", selection: themeModeBinding) {
                    Text("Follow System").tag(ThemeMode.followSystem)
                    Text("Light").tag(ThemeMode.light)
                    Text("Dark").tag(ThemeMode.dark)
                }

                Text("If the shortcut conflicts with another app, ClipLite keeps the previous shortcut.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Storage") {
                Stepper(value: maxItemCountBinding, in: 50...5000, step: 50) {
                    Text("Max history items: \(settingsManager.settings.maxItemCount)")
                }

                Stepper(value: maxRetentionDaysBinding, in: 1...365, step: 1) {
                    Text("Retention days: \(settingsManager.settings.maxRetentionDays)")
                }
            }

            Section("Advanced") {
                Toggle("Ignore consecutive duplicates", isOn: ignoreDuplicatesBinding)
                Toggle("Ignore whitespace text", isOn: ignoreWhitespaceBinding)
            }

            if let startupError {
                Section {
                    Text(startupError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 460, height: 420)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.settings.launchAtLogin },
            set: { value in
                do {
                    try startupManager.setLaunchAtLogin(enabled: value)
                    startupError = nil
                    settingsManager.update { $0.launchAtLogin = value }
                } catch {
                    startupError = "Failed to update launch at login: \(error)"
                }
            }
        )
    }

    private var themeModeBinding: Binding<ThemeMode> {
        Binding(
            get: { settingsManager.settings.themeMode },
            set: { value in
                settingsManager.update { $0.themeMode = value }
            }
        )
    }

    private var hotkeyPresetBinding: Binding<HotkeyPreset> {
        Binding(
            get: { settingsManager.settings.hotkeyPreset },
            set: { value in
                settingsManager.update { $0.hotkeyPreset = value }
            }
        )
    }

    private var maxItemCountBinding: Binding<Int> {
        Binding(
            get: { settingsManager.settings.maxItemCount },
            set: { value in
                settingsManager.update { $0.maxItemCount = value }
            }
        )
    }

    private var maxRetentionDaysBinding: Binding<Int> {
        Binding(
            get: { settingsManager.settings.maxRetentionDays },
            set: { value in
                settingsManager.update { $0.maxRetentionDays = value }
            }
        )
    }

    private var ignoreDuplicatesBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.settings.ignoreConsecutiveDuplicates },
            set: { value in
                settingsManager.update { $0.ignoreConsecutiveDuplicates = value }
            }
        )
    }

    private var ignoreWhitespaceBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.settings.ignoreWhitespaceText },
            set: { value in
                settingsManager.update { $0.ignoreWhitespaceText = value }
            }
        )
    }
}
