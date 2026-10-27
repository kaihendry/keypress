import AppKit
import ApplicationServices

/// Samples geometry before the click, so opening a menu or dismissing a dialog cannot
/// accidentally measure the control underneath it. Missed/fast targets remain unmeasured.
final class TargetProbe {
    private struct Sample {
        let point: CGPoint
        let rect: CGRect
        let time: Double
        let frontmostPID: pid_t?
    }
    private let queue = DispatchQueue(label: "local.keypress.target", qos: .utility)
    private var sample: Sample?
    private var busy = false
    private var generation = UUID()

    func clear() { generation = UUID(); sample = nil }

    func target(at point: CGPoint, time: Double) -> CGRect? {
        guard let sample, time - sample.time <= 0.4,
              sample.frontmostPID == NSWorkspace.shared.frontmostApplication?.processIdentifier,
              hypot(point.x - sample.point.x, point.y - sample.point.y) <= 6,
              sample.rect.contains(point) else { return nil }
        return sample.rect
    }

    func refresh(at point: CGPoint, time: Double) {
        guard !busy else { return }
        busy = true
        let token = generation
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        queue.async { [weak self] in
            let rect = Self.lookup(at: point)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                guard self.generation == token else { return }
                self.sample = rect.map { Sample(point: point, rect: $0, time: time, frontmostPID: pid) }
            }
        }
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func lookup(at point: CGPoint) -> CGRect? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.025)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit) == .success,
              var element = hit else { return nil }
        // Broad text/canvas/window bounds do not describe the intended click target.
        let roles: Set<String> = ["AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton",
                                  "AXMenuButton", "AXMenuItem", "AXLink", "AXDisclosureTriangle",
                                  "AXTab", "AXSwitch"]
        for _ in 0..<6 {
            var pid: pid_t = 0
            guard AXUIElementGetPid(element, &pid) == .success, pid != getpid() else { return nil }
            if let role = attribute(kAXRoleAttribute, of: element) as? String, roles.contains(role),
               let position = attribute(kAXPositionAttribute, of: element),
               let size = attribute(kAXSizeAttribute, of: element),
               CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() {
                var origin = CGPoint.zero
                var dimensions = CGSize.zero
                if AXValueGetValue(position as! AXValue, .cgPoint, &origin),
                   AXValueGetValue(size as! AXValue, .cgSize, &dimensions) {
                    let rect = CGRect(origin: origin, size: dimensions)
                    if dimensions.width > 0, dimensions.height > 0, rect.contains(point) { return rect }
                }
            }
            guard let parent = attribute(kAXParentAttribute, of: element),
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
            element = parent as! AXUIElement
        }
        return nil
    }
}
