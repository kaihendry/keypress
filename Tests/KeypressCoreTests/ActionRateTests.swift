import Testing
@testable import KeypressCore

struct ActionRateTests {
    @Test func initialBurstIsNotExtrapolated() {
        var rate = ActionRate()
        rate.record(actions: 10, at: 0.1)
        #expect(rate.perMinute(at: 0.1) == 10)
        rate.record(actions: 5, at: 0.9)
        #expect(rate.perMinute(at: 0.9) == 15)
    }

    @Test func windowExpiresWithoutNewInput() {
        var rate = ActionRate()
        rate.record(actions: 10, at: 0.2)
        rate.record(actions: 20, at: 1.2)
        #expect(rate.perMinute(at: 59.9) == 30)
        #expect(rate.perMinute(at: 60) == 20)
        #expect(rate.perMinute(at: 61) == 0)
        #expect(rate.perMinute(at: 3_600) == 0)
    }

    @Test func reusedBucketDoesNotCarryOldActions() {
        var rate = ActionRate()
        rate.record(actions: 50, at: 4)
        rate.record(actions: 7, at: 64)
        #expect(rate.perMinute(at: 64) == 7)
        rate.record(actions: 3, at: 184)
        #expect(rate.perMinute(at: 184) == 3)
    }

    @Test func steadyTwoActionsPerSecondGives120APM() {
        var rate = ActionRate()
        for second in 0..<120 { rate.record(actions: 2, at: Double(second)) }
        #expect(rate.perMinute(at: 119) == 120)
        #expect(rate.perMinute(at: 149) == 60)
        #expect(rate.perMinute(at: 179) == 0)
    }

    @Test func onlyAcceptedActionsContribute() {
        var counts = ActionCounter()
        var rate = ActionRate()
        counts.key(isRepeat: false) // A shortcut contributes one.
        counts.key(isRepeat: true)
        counts.click(difficulty: nil)
        counts.scroll(at: 0, phase: .began, momentum: false, hasDelta: true)
        counts.scroll(at: 0.1, phase: .changed, momentum: false, hasDelta: true)
        counts.scroll(at: 0.2, phase: .none, momentum: true, hasDelta: true)
        counts.gesture(.pinch, at: 0.3, phase: .began)
        counts.gesture(.pinch, at: 0.4, phase: .changed)
        rate.record(actions: counts.total, at: 0.4)
        #expect(rate.perMinute(at: 0.4) == 4)
    }

    @Test func invalidSamplesAreIgnored() {
        var rate = ActionRate()
        rate.record(actions: 0, at: 1)
        rate.record(actions: -1, at: 1)
        rate.record(actions: 2, at: -.infinity)
        rate.record(actions: 2, at: .nan)
        rate.record(actions: 2, at: -1)
        #expect(rate.perMinute(at: 1) == 0)
        #expect(rate.perMinute(at: .infinity) == 0)
    }
}
