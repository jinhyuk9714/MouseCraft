import SwiftUI

struct StatusMenu: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, MCStyle.popoverPadding)
                .padding(.top, MCStyle.popoverPadding)
                .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, MCStyle.popoverPadding)

            // Features
            VStack(spacing: MCStyle.itemSpacing) {
                FeatureRow(
                    icon: "arrow.left.arrow.right",
                    iconColor: .purple,
                    title: "Button Remap",
                    isOn: $appState.remapSettings.enabled,
                    disabled: !appState.enabled
                )
                FeatureRow(
                    icon: "arrow.up.and.down.circle",
                    iconColor: .blue,
                    title: "Smooth Scroll",
                    isOn: $appState.scrollSettings.enabled,
                    disabled: !appState.enabled
                )
            }
            .padding(MCStyle.popoverPadding)

            // Permission (only when not granted)
            if !appState.accessibilityTrusted {
                Divider()
                    .padding(.horizontal, MCStyle.popoverPadding)

                permissionSection
                    .padding(MCStyle.popoverPadding)
            }

            // Status message
            if let statusMessage = appState.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, MCStyle.popoverPadding)
                    .padding(.bottom, 8)
            }

#if DEBUG
            Divider()
                .padding(.horizontal, MCStyle.popoverPadding)
            debugSection
                .padding(.horizontal, MCStyle.popoverPadding)
                .padding(.vertical, 6)
#endif

            Divider()
                .padding(.horizontal, MCStyle.popoverPadding)

            // Footer
            footer
                .padding(MCStyle.popoverPadding)
        }
        .frame(width: 280)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(MCStyle.accent)
            Text("MouseCraft")
                .font(.headline)
            Spacer()
            PowerToggle(isOn: $appState.enabled)
        }
    }

    // MARK: - Permission

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PermissionBadge(granted: appState.accessibilityTrusted)

            HStack(spacing: 8) {
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
    }

    // MARK: - Debug

#if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Debug: \(appState.debugEventCounts.total) events")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("down=\(appState.debugEventCounts.otherMouseDown) up=\(appState.debugEventCounts.otherMouseUp) scroll=\(appState.debugEventCounts.scrollWheel)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }
#endif

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                openWindow(id: "settings")
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
            } label: {
                Label("Settings...", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .font(.subheadline)
    }
}
