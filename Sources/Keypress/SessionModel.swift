import AppKit
import ApplicationServices
import Carbon
import KeypressCore

final class SessionModel: ObservableObject {
    @Published private(set) var counts = ActionCounter()
    @Published private(set) var running = false
    @Published private(set) var elapsed = 0.0
    @Published private(set) var recentAPM = 0
    @Published private(set) var accessibilityAllowed = AXIsProcessTrusted()
    @Published private(set) var inputAllowed = CGPreflightListenEventAccess()
    @Published private(set) var notice: String?
    var excludePoint: ((CGPoint) -> Bool)?
    var onChange: (() -> Void)?

    private let monitor = InputMonitor()
    private let probe = TargetProbe()
    private var stopwatch = Stopwatch()
    private var actionRate = ActionRate()
    private var movement = PointerMovement()
    private var timer: Timer?
    private var lastPermissionCheck = 0.0
    private var observers: [NSObjectProtocol] = []
    private var now: Double { ProcessInfo.processInfo.systemUptime }

    var ready: Bool { accessibilityAllowed && inputAllowed }
    var averageAPMText: String {
        elapsed >= 1 ? String(format: "%.1f", Double(counts.total) * 60 / elapsed) : "—"
    }
    var clockText: String {
        let seconds = Int(elapsed)
        return seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    init() {
        monitor.onEvent = { [weak self] type, event in self?.receive(type, event) }
        monitor.onGesture = { [weak self] event in self?.receiveGesture(event) }
        monitor.onInterruption = { [weak self] in
            self?.pause()
            self?.notice = "Input monitoring was interrupted. Resume to reconnect."
        }
        timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
        for notification in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: notification, object: nil, queue: .main
            ) { [weak self] _ in
                guard let self, self.running else { return }
                self.pause()
                self.notice = "Paused when your Mac slept or the session became inactive."
            })
        }
    }

    func refreshPermissions() {
        accessibilityAllowed = AXIsProcessTrusted()
        inputAllowed = CGPreflightListenEventAccess()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openSettings("Privacy_Accessibility")
    }

    func requestInput() {
        _ = CGRequestListenEventAccess()
        openSettings("Privacy_ListenEvent")
    }

    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    func toggle() { running ? pause() : resume() }

    func resume() {
        refreshPermissions()
        guard ready else { notice = "Enable both permissions below, then start."; return }
        guard !IsSecureEventInputEnabled() else {
            notice = "Secure keyboard input is active. Leave the password field or disable Secure Keyboard Entry, then resume."
            return
        }
        guard monitor.start() else {
            notice = "Could not start input monitoring. Check permissions, then quit and reopen Keypress."
            return
        }
        probe.clear()
        movement = PointerMovement(at: CGEvent(source: nil)?.location)
        counts.breakSequences()
        actionRate = ActionRate()
        recentAPM = 0
        stopwatch.start(at: now)
        running = true
        notice = nil
        onChange?()
    }

    func pause() {
        let time = now
        if running { recentAPM = actionRate.perMinute(at: time) }
        stopwatch.stop(at: time)
        elapsed = stopwatch.elapsed(at: time)
        running = false
        monitor.stop()
        probe.clear()
        onChange?()
    }

    func reset() {
        pause()
        stopwatch = Stopwatch()
        counts = ActionCounter()
        actionRate = ActionRate()
        recentAPM = 0
        elapsed = 0
        notice = nil
        onChange?()
    }

    private func tick() {
        let time = now
        if time - lastPermissionCheck >= 1 {
            refreshPermissions()
            lastPermissionCheck = time
            if running && !ready {
                pause()
                notice = "Paused because a required permission was removed."
            }
        }
        guard running else { return }
        if IsSecureEventInputEnabled() {
            pause()
            notice = "Paused for secure keyboard input. Resume after leaving the password field."
            return
        }
        elapsed = stopwatch.elapsed(at: time)
        recentAPM = actionRate.perMinute(at: time)
        if let point = CGEvent(source: nil)?.location, excludePoint?(point) != true {
            probe.refresh(at: point, time: time)
        }
        onChange?()
    }

    private func receive(_ type: CGEventType, _ event: CGEvent) {
        guard running else { return }
        let point = event.location
        let time = now
        let previousTotal = counts.total
        switch type {
        case .keyDown:
            guard !NSApp.isActive else { return }
            counts.key(isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            guard excludePoint?(point) != true else { return }
            let difficulty = movement.origin.flatMap { start in
                probe.target(at: point, time: time).flatMap { Fitts.difficulty(from: start, target: $0) }
            }
            counts.click(difficulty: difficulty)
            movement.clicked(at: point)
            probe.clear()
        case .mouseMoved:
            movement.move(to: point, at: time)
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            // The next pointing action starts at the drag destination.
            movement.clicked(at: point)
        case .scrollWheel:
            guard excludePoint?(point) != true, let converted = NSEvent(cgEvent: event) else { return }
            counts.scroll(at: time, phase: InputMonitor.phase(converted.phase),
                          momentum: !converted.momentumPhase.isEmpty,
                          hasDelta: converted.scrollingDeltaX != 0 || converted.scrollingDeltaY != 0)
            probe.clear()
        default: break
        }
        recordActions(counts.total - previousTotal, at: time)
    }

    private func receiveGesture(_ event: NSEvent) {
        guard running else { return }
        let kind: Gesture
        switch event.type {
        case .swipe: kind = .swipe
        case .magnify: kind = .pinch
        case .rotate: kind = .rotation
        case .smartMagnify: kind = .smartZoom
        default: return
        }
        let time = now
        let previousTotal = counts.total
        counts.gesture(kind, at: time, phase: InputMonitor.phase(event.phase))
        recordActions(counts.total - previousTotal, at: time)
        probe.clear()
    }

    private func recordActions(_ actions: Int, at time: Double) {
        guard actions > 0 else { return }
        actionRate.record(actions: actions, at: time)
        recentAPM = actionRate.perMinute(at: time)
        onChange?()
    }

    func copySummary() {
        let average = counts.averageDifficulty.map { String(format: "%.2f bits", $0) } ?? "unavailable"
        let text = """
        Keypress — \(clockText)
        Actions: \(counts.total)
        Recent APM (last minute\(running ? "" : " at stop")): \(recentAPM)
        Session average APM (excluding pauses): \(averageAPMText)
        Keyboard actions: \(counts.keys)
        Clicks / taps: \(counts.clicks)
        Scroll strokes / wheel bursts: \(counts.scrolls)
        Other gestures observed (partial coverage): \(counts.gestures)
        Average pointing difficulty: \(average) (Fitts’s law; lower = easier targets)
        Measurable click targets: \(counts.measuredClicks) / \(counts.clicks)
        Pointing difficulty is an estimate, not a strain score.
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
