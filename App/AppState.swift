import Foundation
import Combine

/// Determines whether the event tap must run in active-filter mode
/// (i.e. it needs to suppress/transform events) vs listen-only.
func needsActiveFilter(remap: RemapSettings, scroll: ScrollSettings) -> Bool {
    if remap.enabled {
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

    return scroll.invertMouseScroll
}

#if DEBUG
struct DebugEventCounts {
    var otherMouseDown: Int = 0
    var otherMouseUp: Int = 0
    var scrollWheel: Int = 0

    var total: Int {
        otherMouseDown + otherMouseUp + scrollWheel
    }
}
#endif

final class AppState: ObservableObject {
    @Published var enabled: Bool = false {
        didSet {
            guard !isBootstrapping else { return }
            persistGeneralSettings()
            schedulePipelineReconfigure()
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

    @Published var profiles: [AppProfile] = []

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

    private let runtimeLock = NSLock()
    private var runtimeRemapSettings: RemapSettings = .default
    private var runtimeScrollSettings: ScrollSettings = .default
    private var runtimeProfiles: [String: AppProfile] = [:]

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
        profiles = settingsStore.loadProfiles()

        runtimeRemapSettings = remapSettings
        runtimeScrollSettings = scrollSettings
        runtimeProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.bundleIdentifier, $0) })

        isBootstrapping = false
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
        runtimeProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.bundleIdentifier, $0) })
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

    private func runtimeSettingsSnapshot() -> (RemapSettings, ScrollSettings) {
        runtimeLock.lock()
        let globalRemap = runtimeRemapSettings
        let globalScroll = runtimeScrollSettings
        let profilesMap = runtimeProfiles
        runtimeLock.unlock()

        let bundleID = frontmostAppTracker.currentBundleID
        let profile = bundleID.flatMap { profilesMap[$0] }

        return (
            resolvedRemap(global: globalRemap, override: profile?.remap),
            resolvedScroll(global: globalScroll, override: profile?.scroll)
        )
    }

    private func anyConfigNeedsActiveFilter() -> Bool {
        if needsActiveFilter(remap: remapSettings, scroll: scrollSettings) {
            return true
        }
        for profile in profiles {
            let r = resolvedRemap(global: remapSettings, override: profile.remap)
            let s = resolvedScroll(global: scrollSettings, override: profile.scroll)
            if needsActiveFilter(remap: r, scroll: s) {
                return true
            }
        }
        return false
    }

    private func reconfigurePipeline() {
        if !enabled {
            eventTap.stop()
            scrollEngine.reset()
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

    private func handleEvent(_ sample: MouseEventSample) -> EventProcessingDecision {
        if sample.isSynthetic {
            return .passThrough
        }

#if DEBUG
        incrementDebugCount(for: sample)
#endif

        let (remap, scroll) = runtimeSettingsSnapshot()

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
