import Foundation

/// In-memory, per-second aggregate APM readings. Paused time is excluded by the caller.
public struct ActionRateHistory {
    public struct Sample: Identifiable, Equatable {
        public let id: Int
        public let elapsed: Double
        public let apm: Int
        public let segment: Int
    }

    public static let windowDuration = 600.0
    public static let maximumSamples = 601
    public private(set) var samples: [Sample] = []
    private var segment = 0
    private var nextID = 0

    public init() {}

    /// A fresh rolling-rate window must not be joined to the preceding run's line.
    public mutating func startSegment(at elapsed: Double) {
        guard isValid(elapsed) else { return }
        segment += 1
        record(apm: 0, elapsed: elapsed)
    }

    public mutating func record(apm: Int, elapsed: Double) {
        guard apm >= 0, isValid(elapsed) else { return }
        if let last = samples.last, last.segment == segment, Int(last.elapsed) == Int(elapsed) {
            samples[samples.count - 1] = Sample(id: last.id, elapsed: elapsed, apm: apm, segment: segment)
        } else {
            samples.append(Sample(id: nextID, elapsed: elapsed, apm: apm, segment: segment))
            nextID += 1
        }
        samples.removeAll { $0.elapsed < elapsed - Self.windowDuration }
        if samples.count > Self.maximumSamples {
            samples.removeFirst(samples.count - Self.maximumSamples)
        }
    }

    private func isValid(_ elapsed: Double) -> Bool {
        elapsed.isFinite && elapsed >= 0 && elapsed < Double(Int.max)
            && elapsed >= (samples.last?.elapsed ?? 0)
    }
}
