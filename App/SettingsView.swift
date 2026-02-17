import SwiftUI
import ServiceManagement

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
        .frame(width: 560, height: 440)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable MouseCraft", isOn: $appState.enabled)

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        #if DEBUG
                        print("[MouseCraft] Launch at Login error: \(error)")
                        #endif
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Divider()

            Text("Permissions")
                .font(.headline)

            HStack {
                Label(
                    appState.accessibilityTrusted ? "Accessibility: Granted" : "Accessibility: Not Granted",
                    systemImage: appState.accessibilityTrusted ? "checkmark.seal" : "exclamationmark.triangle"
                )
                Spacer()
                if !appState.accessibilityTrusted {
                    Button("Request Accessibility…") {
                        appState.requestAccessibility()
                    }
                    Button("Open System Settings…") {
                        appState.openAccessibilitySettings()
                    }
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

            Text("Button 4, 5는 대부분 마우스의 사이드 버튼입니다.")
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
                    Text(String(format: "%.1fx", localSettings.speed))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: speedBinding, in: 0.5...3.0, step: 0.05)
                    .disabled(!localSettings.enabled)
            }

            Toggle("Invert mouse scroll", isOn: invertBinding)
                .disabled(!localSettings.enabled)

            Text("Regular/High 모드에서 부드러운 스크롤과 관성이 적용됩니다.")
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
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MouseCraft")
                .font(.title2)
                .bold()
            Text(version)
                .foregroundStyle(.secondary)

            Divider()

            Text("MouseCraft는 완전히 로컬에서 동작하며, 텔레메트리를 전송하지 않습니다. 입력 이벤트는 저장되지 않으며, 키보드 이벤트는 모니터링하지 않습니다.")
                .font(.callout)

            Spacer()
        }
    }
}
