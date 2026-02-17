import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Navigation Model

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case remap
    case scrolling
    case apps
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .remap: return "Remap"
        case .scrolling: return "Scrolling"
        case .apps: return "Apps"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .remap: return "computermouse"
        case .scrolling: return "arrow.up.and.down"
        case .apps: return "square.grid.2x2"
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
        case .apps:
            AppProfilesView(appState: appState)
        case .about:
            AboutView()
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var importMessage: String?
    @State private var importSuccess = false

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

                SectionHeader(title: "Backup & Restore", systemImage: "square.and.arrow.up.on.square")

                SectionBox {
                    VStack(alignment: .leading, spacing: MCStyle.itemSpacing) {
                        HStack {
                            Label("Export all settings and app profiles to a JSON file.", systemImage: "square.and.arrow.up")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Export...") {
                                exportSettings()
                            }
                            .controlSize(.small)
                        }

                        Divider()

                        HStack {
                            Label("Import settings from a JSON file.", systemImage: "square.and.arrow.down")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Import...") {
                                importSettings()
                            }
                            .controlSize(.small)
                        }
                    }
                }

                if let importMessage {
                    Text(importMessage)
                        .font(.caption)
                        .foregroundStyle(importSuccess ? .green : .orange)
                }

                Spacer()
            }
            .padding(24)
        }
    }

    private func exportSettings() {
        guard let data = appState.exportSettings() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "MouseCraft-Settings.json"
        panel.title = "Export MouseCraft Settings"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url)
            importMessage = "Settings exported successfully."
            importSuccess = true
        } catch {
            importMessage = "Export failed: \(error.localizedDescription)"
            importSuccess = false
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Import MouseCraft Settings"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            try appState.importSettings(from: data)
            importMessage = "Settings imported successfully."
            importSuccess = true
        } catch {
            importMessage = "Import failed: \(error.localizedDescription)"
            importSuccess = false
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

// MARK: - Apps

private struct AppProfilesView: View {
    @ObservedObject var appState: AppState
    @State private var selectedProfileID: UUID?
    @State private var showingAppPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCStyle.sectionSpacing) {
                HStack {
                    SectionHeader(title: "App Profiles", systemImage: "square.grid.2x2")
                    Spacer()
                    Button {
                        showingAppPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }

                if appState.profiles.isEmpty {
                    SectionBox {
                        VStack(spacing: 8) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 28))
                                .foregroundStyle(.tertiary)
                            Text("No app profiles yet")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("Add a profile to customize settings per application.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                } else {
                    SectionBox {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(appState.profiles.enumerated()), id: \.element.id) { index, profile in
                                if index > 0 {
                                    Divider()
                                }
                                ProfileRow(
                                    profile: profile,
                                    isSelected: selectedProfileID == profile.id,
                                    onSelect: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedProfileID = selectedProfileID == profile.id ? nil : profile.id
                                        }
                                    },
                                    onDelete: {
                                        appState.removeProfile(profile)
                                        if selectedProfileID == profile.id {
                                            selectedProfileID = nil
                                        }
                                    }
                                )
                            }
                        }
                    }
                }

                if let profileID = selectedProfileID,
                   let index = appState.profiles.firstIndex(where: { $0.id == profileID }) {
                    AppProfileDetailView(
                        appState: appState,
                        profile: $appState.profiles[index]
                    )
                }

                Text("앱별로 다른 리맵/스크롤 설정을 적용할 수 있습니다. 설정하지 않은 항목은 전역 설정을 따릅니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)

                Spacer()
            }
            .padding(24)
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(
                existingBundleIDs: Set(appState.profiles.map(\.bundleIdentifier))
            ) { bundleID, displayName in
                let profile = AppProfile(
                    id: UUID(),
                    bundleIdentifier: bundleID,
                    displayName: displayName,
                    remap: nil,
                    scroll: nil
                )
                appState.addProfile(profile)
                selectedProfileID = profile.id
            }
        }
    }
}

private struct ProfileRow: View {
    let profile: AppProfile
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    private var overrideSummary: String {
        var parts: [String] = []
        if profile.remap != nil { parts.append("Remap") }
        if profile.scroll != nil { parts.append("Scroll") }
        return parts.isEmpty ? "No overrides" : parts.joined(separator: ", ")
    }

    var body: some View {
        HStack {
            AppIconView(bundleIdentifier: profile.bundleIdentifier)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.body)
                Text(overrideSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .controlSize(.small)

            Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

private struct AppIconView: View {
    let bundleIdentifier: String

    private var appIcon: NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        Group {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
            } else {
                Image(systemName: "app")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
    }
}

private struct AppProfileDetailView: View {
    @ObservedObject var appState: AppState
    @Binding var profile: AppProfile

    var body: some View {
        VStack(alignment: .leading, spacing: MCStyle.sectionSpacing) {
            SectionHeader(title: "Remap Override", systemImage: "arrow.left.arrow.right")

            SectionBox {
                VStack(alignment: .leading, spacing: MCStyle.itemSpacing) {
                    OverrideToggleRow(
                        label: "Enable remapping",
                        globalValue: appState.remapSettings.enabled,
                        override: $profile.remap.transform(
                            get: { $0?.enabled },
                            set: { newVal in ensureRemapOverride(); profile.remap?.enabled = newVal }
                        )
                    )

                    Divider()

                    OverridePickerRow(
                        label: "Button 4",
                        globalValue: appState.remapSettings.button4Preset,
                        override: $profile.remap.transform(
                            get: { $0?.button4Preset },
                            set: { newVal in ensureRemapOverride(); profile.remap?.button4Preset = newVal }
                        ),
                        allCases: RemapActionPreset.allCases
                    )

                    Divider()

                    OverridePickerRow(
                        label: "Button 5",
                        globalValue: appState.remapSettings.button5Preset,
                        override: $profile.remap.transform(
                            get: { $0?.button5Preset },
                            set: { newVal in ensureRemapOverride(); profile.remap?.button5Preset = newVal }
                        ),
                        allCases: RemapActionPreset.allCases
                    )
                }
            }

            SectionHeader(title: "Scroll Override", systemImage: "arrow.up.and.down.circle")

            SectionBox {
                VStack(alignment: .leading, spacing: MCStyle.itemSpacing) {
                    OverrideToggleRow(
                        label: "Enable smooth scrolling",
                        globalValue: appState.scrollSettings.enabled,
                        override: $profile.scroll.transform(
                            get: { $0?.enabled },
                            set: { newVal in ensureScrollOverride(); profile.scroll?.enabled = newVal }
                        )
                    )

                    Divider()

                    OverridePickerRow(
                        label: "Smoothness",
                        globalValue: appState.scrollSettings.smoothness,
                        override: $profile.scroll.transform(
                            get: { $0?.smoothness },
                            set: { newVal in ensureScrollOverride(); profile.scroll?.smoothness = newVal }
                        ),
                        allCases: ScrollSmoothness.allCases
                    )

                    Divider()

                    OverrideSpeedRow(
                        globalValue: appState.scrollSettings.speed,
                        override: $profile.scroll.transform(
                            get: { $0?.speed },
                            set: { newVal in ensureScrollOverride(); profile.scroll?.speed = newVal }
                        )
                    )

                    Divider()

                    OverrideToggleRow(
                        label: "Invert scroll direction",
                        globalValue: appState.scrollSettings.invertMouseScroll,
                        override: $profile.scroll.transform(
                            get: { $0?.invertMouseScroll },
                            set: { newVal in ensureScrollOverride(); profile.scroll?.invertMouseScroll = newVal }
                        )
                    )
                }
            }
        }
        .onChange(of: profile) { newValue in
            appState.updateProfile(newValue)
        }
    }

    private func ensureRemapOverride() {
        if profile.remap == nil {
            profile.remap = RemapOverride()
        }
    }

    private func ensureScrollOverride() {
        if profile.scroll == nil {
            profile.scroll = ScrollOverride()
        }
    }
}

// MARK: - Override Controls

private struct OverrideToggleRow: View {
    let label: String
    let globalValue: Bool
    @Binding var override: Bool?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if override == nil {
                Text("Global: \(globalValue ? "On" : "Off")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Menu {
                Button("Use Global") { override = nil }
                Divider()
                Button("On") { override = true }
                Button("Off") { override = false }
            } label: {
                Text(override == nil ? "Global" : (override! ? "On" : "Off"))
                    .frame(width: 70)
            }
            .controlSize(.small)
        }
    }
}

private struct OverridePickerRow<T: Hashable & Identifiable & CaseIterable>: View where T: RawRepresentable, T.RawValue == String, T.AllCases: RandomAccessCollection {
    let label: String
    let globalValue: T
    @Binding var override: T?
    let allCases: T.AllCases

    private var displayName: (T) -> String {
        { ($0 as? RemapActionPreset)?.displayName ?? ($0 as? ScrollSmoothness)?.displayName ?? $0.rawValue }
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if override == nil {
                Text("Global: \(displayName(globalValue))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Menu {
                Button("Use Global") { override = nil }
                Divider()
                ForEach(allCases) { item in
                    Button(displayName(item)) { override = item }
                }
            } label: {
                Text(override == nil ? "Global" : displayName(override!))
                    .frame(width: 120)
            }
            .controlSize(.small)
        }
    }
}

private struct OverrideSpeedRow: View {
    let globalValue: Double
    @Binding var override: Double?

    var body: some View {
        HStack {
            Text("Speed")
            Spacer()
            if override == nil {
                Text("Global: \(String(format: "%.1fx", globalValue))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Menu {
                Button("Use Global") { override = nil }
                Divider()
                ForEach([0.5, 1.0, 1.5, 2.0, 2.5, 3.0], id: \.self) { val in
                    Button(String(format: "%.1fx", val)) { override = val }
                }
            } label: {
                Text(override == nil ? "Global" : String(format: "%.1fx", override!))
                    .frame(width: 70)
            }
            .controlSize(.small)
        }
    }
}

// MARK: - App Picker Sheet

private struct AppPickerSheet: View {
    let existingBundleIDs: Set<String>
    let onSelect: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != nil }
            .filter { !existingBundleIDs.contains($0.bundleIdentifier!) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add App Profile")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if runningApps.isEmpty {
                VStack(spacing: 8) {
                    Text("No available apps")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("All running apps already have profiles.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(runningApps, id: \.processIdentifier) { app in
                    HStack(spacing: 10) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Text(app.localizedName ?? "Unknown")
                        Spacer()
                        Text(app.bundleIdentifier ?? "")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let bundleID = app.bundleIdentifier ?? ""
                        let name = app.localizedName ?? bundleID
                        onSelect(bundleID, name)
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 350)
    }
}

// MARK: - Binding Helpers

private extension Binding {
    func transform<T>(get: @escaping (Value) -> T, set: @escaping (T) -> Void) -> Binding<T> {
        Binding<T>(
            get: { get(self.wrappedValue) },
            set: { newVal in set(newVal); self.wrappedValue = self.wrappedValue }
        )
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
