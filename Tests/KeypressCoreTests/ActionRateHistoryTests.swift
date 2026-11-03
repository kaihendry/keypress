import Testing
@testable import KeypressCore

struct ActionRateHistoryTests {
    @Test func keepsLatestReadingInEachRecordedSecond() {
        var history = ActionRateHistory()
        history.startSegment(at: 0)
        history.record(apm: 5, elapsed: 0.2)
        history.record(apm: 8, elapsed: 0.9)
        history.record(apm: 12, elapsed: 1.1)
        #expect(history.samples.map(\.apm) == [8, 12])
        #expect(history.samples.map(\.elapsed) == [0.9, 1.1])
        #expect(Set(history.samples.map(\.id)).count == 2)
    }

    @Test func inactivityShowsRollingRateDecayingToZero() {
        var history = ActionRateHistory()
        var rate = ActionRate()
        history.startSegment(at: 0)
        rate.record(actions: 20, at: 0)
        for second in 0...61 {
            history.record(apm: rate.perMinute(at: Double(second)), elapsed: Double(second))
        }
        #expect(history.samples[59].apm == 20)
        #expect(history.samples[60].apm == 0)
        #expect(history.samples.last?.apm == 0)
    }

    @Test func pauseAndResumePreserveHistoryWithoutJoiningRuns() throws {
        var history = ActionRateHistory()
        var watch = Stopwatch()
        watch.start(at: 100)
        history.startSegment(at: watch.elapsed(at: 100))
        watch.stop(at: 110.5)
        history.record(apm: 30, elapsed: watch.elapsed(at: 110.5))
        let stopped = try #require(history.samples.last)
        watch.start(at: 1_000)
        history.startSegment(at: watch.elapsed(at: 1_000))
        history.record(apm: 2, elapsed: watch.elapsed(at: 1_000.2))
        #expect(history.samples.contains(stopped))
        let resumed = try #require(history.samples.last)
        #expect(resumed.segment != stopped.segment)
        #expect(abs(resumed.elapsed - 10.7) < 0.000001)
        #expect(resumed.apm == 2)
    }

    @Test func longSessionsRetainOnlyTheLatestTenMinutes() {
        var history = ActionRateHistory()
        for second in 0...7_200 { history.record(apm: second % 120, elapsed: Double(second)) }
        #expect(history.samples.count == 601)
        #expect(history.samples.first?.elapsed == 6_600)
        #expect(history.samples.last?.elapsed == 7_200)
        history.record(apm: 0, elapsed: 8_000)
        #expect(history.samples.count == 1)
    }

    @Test func rapidResumesCannotGrowHistoryWithoutBound() {
        var history = ActionRateHistory()
        for index in 0..<2_000 { history.startSegment(at: Double(index) / 100) }
        #expect(history.samples.count == ActionRateHistory.maximumSamples)
        #expect(Set(history.samples.map(\.id)).count == history.samples.count)
    }

    @Test func invalidAndOutOfOrderSamplesAreIgnored() {
        var history = ActionRateHistory()
        history.startSegment(at: 2)
        history.record(apm: 4, elapsed: 3)
        let samples = history.samples
        history.record(apm: -1, elapsed: 4)
        for time in [-1, 1, Double.nan, .infinity, Double(Int.max)] {
            history.record(apm: 10, elapsed: time)
            history.startSegment(at: time)
        }
        #expect(history.samples == samples)
        history = ActionRateHistory()
        #expect(history.samples.isEmpty)
    }
}
