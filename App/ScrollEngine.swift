import Foundation
import CoreGraphics
import CoreVideo

final class ScrollEngine {
    // MARK: - Per-axis state

    private struct AxisState {
        var target: Double = 0
        var current: Double = 0
        var subPixelRemainder: Double = 0
        var velocity: Double = 0
    }

    // MARK: - Animation state (protected by stateLock)

    private let stateLock = NSLock()
    private var yAxis = AxisState()
    private var xAxis = AxisState()

    // MARK: - Momentum state (protected by stateLock)

    private var lastInputTime: UInt64 = 0
    private var inMomentumPhase: Bool = false
    private var lastFrameTime: UInt64 = 0
    private var cachedSmoothness: ScrollSmoothness = .regular
    private var cachedMomentum: Double = 0.5

    // MARK: - Settings snapshot (written from event tap, read from display link)

    private var lerpFactor: Double = 0.18

    // MARK: - Display link

    private var displayLink: CVDisplayLink?
    private let displayLinkQueue = DispatchQueue(label: "mousecraft.scroll.displaylink", qos: .userInteractive)

    // MARK: - Momentum constants

    private static let momentumIdleThreshold: Double = 0.08
    private static let momentumStopThreshold: Double = 5.0
    private static let maxVelocity: Double = 3000.0

    // MARK: - Acceleration curve constants

    private static let accelReferenceVelocity: Double = 600.0
    private static let accelExponent: Double = 1.5
    private static let accelMaxGain: Double = 2.5
    private static let frictionMin: Double = 1.5
    private static let frictionMax: Double = 12.0

    // MARK: - Time conversion

    private static let machTimebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private static func machTimeToSeconds(_ time: UInt64) -> Double {
        let nanos = Double(time) * Double(machTimebaseInfo.numer) / Double(machTimebaseInfo.denom)
        return nanos / 1_000_000_000.0
    }

    deinit {
        // Stop synchronously: CVDisplayLinkStop blocks until the current
        // callback completes, preventing use-after-free on the
        // passUnretained self pointer used in the callback context.
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
    }

    // MARK: - Public API

    func reset() {
        stateLock.lock()
        yAxis = AxisState()
        xAxis = AxisState()
        lastInputTime = 0
        inMomentumPhase = false
        lastFrameTime = 0
        cachedMomentum = 0.5
        stateLock.unlock()
        stopDisplayLink()
    }

    /// Called from event tap callback. Returns true if the original event should be suppressed.
    @discardableResult
    func handle(_ sample: MouseEventSample, settings: ScrollSettings) -> Bool {
        guard settings.enabled else { return false }
        guard sample.type == .scrollWheel else { return false }
        guard sample.deltaY != 0 || sample.deltaX != 0 else { return false }

        if settings.smoothness == .off {
            return handlePassThrough(sample, settings: settings)
        }

        let normalizedSpeed = settings.speed.clamped(to: 0.5...3.0)
        let vertDirection: Double = settings.invertMouseScroll ? -1.0 : 1.0
        let horizDirection: Double = settings.invertHorizontalScroll ? -1.0 : 1.0
        let pxMul = pixelMultiplier(for: settings.smoothness)

        var yPixelDelta: Double = 0
        var xPixelDelta: Double = 0

        stateLock.lock()

        // Process Y axis
        if sample.deltaY != 0 {
            let baseDelta = Double(sample.deltaY) * normalizedSpeed * vertDirection * pxMul
            yPixelDelta = acceleratedDelta(baseDelta, velocity: yAxis.velocity, strength: settings.acceleration)

            let dirChanged = (yPixelDelta > 0 && yAxis.target < yAxis.current) || (yPixelDelta < 0 && yAxis.target > yAxis.current)
            if dirChanged {
                yAxis.target = yAxis.current
                yAxis.subPixelRemainder = 0
                yAxis.velocity = 0
                inMomentumPhase = false
            }

            yAxis.target += yPixelDelta
        }

        // Process X axis
        if sample.deltaX != 0 {
            let baseDelta = Double(sample.deltaX) * normalizedSpeed * horizDirection * pxMul
            xPixelDelta = acceleratedDelta(baseDelta, velocity: xAxis.velocity, strength: settings.acceleration)

            let dirChanged = (xPixelDelta > 0 && xAxis.target < xAxis.current) || (xPixelDelta < 0 && xAxis.target > xAxis.current)
            if dirChanged {
                xAxis.target = xAxis.current
                xAxis.subPixelRemainder = 0
                xAxis.velocity = 0
                inMomentumPhase = false
            }

            xAxis.target += xPixelDelta
        }

        lerpFactor = lerpFactor(for: settings.smoothness)
        cachedSmoothness = settings.smoothness
        cachedMomentum = settings.momentum

        // Velocity tracking via EMA for momentum
        let now = mach_absolute_time()
        if lastInputTime != 0 {
            let dtInput = Self.machTimeToSeconds(now - lastInputTime)
            if dtInput > 0 && dtInput < 0.5 {
                if sample.deltaY != 0 {
                    let instantVelocity = yPixelDelta / dtInput
                    let raw = yAxis.velocity * 0.7 + instantVelocity * 0.3
                    yAxis.velocity = raw.clamped(to: -Self.maxVelocity...Self.maxVelocity)
                }
                if sample.deltaX != 0 {
                    let instantVelocity = xPixelDelta / dtInput
                    let raw = xAxis.velocity * 0.7 + instantVelocity * 0.3
                    xAxis.velocity = raw.clamped(to: -Self.maxVelocity...Self.maxVelocity)
                }
            }
        }
        lastInputTime = now
        inMomentumPhase = false

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

    /// Lerp factor per frame (at 60 Hz baseline). Lower = smoother but more latency.
    func lerpFactor(for smoothness: ScrollSmoothness) -> Double {
        switch smoothness {
        case .off: return 1.0
        case .regular: return 0.22
        case .high: return 0.12
        }
    }

    /// Friction coefficient for momentum decay. Higher = more friction = shorter coast.
    func frictionCoefficient(for smoothness: ScrollSmoothness) -> Double {
        switch smoothness {
        case .off: return 0
        case .regular: return 6.0
        case .high: return 3.5
        }
    }

    /// Non-linear acceleration: slow scrolls stay precise, fast flicks go farther.
    /// Uses previous velocity EMA to avoid feedback loops.
    private func acceleratedDelta(_ rawDelta: Double, velocity: Double, strength: Double) -> Double {
        guard strength > 0.001 else { return rawDelta }
        let normalizedVelocity = abs(velocity) / Self.accelReferenceVelocity
        let curveGain = min(pow(normalizedVelocity, Self.accelExponent), Self.accelMaxGain)
        return rawDelta * (1.0 + strength * curveGain)
    }

    /// Maps user momentum setting (0–1) to friction coefficient via log interpolation.
    /// momentum=0 → high friction (short coast), momentum=1 → low friction (long coast).
    func effectiveFriction(smoothness: ScrollSmoothness, momentum: Double) -> Double {
        guard smoothness != .off else { return 0 }
        let clamped = momentum.clamped(to: 0.0...1.0)
        let logMin = log(Self.frictionMin)
        let logMax = log(Self.frictionMax)
        let logFriction = logMax - clamped * (logMax - logMin)
        return exp(logFriction)
    }

    // MARK: - Pass-through mode (speed/invert only, no smoothing)

    private func handlePassThrough(_ sample: MouseEventSample, settings: ScrollSettings) -> Bool {
        let normalizedSpeed = settings.speed.clamped(to: 0.5...3.0)
        let noTransformNeeded = normalizedSpeed == 1.0 && !settings.invertMouseScroll && !settings.invertHorizontalScroll
        guard !noTransformNeeded else { return false }

        let vertDirection: Double = settings.invertMouseScroll ? -1.0 : 1.0
        let horizDirection: Double = settings.invertHorizontalScroll ? -1.0 : 1.0

        let vertStep = Int32((Double(sample.deltaY) * normalizedSpeed * vertDirection).rounded())
        let horizStep = Int32((Double(sample.deltaX) * normalizedSpeed * horizDirection).rounded())
        guard vertStep != 0 || horizStep != 0 else { return false }

        postLineEvent(vertical: vertStep, horizontal: horizStep)
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

        // Compute deltaTime
        let nowMach = mach_absolute_time()
        var dt: Double = 1.0 / 60.0
        if lastFrameTime != 0 {
            dt = Self.machTimeToSeconds(nowMach - lastFrameTime)
            dt = min(dt, 0.05)
        }
        lastFrameTime = nowMach

        // Check for momentum phase entry
        if !inMomentumPhase && lastInputTime != 0 && cachedSmoothness != .off {
            let timeSinceLastInput = Self.machTimeToSeconds(nowMach - lastInputTime)
            let hasVelocity = abs(yAxis.velocity) > Self.momentumStopThreshold || abs(xAxis.velocity) > Self.momentumStopThreshold
            if timeSinceLastInput > Self.momentumIdleThreshold && hasVelocity {
                inMomentumPhase = true
            }
        }

        // Advance targets if in momentum phase
        if inMomentumPhase {
            let friction = effectiveFriction(smoothness: cachedSmoothness, momentum: cachedMomentum)
            let decayFactor = exp(-friction * dt)

            yAxis.velocity *= decayFactor
            xAxis.velocity *= decayFactor

            let yDead = abs(yAxis.velocity) < Self.momentumStopThreshold
            let xDead = abs(xAxis.velocity) < Self.momentumStopThreshold

            if yDead { yAxis.velocity = 0 }
            if xDead { xAxis.velocity = 0 }

            if yDead && xDead {
                inMomentumPhase = false
            } else {
                if !yDead { yAxis.target += yAxis.velocity * dt }
                if !xDead { xAxis.target += xAxis.velocity * dt }
            }
        }

        // Frame-rate independent lerp: at 60fps dt*60=1.0 so factor==lerpFactor
        let factor = 1.0 - pow(1.0 - lerpFactor, dt * 60.0)

        // Y axis lerp + sub-pixel accumulation
        let yRemaining = yAxis.target - yAxis.current
        let yStep = yRemaining * factor
        yAxis.current += yStep
        yAxis.subPixelRemainder += yStep
        let yIntDelta = Int32(yAxis.subPixelRemainder.rounded(.towardZero))
        if yIntDelta != 0 {
            yAxis.subPixelRemainder -= Double(yIntDelta)
        }

        // X axis lerp + sub-pixel accumulation
        let xRemaining = xAxis.target - xAxis.current
        let xStep = xRemaining * factor
        xAxis.current += xStep
        xAxis.subPixelRemainder += xStep
        let xIntDelta = Int32(xAxis.subPixelRemainder.rounded(.towardZero))
        if xIntDelta != 0 {
            xAxis.subPixelRemainder -= Double(xIntDelta)
        }

        // Stop only when momentum is done AND both axes have converged
        let shouldStop = !inMomentumPhase && abs(yRemaining) < 0.1 && abs(xRemaining) < 0.1
        if shouldStop {
            yAxis.current = yAxis.target
            yAxis.subPixelRemainder = 0
            xAxis.current = xAxis.target
            xAxis.subPixelRemainder = 0
            lastFrameTime = 0
        }

        stateLock.unlock()

        if yIntDelta != 0 || xIntDelta != 0 {
            postPixelEvent(vertical: yIntDelta, horizontal: xIntDelta)
        }

        if shouldStop {
            stopDisplayLink()
        }
    }

    // MARK: - Event posting

    private func postPixelEvent(vertical: Int32, horizontal: Int32) {
        let wheelCount: UInt32 = horizontal != 0 ? 2 : 1
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: wheelCount,
            wheel1: vertical,
            wheel2: horizontal,
            wheel3: 0
        ) else {
            #if DEBUG
            print("[MouseCraft] ScrollEngine: Failed to create pixel scroll event (v=\(vertical), h=\(horizontal))")
            #endif
            return
        }

        // Mark as continuous (trackpad-like) so macOS renders smoothly
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.eventSourceUserData, value: EventConstants.syntheticEventMarker)
        event.post(tap: .cghidEventTap)
    }

    private func postLineEvent(vertical: Int32, horizontal: Int32) {
        let wheelCount: UInt32 = horizontal != 0 ? 2 : 1
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: wheelCount,
            wheel1: vertical,
            wheel2: horizontal,
            wheel3: 0
        ) else {
            #if DEBUG
            print("[MouseCraft] ScrollEngine: Failed to create line scroll event (v=\(vertical), h=\(horizontal))")
            #endif
            return
        }

        event.setIntegerValueField(.eventSourceUserData, value: EventConstants.syntheticEventMarker)
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Test-only inspection

    #if DEBUG
    var _testVelocity: Double {
        stateLock.lock()
        defer { stateLock.unlock() }
        return yAxis.velocity
    }

    var _testInMomentumPhase: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return inMomentumPhase
    }
    #endif
}
