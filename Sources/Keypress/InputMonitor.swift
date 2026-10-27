import AppKit
import KeypressCore

final class InputMonitor {
    var onEvent: ((CGEventType, CGEvent) -> Void)?
    var onGesture: ((NSEvent) -> Void)?
    var onInterruption: (() -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var gestures: Any?

    func start() -> Bool {
        stop()
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
                                    .mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                    .otherMouseDragged, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<InputMonitor>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                // Stop visibly rather than silently report an incomplete session as complete.
                DispatchQueue.main.async { monitor.onInterruption?() }
            } else {
                monitor.onEvent?(type, event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: .listenOnly, eventsOfInterest: mask,
                                         callback: callback,
                                         userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        gestures = NSEvent.addGlobalMonitorForEvents(matching: [.swipe, .magnify, .rotate, .smartMagnify]) { [weak self] in
            self?.onGesture?($0)
        }
        return true
    }

    func stop() {
        if let gestures { NSEvent.removeMonitor(gestures) }
        gestures = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
    }

    static func phase(_ phase: NSEvent.Phase) -> Phase {
        if phase.contains(.cancelled) { return .cancelled }
        if phase.contains(.ended) { return .ended }
        if phase.contains(.began) { return .began }
        if phase.contains(.changed) { return .changed }
        if phase.contains(.mayBegin) { return .mayBegin }
        return .none
    }
}
