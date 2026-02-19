import Foundation
import Combine

/// Determines whether the event tap must run in active-filter mode
/// (i.e. it needs to suppress/transform events) vs listen-only.
func needsActiveFilter(remap: RemapSettings, scroll: ScrollSettings, gesture: GestureSettings = .default) -> Bool {
    if remap.enabled {
        return true
    }

    if gesture.enabled {
        return true
    }

    guard scroll.enabled else {
        return false
    }

    if scroll.smoothness != .off {
        return true
    }

    let normalizedSpeed = scroll.speed.clamped(to: 0.5...3.0)
    if normalizedSpeed != 1.0 {
        return true
    }

    return scroll.invertMouseScroll || scroll.invertHorizontalScroll
}

#if DEBUG
struct DebugEventCounts {
    var otherMouseDown: Int = 0
    var otherMouseUp: Int = 0
    var otherMouseDragged: Int = 0
    var scrollWheel: Int = 0

    var total: Int {
        otherMouseDown + otherMouseUp + otherMouseDragged + scrollWheel
    }
}
#endif

/// Central state manager. All `@Published` properties must be accessed on the main thread.
/// The `handleEvent` path runs on the CGEventTap callback thread and accesses only
/// lock-protected `runtime*` properties and thread-safe engine objects.
/// Note: `@MainActor` is not applied because `handleEvent`/`runtimeSettingsSnapshot`
/// must run off the main thread, and extracting shared state into a Sendable wrapper
/// would require significant refactoring for minimal practical benefit (these objects
/// are app-lifetime singletons owned by @StateObject).
final class AppState: ObservableObject {
    @Published var enabled: Bool = false {
        didSet {
            guard !isBootstrapping else { return }
            persistGeneralSettings()
            // Internal disable path can set a failure message; avoid immediate
            // reconfigure that would clear it before the user sees it.
            if !isInternalDisable {
                schedulePipelineReconfigure()
            }
        }
    }

    @Published var showInMenuBar: Bool = true {
        didSet {
            guard !isBootstrapping else { return }
            persistGeneralSettings()
        }
    }

    @Published var remapSettings: RemapSettings = .default {
        didSet {
            guard !isBootstrapping else { return }
            settingsStore.saveRemap(remapSettings)
            syncRuntimeSettings()
            if enabled {
                schedulePipelineReconfigure()
            }
        }
    }

    @Published var scrollSettings: ScrollSettings = .default {
        didSet {
            guard !isBootstrapping else { return }
            settingsStore.saveScroll(scrollSettings)
            syncRuntimeSettings()
            scrollEngine.reset()
            if enabled {
                schedulePipelineReconfigure()
            }
        }
    }

    @Published var gestureSettings: GestureSettings = .default {
        didSet {
            guard !isBootstrapping else { return }
            settingsStore.saveGesture(gestureSettings)
            syncRuntimeSettings()
            gestureEngine.reset()
            if enabled {
                schedulePipelineReconfigure()
            }
        }
    }

    @Published var hasCompletedOnboarding: Bool = false

    @Published var profiles: [AppProfile] = []

    @Published var deviceProfiles: [DeviceProfile] = []
    @Published var activeDeviceKey: String? = nil
    @Published var connectedDevices: [HIDDeviceInfo] = []

    @Published var accessibilityTrusted: Bool = false
    @Published var statusMessage: String? = nil

#if DEBUG
    @Published var debugEventCounts = DebugEventCounts()
#endif

    private let permissionManager = PermissionManager()
    private let settingsStore = SettingsStore()
    private let eventTap = EventTapManager()
    private let remapEngine = ButtonRemapEngine()
    private let scrollEngine = ScrollEngine()
    private let gestureEngine = GestureEngine()

    private let hidDeviceManager = HIDDeviceManager()

    private let runtimeLock = NSLock()
    private var runtimeRemapSettings: RemapSettings = .default
    private var runtimeScrollSettings: ScrollSettings = .default
    private var runtimeGestureSettings: GestureSettings = .default
    private var runtimeProfiles: [String: AppProfile] = [:]
    private var runtimeDeviceProfiles: [String: DeviceProfile] = [:]
    private var runtimeActiveDeviceKey: String? = nil

    private let frontmostAppTracker = FrontmostAppTracker()

    private var isBootstrapping = true
    private var isInternalDisable = false
    private var isReconfigureScheduled = false
    private var permissionTimer: Timer?

    deinit {
        permissionTimer?.invalidate()
    }

    init() {
        let settings = settingsStore.load()
        enabled = settings.general.enabled
        showInMenuBar = settings.general.showInMenuBar
        remapSettings = settings.remap
        scrollSettings = settings.scroll
        gestureSettings = settings.gesture
        hasCompletedOnboarding = settingsStore.loadOnboardingCompleted()
        profiles = settingsStore.loadProfiles()
        deviceProfiles = settingsStore.loadDeviceProfiles()
        activeDeviceKey = settingsStore.loadActiveDeviceKey()

        runtimeRemapSettings = remapSettings
        runtimeScrollSettings = scrollSettings
        runtimeGestureSettings = gestureSettings
        runtimeProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.bundleIdentifier, $0) })
        runtimeDeviceProfiles = Dictionary(uniqueKeysWithValues: deviceProfiles.map { ($0.deviceKey, $0) })
        runtimeActiveDeviceKey = activeDeviceKey

        hidDeviceManager.onDevicesChanged = { [weak self] in
            guard let self else { return }
            self.connectedDevices = self.hidDeviceManager.connectedDevices
            self.autoSelectDeviceIfNeeded()
        }
        connectedDevices = hidDeviceManager.connectedDevices

        isBootstrapping = false
        autoSelectDeviceIfNeeded()
        refreshPermissions()
        reconfigurePipeline()
        startPermissionTimer()
    }

    private func startPermissionTimer() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let current = self.permissionManager.isAccessibilityTrusted(prompt: false)
            if current != self.accessibilityTrusted {
                self.accessibilityTrusted = current
                if current && self.enabled {
                    self.reconfigurePipeline()
                }
            }
        }
    }

    func refreshPermissions() {
        dispatchPrecondition(condition: .onQueue(.main))
        accessibilityTrusted = permissionManager.isAccessibilityTrusted(prompt: false)
    }

    func requestAccessibility() {
        _ = permissionManager.isAccessibilityTrusted(prompt: true)
        refreshPermissions()
        reconfigurePipeline()
    }

    func openAccessibilitySettings() {
        _ = permissionManager.openAccessibilitySettings()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        settingsStore.saveOnboardingCompleted(true)
    }

    // MARK: - Profile CRUD

    func addProfile(_ profile: AppProfile) {
        guard !profiles.contains(where: { $0.bundleIdentifier == profile.bundleIdentifier }) else { return }
        profiles.append(profile)
        persistProfiles()
    }

    func updateProfile(_ profile: AppProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        persistProfiles()
    }

    func removeProfile(_ profile: AppProfile) {
        profiles.removeAll { $0.id == profile.id }
        persistProfiles()
    }

    // MARK: - Device Profile CRUD

    func addDeviceProfile(_ profile: DeviceProfile) {
        guard !deviceProfiles.contains(where: { $0.deviceKey == profile.deviceKey }) else { return }
        deviceProfiles.append(profile)
        persistDeviceProfiles()
    }

    func updateDeviceProfile(_ profile: DeviceProfile) {
        guard let index = deviceProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        deviceProfiles[index] = profile
        persistDeviceProfiles()
    }

    func removeDeviceProfile(_ profile: DeviceProfile) {
        deviceProfiles.removeAll { $0.id == profile.id }
        persistDeviceProfiles()
    }

    func setActiveDevice(_ deviceKey: String?) {
        activeDeviceKey = deviceKey
        settingsStore.saveActiveDeviceKey(deviceKey)
        syncRuntimeSettings()
        if enabled {
            schedulePipelineReconfigure()
        }
    }

    private func autoSelectDeviceIfNeeded() {
        let devices = connectedDevices
        switch devices.count {
        case 0:
            if activeDeviceKey != nil {
                setActiveDevice(nil)
            }
        case 1:
            let key = devices[0].deviceKey
            if activeDeviceKey != key {
                setActiveDevice(key)
            }
        default:
            // Multiple mice: keep manual selection.
            // Clear if the active device is no longer connected.
            if let key = activeDeviceKey, !devices.contains(where: { $0.deviceKey == key }) {
                setActiveDevice(nil)
            }
        }
    }

    private func persistDeviceProfiles() {
        settingsStore.saveDeviceProfiles(deviceProfiles)
        syncRuntimeSettings()
        if enabled {
            schedulePipelineReconfigure()
        }
    }

    // MARK: - Settings Export/Import

    func exportSettings() -> Data? {
        let export = SettingsExport(
            schemaVersion: AppSettings.schemaVersion,
            exportDate: ISO8601DateFormatter().string(from: Date()),
            general: GeneralSettings(enabled: enabled, showInMenuBar: showInMenuBar),
            remap: remapSettings,
            scroll: scrollSettings,
            gesture: gestureSettings,
            profiles: profiles,
            deviceProfiles: deviceProfiles
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(export)
    }

    func importSettings(from data: Data) throws {
        let decoder = JSONDecoder()
        let imported = try decoder.decode(SettingsExport.self, from: data)

        isBootstrapping = true
        enabled = imported.general.enabled
        showInMenuBar = imported.general.showInMenuBar
        remapSettings = imported.remap
        scrollSettings = ScrollSettings(
            enabled: imported.scroll.enabled,
            smoothness: imported.scroll.smoothness,
            speed: imported.scroll.speed.clamped(to: 0.5...3.0),
            acceleration: imported.scroll.acceleration.clamped(to: 0.0...1.0),
            momentum: imported.scroll.momentum.clamped(to: 0.0...1.0),
            invertMouseScroll: imported.scroll.invertMouseScroll,
            invertHorizontalScroll: imported.scroll.invertHorizontalScroll
        )
        gestureSettings = imported.gesture ?? .default
        profiles = imported.profiles
        deviceProfiles = imported.deviceProfiles ?? []
        isBootstrapping = false

        settingsStore.saveGeneral(GeneralSettings(enabled: enabled, showInMenuBar: showInMenuBar))
        settingsStore.saveRemap(remapSettings)
        settingsStore.saveScroll(scrollSettings)
        settingsStore.saveGesture(gestureSettings)
        settingsStore.saveProfiles(profiles)
        settingsStore.saveDeviceProfiles(deviceProfiles)
        syncRuntimeSettings()
        scrollEngine.reset()
        gestureEngine.reset()
        schedulePipelineReconfigure()
    }

    private func persistProfiles() {
        settingsStore.saveProfiles(profiles)
        syncRuntimeSettings()
        if enabled {
            schedulePipelineReconfigure()
        }
    }

    private func persistGeneralSettings() {
        let general = GeneralSettings(enabled: enabled, showInMenuBar: showInMenuBar)
        settingsStore.saveGeneral(general)
    }

    private func syncRuntimeSettings() {
        runtimeLock.lock()
        runtimeRemapSettings = remapSettings
        runtimeScrollSettings = scrollSettings
        runtimeGestureSettings = gestureSettings
        runtimeProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.bundleIdentifier, $0) })
        runtimeDeviceProfiles = Dictionary(uniqueKeysWithValues: deviceProfiles.map { ($0.deviceKey, $0) })
        runtimeActiveDeviceKey = activeDeviceKey
        runtimeLock.unlock()
    }

    private func schedulePipelineReconfigure() {
        guard !isReconfigureScheduled else { return }
        isReconfigureScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isReconfigureScheduled = false
            self.reconfigurePipeline()
        }
    }

    /// Called from event tap thread via handleEvent(). Thread-safe via runtimeLock.
    private func runtimeSettingsSnapshot() -> (RemapSettings, ScrollSettings, GestureSettings) {
        runtimeLock.lock()
        let globalRemap = runtimeRemapSettings
        let globalScroll = runtimeScrollSettings
        let globalGesture = runtimeGestureSettings
        let profilesMap = runtimeProfiles
        let deviceProfilesMap = runtimeDeviceProfiles
        let deviceKey = runtimeActiveDeviceKey
        runtimeLock.unlock()

        let bundleID = frontmostAppTracker.currentBundleID
        let appProfile = bundleID.flatMap { profilesMap[$0] }
        let deviceProfile = deviceKey.flatMap { deviceProfilesMap[$0] }

        return (
            resolvedRemap(global: globalRemap, appOverride: appProfile?.remap, deviceOverride: deviceProfile?.remap),
            resolvedScroll(global: globalScroll, appOverride: appProfile?.scroll, deviceOverride: deviceProfile?.scroll),
            resolvedGesture(global: globalGesture, appOverride: appProfile?.gesture, deviceOverride: deviceProfile?.gesture)
        )
    }

    private func anyConfigNeedsActiveFilter() -> Bool {
        if needsActiveFilter(remap: remapSettings, scroll: scrollSettings, gesture: gestureSettings) {
            return true
        }
        for profile in profiles {
            let r = resolvedRemap(global: remapSettings, override: profile.remap)
            let s = resolvedScroll(global: scrollSettings, override: profile.scroll)
            let g = resolvedGesture(global: gestureSettings, override: profile.gesture)
            if needsActiveFilter(remap: r, scroll: s, gesture: g) {
                return true
            }
        }
        for dp in deviceProfiles {
            let r = resolvedRemap(global: remapSettings, override: dp.remap)
            let s = resolvedScroll(global: scrollSettings, override: dp.scroll)
            let g = resolvedGesture(global: gestureSettings, override: dp.gesture)
            if needsActiveFilter(remap: r, scroll: s, gesture: g) {
                return true
            }
        }
        return false
    }

    private func reconfigurePipeline() {
        if !enabled {
            eventTap.stop()
            scrollEngine.reset()
            gestureEngine.reset()
            if !isInternalDisable {
                statusMessage = nil
            }
            return
        }

        refreshPermissions()
        if !accessibilityTrusted {
            // Ask once and re-check immediately when user tries to enable.
            _ = permissionManager.isAccessibilityTrusted(prompt: true)
            refreshPermissions()
        }

        syncRuntimeSettings()
        let mode: EventTapManager.Mode = anyConfigNeedsActiveFilter() ? .activeFilter : .listenOnly
        eventTap.onTapReEnabled = { [weak self] in
            self?.gestureEngine.reset()
        }
        let started = eventTap.start(mode: mode) { [weak self] sample in
            self?.handleEvent(sample) ?? .passThrough
        }

        if started {
            // If tap starts successfully, treat accessibility as effectively granted
            // even when AX trust APIs transiently report false.
            if !accessibilityTrusted {
                accessibilityTrusted = true
            }
            statusMessage = nil
        } else {
            refreshPermissions()
            if !accessibilityTrusted {
                statusMessage = "Accessibility permission is required to enable MouseCraft."
            } else {
                statusMessage = "Event tap could not start. Verify Accessibility permission."
            }
            isInternalDisable = true
            enabled = false
            isInternalDisable = false
        }
    }

    /// Called from CGEventTap callback thread — not the main thread.
    /// Accesses only lock-protected runtime* properties and thread-safe engines.
    private func handleEvent(_ sample: MouseEventSample) -> EventProcessingDecision {
        if sample.isSynthetic {
            return .passThrough
        }

#if DEBUG
        incrementDebugCount(for: sample)
#endif

        let (remap, scroll, gesture) = runtimeSettingsSnapshot()

        // Gesture engine has priority: it suppresses buttonDown and may consume the full gesture.
        if gesture.enabled {
            let result = gestureEngine.handle(sample, settings: gesture)
            if result == .consumed {
                return .suppressOriginal
            }
            // .none → fall through to remap/scroll
        }

        var shouldSuppress = false

        if remap.enabled && remapEngine.handle(sample, settings: remap) {
            shouldSuppress = true
        }

        if scroll.enabled && scrollEngine.handle(sample, settings: scroll) {
            shouldSuppress = true
        }

        return shouldSuppress ? .suppressOriginal : .passThrough
    }

#if DEBUG
    private func incrementDebugCount(for sample: MouseEventSample) {
        let update: (inout DebugEventCounts) -> Void

        switch sample.type {
        case .otherMouseDown:
            update = { $0.otherMouseDown += 1 }
        case .otherMouseUp:
            update = { $0.otherMouseUp += 1 }
        case .otherMouseDragged:
            update = { $0.otherMouseDragged += 1 }
        case .scrollWheel:
            update = { $0.scrollWheel += 1 }
        default:
            return
        }

        if Thread.isMainThread {
            update(&debugEventCounts)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                update(&self.debugEventCounts)
            }
        }
    }
#endif
}
