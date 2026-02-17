import Foundation
import AppKit

/// Tracks the frontmost application's bundle identifier.
/// Thread-safe: the bundle ID is read via NSLock (sub-microsecond pointer copy).
final class FrontmostAppTracker {
    private let lock = NSLock()
    private var _bundleID: String?
    private var observation: NSObjectProtocol?

    var currentBundleID: String? {
        lock.lock()
        let value = _bundleID
        lock.unlock()
        return value
    }

    init() {
        _bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        observation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let newID = app?.bundleIdentifier
            self.lock.lock()
            self._bundleID = newID
            self.lock.unlock()
        }
    }

    deinit {
        if let observation {
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
        }
    }
}
