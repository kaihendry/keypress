import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = SessionModel()
    private var item: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.setAccessibilityLabel("Keypress actions per minute")
        }
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PanelView(model: model) { [weak self] in
            self?.toggle()
        })
        model.onChange = { [weak self] in self?.updateTitle() }
        model.excludePoint = { [weak self] point in self?.isOwnControl(point) ?? false }
        updateTitle()
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            popover.isShown ? popover.performClose(nil) : showDetails()
        } else {
            toggle()
        }
    }

    private func toggle() {
        model.toggle()
        if model.running { popover.performClose(nil) } else { showDetails() }
    }

    private func showDetails() {
        model.refreshPermissions()
        guard let button = item.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func updateTitle() {
        let title = model.running ? " \(model.recentAPM) APM" : " — APM"
        if item.button?.title != title { item.button?.title = title }
        item.button?.image = NSImage(systemSymbolName: model.running ? "stop.circle.fill" : "hand.tap",
                                    accessibilityDescription: model.running ? "Stop counting" : "Start counting")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = model.running
            ? "\(model.recentAPM) actions in the last minute. Click to stop; right-click for results."
            : "Counting stopped. Click to start; right-click for results."
    }

    private func isOwnControl(_ quartzPoint: CGPoint) -> Bool {
        // AX/CG use a top-left origin; AppKit uses a bottom-left origin on the primary screen.
        guard let primary = NSScreen.screens.first else { return false }
        let point = CGPoint(x: quartzPoint.x, y: primary.frame.maxY - quartzPoint.y)
        if let button = item.button, let window = button.window {
            if window.convertToScreen(button.convert(button.bounds, to: nil)).contains(point) { return true }
        }
        if popover.isShown, let window = popover.contentViewController?.view.window,
           window.frame.contains(point) { return true }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) { model.pause() }
}

// Cache the installed build's identity even if it is replaced while this process runs.
let buildInfo = BuildInfo.current
if CommandLine.arguments.dropFirst() == ["--version"] {
    print("Keypress \(buildInfo.version) (git \(buildInfo.revision))")
    exit(0)
}
if CommandLine.arguments.count > 1 {
    print("Usage: Keypress [--version | --help]\nLaunch without arguments for the menu bar stopwatch.")
    exit(CommandLine.arguments.dropFirst() == ["--help"] ? 0 : 1)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
