import Foundation
import CoreGraphics
import CoreVideo

final class ScrollEngine {
    // MARK: - Animation state (protected by stateLock)

    private let stateLock = NSLock()
    private var targetY: Double = 0
    private var currentY: Double = 0
    private var subPixelRemainder: Double = 0

    // MARK: - Display link

    private var displayLink: CVDisplayLink?
    private let displayLinkQueue = DispatchQueue(label: "mousecraft.scroll.displaylink", qos: .userInteractive)

    // MARK: - Settings snapshot (written from event tap, read from display link)

    private var lerpFactor: Double = 0.18
    private var speedMultiplier: Double = 1.0
    private var invertScroll: Bool = false

    deinit {
        stopDisplayLink()
    }

    // MARK: - Public API

    func reset() {
        stateLock.lock()
        targetY = 0
        currentY = 0
        subPixelRemainder = 0
        stateLock.unlock()
        stopDisplayLink()
    }

    /// Called from event tap callback. Returns true if the original event should be suppressed.
    @discardableResult
    func handle(_ sample: MouseEventSample, settings: ScrollSettings) -> Bool {
        guard settings.enabled else { return false }
        guard sample.type == .scrollWheel else { return false }
        guard sample.deltaY != 0 else { return false }

        if settings.smoothness == .off {
            return handlePassThrough(sample, settings: settings)
        }

        let normalizedSpeed = settings.speed.clamped(to: 0.5...3.0)
        let direction: Double = settings.invertMouseScroll ? -1.0 : 1.0
        let pixelDelta = Double(sample.deltaY) * normalizedSpeed * direction * pixelMultiplier(for: settings.smoothness)

        stateLock.lock()

        // Reset on direction reversal for instant response
        let directionChanged = (pixelDelta > 0 && targetY < currentY) || (pixelDelta < 0 && targetY > currentY)
        if directionChanged {
            targetY = currentY
            subPixelRemainder = 0
        }

        targetY += pixelDelta
        lerpFactor = lerpFactor(for: settings.smoothness)
        stateLock.unlock()

        ensureDisplayLinkRunning()
        return true
    }

    // MARK: - Smoothness parameters

    /// Pixels per line-delta. Converts discrete wheel ticks to pixel distance.
    /// macOS scrolls ~30px per line internally, so this matches Off mode's perceived speed.
    func pixelMultiplier(for smoothness: ScrollSmoothness) -> Double {
        switch smoothness {
        case .off: return 1.0
        case .regular: return 30.0
        case .high: return 30.0
        }
    }

    /// Lerp factor per frame. Lower = smoother but more latency.
    func lerpFactor(for smoothness: ScrollSmoothness) -> Double {
        switch smoothness {
        case .off: return 1.0
        case .regular: return 0.22
        case .high: return 0.12
        }
    }

    // MARK: - Pass-through mode (speed/invert only, no smoothing)

    private func handlePassThrough(_ sample: MouseEventSample, settings: ScrollSettings) -> Bool {
        let normalizedSpeed = settings.speed.clamped(to: 0.5...3.0)
        let noTransformNeeded = normalizedSpeed == 1.0 && !settings.invertMouseScroll
        guard !noTransformNeeded else { return false }

        let direction: Double = settings.invertMouseScroll ? -1.0 : 1.0
        let value = Double(sample.deltaY) * normalizedSpeed * direction
        let step = Int32(value.rounded())
        guard step != 0 else { return false }

        postLineEvent(step)
        return true
    }

    // MARK: - Display link management

    private func ensureDisplayLinkRunning() {
        displayLinkQueue.async { [weak self] in
            guard let self, self.displayLink == nil else { return }
            self.startDisplayLink()
        }
    }

    private func startDisplayLink() {
        var link: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&link) == kCVReturnSuccess,
              let link else { return }

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, context) -> CVReturn in
            guard let context else { return kCVReturnError }
            let engine = Unmanaged<ScrollEngine>.fromOpaque(context).takeUnretainedValue()
            engine.displayLinkFired()
            return kCVReturnSuccess
        }, selfPtr)

        CVDisplayLinkStart(link)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLinkQueue.async { [weak self] in
            guard let self, let link = self.displayLink else { return }
            CVDisplayLinkStop(link)
            self.displayLink = nil
        }
    }

    // MARK: - Frame callback (runs on CVDisplayLink thread at display refresh rate)

    private func displayLinkFired() {
        stateLock.lock()

        let remaining = targetY - currentY
        let step = remaining * lerpFactor

        currentY += step

        // Sub-pixel accumulation: accumulate fractional pixels, only post integer deltas
        subPixelRemainder += step
        let intDelta = Int32(subPixelRemainder.rounded(.towardZero))
        if intDelta != 0 {
            subPixelRemainder -= Double(intDelta)
        }

        let shouldStop = abs(remaining) < 0.1
        if shouldStop {
            currentY = targetY
            subPixelRemainder = 0
        }

        stateLock.unlock()

        if intDelta != 0 {
            postPixelEvent(intDelta)
        }

        if shouldStop {
            stopDisplayLink()
        }
    }

    // MARK: - Event posting

    private func postPixelEvent(_ delta: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: delta,
            wheel2: 0,
            wheel3: 0
        ) else {
            #if DEBUG
            print("[MouseCraft] ScrollEngine: Failed to create pixel scroll event (delta=\(delta))")
            #endif
            return
        }

        // Mark as continuous (trackpad-like) so macOS renders smoothly
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.eventSourceUserData, value: EventConstants.syntheticEventMarker)
        event.post(tap: .cghidEventTap)
    }

    private func postLineEvent(_ delta: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: delta,
            wheel2: 0,
            wheel3: 0
        ) else {
            #if DEBUG
            print("[MouseCraft] ScrollEngine: Failed to create line scroll event (delta=\(delta))")
            #endif
            return
        }

        event.setIntegerValueField(.eventSourceUserData, value: EventConstants.syntheticEventMarker)
        event.post(tap: .cghidEventTap)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
