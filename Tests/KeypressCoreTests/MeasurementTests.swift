import Testing
import Foundation
import CoreGraphics
@testable import KeypressCore

struct MeasurementTests {
    @Test func shortcutAndHeldKeyAreEachOneAction() {
        var counter = ActionCounter()
        // Modifier changes are never fed to the reducer. Command-C produces one keyDown.
        counter.key(isRepeat: false)
        for _ in 0..<20 { counter.key(isRepeat: true) }
        #expect(counter.keys == 1)
        counter.key(isRepeat: false)
        #expect(counter.keys == 2)
    }

    @Test func trackpadStrokeWithMomentumAndNextStroke() {
        var counter = ActionCounter()
        counter.scroll(at: 0, phase: .mayBegin, momentum: false, hasDelta: false)
        counter.scroll(at: 0.01, phase: .began, momentum: false, hasDelta: false)
        for tick in 1...10 {
            counter.scroll(at: Double(tick) / 10, phase: .changed, momentum: false, hasDelta: true)
        }
        counter.scroll(at: 1.1, phase: .ended, momentum: false, hasDelta: false)
        for tick in 12...20 {
            counter.scroll(at: Double(tick) / 10, phase: .none, momentum: true, hasDelta: true)
        }
        #expect(counter.scrolls == 1)
        counter.scroll(at: 2.1, phase: .began, momentum: false, hasDelta: true)
        #expect(counter.scrolls == 2)
    }

    @Test func wheelBurstsAndDeviceSwitch() {
        var counter = ActionCounter()
        for time in [0.0, 0.05, 0.1, 0.2, 0.49] {
            counter.scroll(at: time, phase: .none, momentum: false, hasDelta: true)
        }
        #expect(counter.scrolls == 1)
        counter.scroll(at: 1, phase: .none, momentum: false, hasDelta: true)
        counter.scroll(at: 1.1, phase: .began, momentum: false, hasDelta: true)
        #expect(counter.scrolls == 3)
    }

    @Test func emptyAndCancelledScrollDoNotCount() {
        var counter = ActionCounter()
        counter.scroll(at: 0, phase: .mayBegin, momentum: false, hasDelta: false)
        counter.scroll(at: 0.1, phase: .cancelled, momentum: false, hasDelta: false)
        counter.scroll(at: 0.2, phase: .none, momentum: false, hasDelta: false)
        #expect(counter.total == 0)
    }

    @Test func gestureSequencesAndDiscreteSwipes() {
        var counter = ActionCounter()
        counter.gesture(.pinch, at: 0, phase: .began)
        counter.gesture(.pinch, at: 0.1, phase: .changed)
        counter.gesture(.pinch, at: 0.2, phase: .ended)
        counter.gesture(.pinch, at: 0.3, phase: .began)
        counter.gesture(.pinch, at: 0.4, phase: .ended)
        counter.gesture(.swipe, at: 0.5, phase: .none)
        counter.gesture(.swipe, at: 0.6, phase: .none)
        #expect(counter.gestures == 4)
    }

    @Test func resumeBreaksInputSequencesWithoutLosingTotals() {
        var counter = ActionCounter()
        counter.scroll(at: 0, phase: .none, momentum: false, hasDelta: true)
        counter.breakSequences()
        counter.scroll(at: 0.1, phase: .none, momentum: false, hasDelta: true)
        #expect(counter.scrolls == 2)
    }

    @Test func unknownTargetsAreExcludedFromFittsAverage() {
        var counter = ActionCounter()
        counter.click(difficulty: 2)
        counter.click(difficulty: nil)
        counter.click(difficulty: .nan)
        counter.click(difficulty: -1)
        counter.click(difficulty: 4)
        #expect(counter.clicks == 5)
        #expect(counter.measuredClicks == 2)
        #expect(counter.averageDifficulty == 3)
    }

    @Test func fittsHorizontalAndVerticalApproach() throws {
        let target = CGRect(x: 90, y: 95, width: 20, height: 10)
        let horizontal = try #require(Fitts.difficulty(from: CGPoint(x: 0, y: 100), target: target))
        let vertical = try #require(Fitts.difficulty(from: CGPoint(x: 100, y: 0), target: target))
        #expect(abs(horizontal - log2(6)) < 0.000001)
        #expect(abs(vertical - log2(11)) < 0.000001)
        #expect(vertical > horizontal)
    }

    @Test func fittsDiagonalAndDisplayScaling() throws {
        let start = CGPoint(x: -100, y: -100)
        let target = CGRect(x: -10, y: -10, width: 20, height: 20)
        let value = try #require(Fitts.difficulty(from: start, target: target))
        #expect(abs(value - log2(6)) < 0.000001)
        let scaled = try #require(Fitts.difficulty(from: CGPoint(x: -200, y: -200),
                                                  target: CGRect(x: -20, y: -20, width: 40, height: 40)))
        #expect(abs(value - scaled) < 0.000001)
    }

    @Test func fittsInvalidAndAlreadyInsideTarget() {
        #expect(Fitts.difficulty(from: .zero, target: .zero) == nil)
        #expect(Fitts.difficulty(from: CGPoint(x: Double.infinity, y: 0),
                                target: CGRect(x: 0, y: 0, width: 10, height: 10)) == nil)
        #expect(Fitts.difficulty(from: CGPoint(x: 5, y: 5),
                                target: CGRect(x: 0, y: 0, width: 10, height: 10)) == 0)
    }

    @Test func movementStartsAfterRestAndAfterClick() {
        var movement = PointerMovement(at: .zero)
        movement.move(to: CGPoint(x: 10, y: 0), at: 0)
        movement.move(to: CGPoint(x: 20, y: 0), at: 0.1)
        #expect(movement.origin == .zero)
        movement.move(to: CGPoint(x: 30, y: 0), at: 1)
        #expect(movement.origin == CGPoint(x: 20, y: 0))
        movement.clicked(at: CGPoint(x: 30, y: 0))
        movement.move(to: CGPoint(x: 40, y: 0), at: 1.1)
        #expect(movement.origin == CGPoint(x: 30, y: 0))
    }

    @Test func stopwatchPauseResumeAndDuplicateStart() {
        var watch = Stopwatch()
        watch.start(at: 10)
        watch.start(at: 11)
        #expect(watch.elapsed(at: 15) == 5)
        watch.stop(at: 15)
        #expect(watch.elapsed(at: 100) == 5)
        watch.stop(at: 100)
        watch.start(at: 100)
        #expect(watch.elapsed(at: 103) == 8)
        #expect(watch.isRunning)
    }
}
