import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView(appState: appState)
                .tabItem { Label("General", systemImage: "gearshape") }

            RemapSettingsView(appState: appState)
                .tabItem { Label("Remap", systemImage: "computermouse") }

            ScrollingSettingsView(appState: appState)
                .tabItem { Label("Scrolling", systemImage: "arrow.up.and.down") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(16)
        .frame(width: 560, height: 420)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable MouseCraft", isOn: $appState.enabled)

            Divider()

            Text("Permissions")
                .font(.headline)

            HStack {
                Label(
                    appState.accessibilityTrusted ? "Accessibility granted" : "Accessibility not granted",
                    systemImage: appState.accessibilityTrusted ? "checkmark.seal" : "exclamationmark.triangle"
                )
                Spacer()
                Button("Request") {
                    appState.requestAccessibility()
                }
                Button("Open Settings") {
                    appState.openAccessibilitySettings()
                }
            }


            if let statusMessage = appState.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
    }
}

private struct RemapSettingsView: View {
    @ObservedObject var appState: AppState

    @State private var localSettings: RemapSettings

    init(appState: AppState) {
        self.appState = appState
        _localSettings = State(initialValue: appState.remapSettings)
    }

    private func syncFromAppState(_ latest: RemapSettings) {
        guard localSettings != latest else { return }
        localSettings = latest
    }

    private func syncToAppState(_ latest: RemapSettings) {
        guard appState.remapSettings != latest else { return }
        appState.remapSettings = latest
    }

    private var remapEnabledBinding: Binding<Bool> {
        Binding(
            get: { localSettings.enabled },
            set: { value in
                localSettings.enabled = value
            }
        )
    }

    private var button4Binding: Binding<RemapActionPreset> {
        Binding(
            get: { localSettings.button4Preset },
            set: { value in
                localSettings.button4Preset = value
            }
        )
    }

    private var button5Binding: Binding<RemapActionPreset> {
        Binding(
            get: { localSettings.button5Preset },
            set: { value in
                localSettings.button5Preset = value
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable button remapping", isOn: remapEnabledBinding)

            Form {
                Picker("Button 4", selection: button4Binding) {
                    ForEach(RemapActionPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .disabled(!localSettings.enabled)

                Picker("Button 5", selection: button5Binding) {
                    ForEach(RemapActionPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .disabled(!localSettings.enabled)
            }
            .formStyle(.grouped)

            Text("MVP supports fixed slots for side buttons: raw buttonNumber 3 -> Button 4, 4 -> Button 5.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .onAppear {
            syncFromAppState(appState.remapSettings)
        }
        .onChange(of: appState.remapSettings) { latest in
            syncFromAppState(latest)
        }
        .onChange(of: localSettings) { latest in
            syncToAppState(latest)
        }
    }
}

private struct ScrollingSettingsView: View {
    @ObservedObject var appState: AppState

    @State private var localSettings: ScrollSettings

    init(appState: AppState) {
        self.appState = appState
        _localSettings = State(initialValue: appState.scrollSettings)
    }

    private func syncFromAppState(_ latest: ScrollSettings) {
        guard localSettings != latest else { return }
        localSettings = latest
    }

    private func syncToAppState(_ latest: ScrollSettings) {
        guard appState.scrollSettings != latest else { return }
        appState.scrollSettings = latest
    }

    private var scrollEnabledBinding: Binding<Bool> {
        Binding(
            get: { localSettings.enabled },
            set: { value in
                localSettings.enabled = value
            }
        )
    }

    private var smoothnessBinding: Binding<ScrollSmoothness> {
        Binding(
            get: { localSettings.smoothness },
            set: { value in
                localSettings.smoothness = value
            }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { localSettings.speed },
            set: { value in
                localSettings.speed = min(max(value, 0.5), 3.0)
            }
        )
    }

    private var invertBinding: Binding<Bool> {
        Binding(
            get: { localSettings.invertMouseScroll },
            set: { value in
                localSettings.invertMouseScroll = value
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable smooth scrolling", isOn: scrollEnabledBinding)

            Picker("Smoothness", selection: smoothnessBinding) {
                ForEach(ScrollSmoothness.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!localSettings.enabled)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Speed")
                    Spacer()
                    Text(String(format: "%.2fx", localSettings.speed))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: speedBinding, in: 0.5...3.0, step: 0.05)
                    .disabled(!localSettings.enabled)
            }

            Toggle("Invert mouse scroll", isOn: invertBinding)
                .disabled(!localSettings.enabled)

            Text("Vertical wheel deltas are transformed with EMA + momentum in Regular/High modes.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .onAppear {
            syncFromAppState(appState.scrollSettings)
        }
        .onChange(of: appState.scrollSettings) { latest in
            syncFromAppState(latest)
        }
        .onChange(of: localSettings) { latest in
            syncToAppState(latest)
        }
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MouseCraft")
                .font(.title2)
            Text("Privacy-first mouse enhancer for macOS.")
                .foregroundStyle(.secondary)

            Divider()

            Text("MouseCraft runs locally and does not send telemetry by default.")
                .font(.caption)
            Text("Raw input events are not stored.")
                .font(.caption)
            Text("Keyboard monitoring is not enabled in v0.1.")
                .font(.caption)

            Spacer()
        }
    }
}
