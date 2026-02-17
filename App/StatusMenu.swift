import SwiftUI

struct StatusMenu: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable MouseCraft", isOn: $appState.enabled)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label(
                    appState.accessibilityTrusted ? "Accessibility: Granted" : "Accessibility: Not granted",
                    systemImage: appState.accessibilityTrusted ? "checkmark.seal" : "exclamationmark.triangle"
                )

                HStack(spacing: 8) {
                    Button("Request Accessibility…") {
                        appState.requestAccessibility()
                    }
                    Button("Open Accessibility Settings") {
                        appState.openAccessibilitySettings()
                    }
                }


            }

            if let statusMessage = appState.statusMessage {
                Divider()
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

#if DEBUG
            Divider()

            Text("Debug events seen: \(appState.debugEventCounts.total)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("otherDown=\(appState.debugEventCounts.otherMouseDown), otherUp=\(appState.debugEventCounts.otherMouseUp), scroll=\(appState.debugEventCounts.scrollWheel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
#endif

            Divider()

            Button("Open Settings") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(minWidth: 320)
    }
}
