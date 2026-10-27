import Foundation

/// Rolling APM using 60 one-second aggregate buckets, never individual input events.
/// The first minute fills naturally instead of extrapolating a brief initial burst.
public struct ActionRate {
    private struct Bucket {
        var second = -1
        var actions = 0
    }
    private var buckets = Array(repeating: Bucket(), count: 60)

    public init() {}

    public mutating func record(actions: Int, at time: Double) {
        guard actions > 0, let second = Self.second(at: time) else { return }
        let slot = second % buckets.count
        if buckets[slot].second != second { buckets[slot] = Bucket(second: second, actions: 0) }
        buckets[slot].actions += actions
    }

    public func perMinute(at time: Double) -> Int {
        guard let second = Self.second(at: time) else { return 0 }
        return buckets.reduce(0) { total, bucket in
            total + ((bucket.second > second - 60 && bucket.second <= second) ? bucket.actions : 0)
        }
    }

    private static func second(at time: Double) -> Int? {
        guard time.isFinite, time >= 0, time < Double(Int.max) else { return nil }
        return Int(time.rounded(.down))
    }
}
