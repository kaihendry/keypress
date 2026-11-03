import Charts
import KeypressCore
import SwiftUI

struct APMChartView: View {
    let history: ActionRateHistory
    let elapsed: Double

    private var timeRange: ClosedRange<Double> {
        max(0, elapsed - ActionRateHistory.windowDuration)...max(60, elapsed)
    }

    private var segmentEnds: [ActionRateHistory.Sample] {
        history.samples.enumerated().compactMap { index, sample in
            index == history.samples.count - 1 || history.samples[index + 1].segment != sample.segment
                ? sample : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("APM over time").font(.callout.weight(.medium))
            Chart {
                ForEach(history.samples) { sample in
                    LineMark(
                        x: .value("Recorded time", sample.elapsed),
                        y: .value("APM", sample.apm),
                        series: .value("Run", sample.segment)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                // Also keep very short runs (a single sample) visible after resuming.
                ForEach(segmentEnds) { sample in
                    PointMark(x: .value("Recorded time", sample.elapsed), y: .value("APM", sample.apm))
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(24)
                }
            }
            .chartXScale(domain: timeRange)
            .chartYScale(domain: 0...max(10, history.samples.map(\.apm).max() ?? 0))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(Self.timeLabel(seconds)).monospacedDigit()
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .chartLegend(.hidden)
            .frame(height: 120)
            .overlay {
                if history.samples.isEmpty {
                    Text("Start counting to see your activity")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .accessibilityLabel("Actions per minute over recorded time")
            Text("Latest 10 min · recorded time (pauses excluded)")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .help("The same rolling APM as the menu bar, sampled each second. Stops preserve the chart; resuming starts a new line. Reset clears it.")
    }

    private static func timeLabel(_ time: Double) -> String {
        let seconds = Int(time)
        return seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
