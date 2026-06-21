import XCTest
@testable import DayMap

/// Pure planning-logic tests: time formatting, overlap detection, and the transit-aware
/// "suggested next start". No SwiftData / StoreKit needed.
final class PlannerTests: XCTestCase {

    // MARK: Time formatting

    func testClockLabel12Hour() {
        XCTAssertEqual(Planner.clockLabel(0), "12:00 AM")
        XCTAssertEqual(Planner.clockLabel(9 * 60), "9:00 AM")
        XCTAssertEqual(Planner.clockLabel(12 * 60), "12:00 PM")
        XCTAssertEqual(Planner.clockLabel(13 * 60 + 30), "1:30 PM")
        XCTAssertEqual(Planner.clockLabel(23 * 60 + 5), "11:05 PM")
        // Clamped to end-of-day.
        XCTAssertEqual(Planner.clockLabel(24 * 60), "12:00 AM")
    }

    func testClockLabel24Hour() {
        XCTAssertEqual(Planner.clockLabel(9 * 60, use24h: true), "09:00")
        XCTAssertEqual(Planner.clockLabel(13 * 60 + 5, use24h: true), "13:05")
    }

    func testDurationLabel() {
        XCTAssertEqual(Planner.durationLabel(45), "45m")
        XCTAssertEqual(Planner.durationLabel(60), "1h")
        XCTAssertEqual(Planner.durationLabel(90), "1h 30m")
        XCTAssertEqual(Planner.durationLabel(150), "2h 30m")
        XCTAssertEqual(Planner.durationLabel(0), "0m")
    }

    func testSnap() {
        XCTAssertEqual(Planner.snap(542), 540)   // -> 9:00
        XCTAssertEqual(Planner.snap(543), 545)   // -> 9:05
        XCTAssertEqual(Planner.snap(-10), 0)
        XCTAssertEqual(Planner.snap(99999), Planner.minutesInDay)
    }

    // MARK: Overlap detection

    func testOverlapsBasic() {
        let a = PlanBlock(startMinute: 540, durationMins: 60)   // 9:00–10:00
        let b = PlanBlock(startMinute: 600, durationMins: 60)   // 10:00–11:00 (touching, no overlap)
        let c = PlanBlock(startMinute: 570, durationMins: 60)   // 9:30–10:30 (overlaps a)
        XCTAssertFalse(Planner.overlaps(a, b))
        XCTAssertTrue(Planner.overlaps(a, c))
    }

    func testOverlappingIDsFindsAllConflicts() {
        let a = PlanBlock(startMinute: 540, durationMins: 60)   // 9:00–10:00
        let b = PlanBlock(startMinute: 570, durationMins: 60)   // 9:30–10:30 overlaps a
        let c = PlanBlock(startMinute: 720, durationMins: 30)   // 12:00–12:30 clear
        let ids = Planner.overlappingIDs([a, b, c])
        XCTAssertEqual(ids, [a.id, b.id])
        XCTAssertTrue(Planner.hasOverlap([a, b, c]))
        XCTAssertFalse(Planner.hasOverlap([a, c]))
        XCTAssertFalse(Planner.hasOverlap([]))
    }

    // MARK: Suggested next start (transit-aware)

    func testSuggestedStartEmptyUsesDefault() {
        XCTAssertEqual(Planner.suggestedStart(after: [], duration: 60), 540)
        XCTAssertEqual(Planner.suggestedStart(after: [], duration: 60, defaultStart: 480), 480)
    }

    func testSuggestedStartHonorsTransitBuffer() {
        // 9:00–10:00 activity + 20m transit -> next free slot is 10:20 (620).
        let a = PlanBlock(startMinute: 540, durationMins: 60, transitMins: 20)
        XCTAssertEqual(Planner.suggestedStart(after: [a], duration: 90), 620)
    }

    func testSuggestedStartUsesLatestEnd() {
        let a = PlanBlock(startMinute: 540, durationMins: 60)   // ends 10:00
        let b = PlanBlock(startMinute: 600, durationMins: 120)  // 10:00–12:00 ends latest
        XCTAssertEqual(Planner.suggestedStart(after: [a, b], duration: 60), 720) // 12:00
    }

    func testClampStartNeverRunsPastMidnight() {
        // A 120-min activity can start no later than 22:00 (1320) to fit before midnight.
        XCTAssertEqual(Planner.clampStart(23 * 60, duration: 120), Planner.minutesInDay - 120)
        XCTAssertEqual(Planner.suggestedStart(after: [PlanBlock(startMinute: 1380, durationMins: 30)],
                                              duration: 120), Planner.minutesInDay - 120)
    }

    // MARK: Day totals

    func testDayTotals() {
        let blocks = [
            PlanBlock(startMinute: 540, durationMins: 60, transitMins: 15),
            PlanBlock(startMinute: 660, durationMins: 90, transitMins: 0)
        ]
        XCTAssertEqual(Planner.scheduledMinutes(blocks), 150)
        XCTAssertEqual(Planner.transitMinutes(blocks), 15)
    }

    // MARK: Bundled activity library

    func testActivityLibraryLoadsAndIsFamilyFriendly() {
        XCTAssertFalse(ActivityLibrary.categories.isEmpty, "bundled activities.json must load")
        XCTAssertFalse(ActivityLibrary.all.isEmpty)
        // Every suggestion has a non-empty label and a positive duration.
        for s in ActivityLibrary.all {
            XCTAssertFalse(s.label.isEmpty)
            XCTAssertGreaterThan(s.duration, 0)
        }
    }
}
