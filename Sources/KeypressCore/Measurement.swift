import Foundation
import CoreGraphics

public enum Phase { case none, mayBegin, began, changed, ended, cancelled }
public enum Gesture: Hashable { case swipe, pinch, rotation, smartZoom }

/// Reduces an event stream to deliberate actions. Never accepts key codes or text.
public struct ActionCounter {
    public private(set) var keys = 0
    public private(set) var clicks = 0
    public private(set) var scrolls = 0
    public private(set) var gestures = 0
    public private(set) var measuredClicks = 0
    public private(set) var difficultyBits = 0.0
    public var total: Int { keys + clicks + scrolls + gestures }
    public var averageDifficulty: Double? {
        measuredClicks > 0 ? difficultyBits / Double(measuredClicks) : nil
    }

    private var trackpadScrollCounted = false
    private var lastTrackpadScroll: Double?
    private var lastWheelScroll: Double?
    private var gestureTimes: [Gesture: Double] = [:]

    public init() {}

    public mutating func key(isRepeat: Bool) {
        if !isRepeat { keys += 1 }
    }

    public mutating func click(difficulty: Double?) {
        clicks += 1
        if let difficulty, difficulty.isFinite, difficulty >= 0 {
            measuredClicks += 1
            difficultyBits += difficulty
        }
    }

    public mutating func scroll(at time: Double, phase: Phase, momentum: Bool, hasDelta: Bool) {
        guard !momentum else { return }
        if phase == .none {
            guard hasDelta else { return }
            // A conventional wheel has no finger-contact boundaries. Group its ticks into bursts.
            if lastWheelScroll.map({ time - $0 > 0.3 }) ?? true { scrolls += 1 }
            lastWheelScroll = time
            return
        }
        if phase == .began || phase == .mayBegin ||
            (lastTrackpadScroll.map({ time - $0 > 1.0 }) ?? true) {
            trackpadScrollCounted = false
        }
        lastTrackpadScroll = time
        if hasDelta && !trackpadScrollCounted && phase != .cancelled && phase != .mayBegin {
            scrolls += 1
            trackpadScrollCounted = true
        }
        if phase == .ended || phase == .cancelled { trackpadScrollCounted = false }
    }

    public mutating func gesture(_ kind: Gesture, at time: Double, phase: Phase) {
        if phase == .cancelled || phase == .ended {
            gestureTimes[kind] = nil
            return
        }
        guard phase != .mayBegin else { return }
        let discrete = kind == .smartZoom || (kind == .swipe && phase == .none)
        if discrete || phase == .began || (gestureTimes[kind].map({ time - $0 > 1.0 }) ?? true) {
            gestures += 1
        }
        gestureTimes[kind] = time
    }

    public mutating func breakSequences() {
        trackpadScrollCounted = false
        lastTrackpadScroll = nil
        lastWheelScroll = nil
        gestureTimes.removeAll()
    }
}

public enum Fitts {
    /// Shannon index; W is the chord through the target centre along the approach direction.
    /// This is a nominal geometric estimate, not calibrated throughput or a strain score.
    public static func difficulty(from start: CGPoint, target: CGRect) -> Double? {
        guard start.x.isFinite, start.y.isFinite,
              target.origin.x.isFinite, target.origin.y.isFinite,
              target.width.isFinite, target.height.isFinite,
              target.width > 0, target.height > 0 else { return nil }
        if target.contains(start) { return 0 }
        let dx = target.midX - start.x
        let dy = target.midY - start.y
        let distance = hypot(dx, dy)
        guard distance.isFinite, distance > 0 else { return nil }
        let widthX = dx == 0 ? Double.infinity : target.width * distance / abs(dx)
        let widthY = dy == 0 ? Double.infinity : target.height * distance / abs(dy)
        let width = min(widthX, widthY)
        guard width.isFinite, width > 0 else { return nil }
        return log2(1 + distance / width)
    }
}

/// A click destination is intentionally not kept as history: only the current movement origin.
public struct PointerMovement {
    public private(set) var origin: CGPoint?
    private var previous: CGPoint?
    private var lastMove: Double?

    public init(at point: CGPoint? = nil) { origin = point; previous = point }

    public mutating func move(to point: CGPoint, at time: Double) {
        if lastMove.map({ time - $0 > 0.3 }) ?? true { origin = previous ?? point }
        previous = point
        lastMove = time
    }

    public mutating func clicked(at point: CGPoint) {
        origin = point
        previous = point
        lastMove = nil
    }
}

public struct Stopwatch {
    private var accumulated = 0.0
    private var started: Double?
    public var isRunning: Bool { started != nil }
    public init() {}
    public mutating func start(at time: Double) { if started == nil { started = time } }
    public mutating func stop(at time: Double) {
        if let started { accumulated += max(0, time - started) }
        started = nil
    }
    public func elapsed(at time: Double) -> Double {
        accumulated + (started.map { max(0, time - $0) } ?? 0)
    }
}
