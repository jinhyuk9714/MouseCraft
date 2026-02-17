import SwiftUI
import ServiceManagement

// MARK: - Navigation Model

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case remap
    case scrolling
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .remap: return "Remap"
        case .scrolling: return "Scrolling"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .remap: return "computermouse"
        case .scrolling: return "arrow.up.and.down"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Root

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView(appState: appState)
        case .remap:
            RemapSettingsView(appState: appState)
        case .scrolling:
            ScrollingSettingsView(appState: appState)
        case .about:
            AboutView()
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCStyle.sectionSpacing) {
                SectionHeader(title: "Activation", systemImage: "power")

                SectionBox {
                    VStack(alignment: .leading, spacing: MCStyle.itemSpacing) {
                        HStack {
                            Label("Enable MouseCraft", systemImage: "computermouse.fill")
                            Spacer()
                            Toggle("", isOn: $appState.enabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .tint(MCStyle.accent)
                        }

                        Divider()

                        HStack {
                            Label("Launch at Login", systemImage: "arrow.clockwise")
                            Spacer()
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .tint(MCStyle.accent)
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
                        }
                    }
                }

                SectionHeader(title: "Permissions", systemImage: "shield.lefthalf.filled")

                SectionBox {
                    VStack(alignment: .leading, spacing: MCStyle.itemSpacing) {
                        HStack {
                            PermissionBadge(granted: appState.accessibilityTrusted)
                            Spacer()
                            if !appState.accessibilityTrusted {
                                Button("Request Access") {
                                    appState.requestAccessibility()
                                }
                                .controlSize(.small)
                                Button("System Settings...") {
                                    appState.openAccessibilitySettings()
                                }
                                .controlSize(.small)
                            }
                        }

                        if let statusMessage = appState.statusMessage {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - Remap

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
        Binding(get: { localSettings.enabled }, set: { localSettings.enabled = $0 })
    }

    private var button4Binding: Binding<RemapActionPreset> {
        Binding(get: { localSettings.button4Preset }, set: { localSettings.button4Preset = $0 })
    }

    private var button5Binding: Binding<RemapActionPreset> {
        Binding(get: { localSettings.button5Preset }, set: { localSettings.button5Preset = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCStyle.sectionSpacing) {
                SectionHeader(title: "Button Remapping", systemImage: "arrow.left.arrow.right")

                SectionBox {
                    HStack {
                        Label("Enable button remapping", systemImage: "computermouse")
                        Spacer()
                        Toggle("", isOn: remapEnabledBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .tint(MCStyle.accent)
                    }
                }

                SectionHeader(title: "Mappings", systemImage: "square.grid.2x2")

                SectionBox {
                    VStack(alignment: .leading, spacing: MCStyle.itemSpacing) {
                        HStack {
                            Text("Button 4")
                            Spacer()
                            Picker("", selection: button4Binding) {
                                ForEach(RemapActionPreset.allCases) { preset in
                                    Text(preset.displayName).tag(preset)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                            .disabled(!localSettings.enabled)
                        }

                        Divider()

                        HStack {
                            Text("Button 5")
                            Spacer()
                            Picker("", selection: button5Binding) {
                                ForEach(RemapActionPreset.allCases) { preset in
                                    Text(preset.displayName).tag(preset)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                            .disabled(!localSettings.enabled)
                        }
                    }
                }

                Text("Button 4, 5는 대부분 마우스의 사이드 버튼입니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)

                Spacer()
            }
            .padding(24)
        }
        .onAppear { syncFromAppState(appState.remapSettings) }
        .onChange(of: appState.remapSettings) { syncFromAppState($0) }
        .onChange(of: localSettings) { syncToAppState($0) }
    }
}

// MARK: - Scrolling

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
        Binding(get: { localSettings.enabled }, set: { localSettings.enabled = $0 })
    }

    private var smoothnessBinding: Binding<ScrollSmoothness> {
        Binding(get: { localSettings.smoothness }, set: { localSettings.smoothness = $0 })
    }

    private var speedBinding: Binding<Double> {
        Binding(get: { localSettings.speed }, set: { localSettings.speed = min(max($0, 0.5), 3.0) })
    }

    private var invertBinding: Binding<Bool> {
        Binding(get: { localSettings.invertMouseScroll }, set: { localSettings.invertMouseScroll = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCStyle.sectionSpacing) {
                SectionHeader(title: "Smooth Scrolling", systemImage: "arrow.up.and.down.circle")

                SectionBox {
                    HStack {
                        Label("Enable smooth scrolling", systemImage: "hand.draw")
                        Spacer()
                        Toggle("", isOn: scrollEnabledBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .tint(MCStyle.accent)
                    }
                }

                SectionHeader(title: "Smoothness", systemImage: "waveform.path")

                SectionBox {
                    Picker("", selection: smoothnessBinding) {
                        ForEach(ScrollSmoothness.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(!localSettings.enabled)
                }

                SectionHeader(title: "Speed & Direction", systemImage: "speedometer")

                SectionBox {
                    VStack(alignment: .leading, spacing: MCStyle.itemSpacing) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Speed")
                                Spacer()
                                Text(String(format: "%.1fx", localSettings.speed))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .font(.callout)
                            }
                            Slider(value: speedBinding, in: 0.5...3.0, step: 0.05)
                                .disabled(!localSettings.enabled)
                                .tint(MCStyle.accent)
                        }

                        Divider()

                        HStack {
                            Label("Invert scroll direction", systemImage: "arrow.up.arrow.down")
                            Spacer()
                            Toggle("", isOn: invertBinding)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .tint(MCStyle.accent)
                                .disabled(!localSettings.enabled)
                        }
                    }
                }

                Text("Regular/High 모드에서 부드러운 스크롤과 관성이 적용됩니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)

                Spacer()
            }
            .padding(24)
        }
        .onAppear { syncFromAppState(appState.scrollSettings) }
        .onChange(of: appState.scrollSettings) { syncFromAppState($0) }
        .onChange(of: localSettings) { syncToAppState($0) }
    }
}

// MARK: - About

private struct AboutView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 60)

            VStack(spacing: 12) {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(MCStyle.accent)

                Text("MouseCraft")
                    .font(.title.weight(.semibold))

                Text("Version \(version)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 32)

            SectionBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Privacy", systemImage: "lock.shield")
                        .font(.subheadline.weight(.semibold))

                    Text("MouseCraft는 완전히 로컬에서 동작하며, 텔레메트리를 전송하지 않습니다. 입력 이벤트는 저장되지 않으며, 키보드 이벤트는 모니터링하지 않습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
