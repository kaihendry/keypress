import SwiftUI

struct PanelView: View {
    @ObservedObject var model: SessionModel
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Keypress", systemImage: "hand.tap")
                    .font(.headline)
                Spacer()
                Text(model.running ? "Counting" : "Stopped")
                    .font(.caption).foregroundStyle(model.running ? .green : .secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(model.clockText).font(.system(size: 34, weight: .light, design: .monospaced))
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(model.counts.total)").font(.title2.monospacedDigit())
                    Text("actions").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Button(model.running ? "Stop" : (model.elapsed > 0 ? "Resume" : "Start"), action: toggle)
                    .buttonStyle(.borderedProminent).tint(model.running ? .red : .accentColor)
                    .disabled(!model.ready)
                Button("Reset") { model.reset() }.disabled(model.running)
                Spacer()
                Button { model.copySummary() } label: { Image(systemName: "doc.on.doc") }
                    .help("Copy aggregate results")
            }
            Divider()
            VStack(spacing: 8) {
                row(model.running ? "APM · last minute" : "APM · at stop", "\(model.recentAPM)")
                    .help("Actions in the last 60 one-second buckets. The first minute fills naturally; resuming starts a fresh window.")
                row("APM · session average", model.averageAPMText)
                    .help("Total actions divided by recorded minutes. Paused time is excluded. Available after one recorded second.")
                row("Keyboard actions", "\(model.counts.keys)")
                row("Clicks / taps", "\(model.counts.clicks)")
                row("Scroll strokes / wheel bursts", "\(model.counts.scrolls)")
                row("Other gestures observed*", "\(model.counts.gestures)")
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Average pointing difficulty")
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .help("Estimated with Fitts’s law, in bits: log₂(1 + distance / target size). For one click, a distance of 1 target-width scores 1; 3 target-widths scores 2; 7 scores 3. Starting inside the target scores 0. This is an average of measured clicks, with no universal good/bad threshold.")
                        .accessibilityLabel("About pointing difficulty")
                    Spacer()
                    Text(model.counts.averageDifficulty.map {
                        String(format: "%.2f", $0)
                    } ?? "—").monospacedDigit()
                }.font(.callout)
                Text("Lower = easier targets")
                    .font(.caption)
                Text("\(model.counts.measuredClicks) of \(model.counts.clicks) click targets measured")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Nearby, larger targets score lower. Unmeasured clicks are excluded. This estimates pointing difficulty, not physical strain.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let notice = model.notice {
                Text(notice).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if !model.ready {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allow input counting and target-size measurement in System Settings.").font(.caption)
                    if !model.accessibilityAllowed {
                        Button("Enable Accessibility…") { model.requestAccessibility() }
                    }
                    if !model.inputAllowed {
                        Button("Enable Input Monitoring…") { model.requestInput() }
                    }
                    Text("If macOS requests it, quit and reopen Keypress after granting access.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("⌘C = 1 · Held-key repeats and scroll momentum excluded.\n*Other gestures depend on what macOS exposes; system gestures and raw finger contacts may be unavailable.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Counts only · cleared on quit")
                    Text(BuildInfo.current.label)
                        .textSelection(.enabled)
                        .help("Version of this running app. Updates take effect after you quit and reopen Keypress.")
                }
                .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.caption)
            }
        }
        .padding(18)
        .frame(width: 350)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.primary)
        }.font(.callout)
    }
}
