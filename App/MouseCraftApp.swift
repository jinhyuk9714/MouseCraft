import SwiftUI

@main
struct MouseCraftApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("MouseCraft", systemImage: "computermouse") {
            StatusMenu(appState: appState)
        }
        .menuBarExtraStyle(.window)

        Window("MouseCraft", id: "settings") {
            SettingsView(appState: appState)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                    guard let window = notification.object as? NSWindow,
                          window.title == "MouseCraft" else { return }
                    DispatchQueue.main.async {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        .defaultSize(width: 560, height: 420)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.setActivationPolicy(.regular)
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        return true
    }
}
