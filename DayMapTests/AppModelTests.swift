import XCTest
import SwiftData
@testable import DayMap

/// Integration tests for the live app logic: trip/day/block CRUD, the free-tier "one trip" gate,
/// and the StoreKit product/price wiring. Runs on an in-memory SwiftData store.
@MainActor
final class AppModelTests: XCTestCase {

    private func memoryModel() -> ModelContainer {
        try! ModelContainer(for: Trip.self, Day.self, Block.self,
                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    // MARK: Free-tier gate

    func testFreeTierAllowsOnlyOneTrip() {
        let model = AppModel(container: memoryModel())
        XCTAssertEqual(model.tripCount, 0)
        XCTAssertTrue(model.canCreateTrip(isPro: false))

        let first = model.createTrip(name: "Rome", isPro: false)
        XCTAssertNotNil(first)
        XCTAssertEqual(model.tripCount, 1)

        // Second trip is blocked for a free user.
        XCTAssertFalse(model.canCreateTrip(isPro: false))
        let second = model.createTrip(name: "Tokyo", isPro: false)
        XCTAssertNil(second, "free users must not create a second trip")
        XCTAssertEqual(model.tripCount, 1)
    }

    func testProUserCanCreateManyTrips() {
        let model = AppModel(container: memoryModel())
        XCTAssertNotNil(model.createTrip(name: "Rome", isPro: true))
        XCTAssertNotNil(model.createTrip(name: "Tokyo", isPro: true))
        XCTAssertNotNil(model.createTrip(name: "Oslo", isPro: true))
        XCTAssertEqual(model.tripCount, 3)
    }

    // MARK: Trip seeds one day

    func testNewTripSeedsOneDay() {
        let model = AppModel(container: memoryModel())
        let trip = model.createTrip(name: "Lisbon", isPro: false)!
        XCTAssertEqual(trip.sortedDays.count, 1)
    }

    // MARK: Days are consecutive

    func testAddDayAppendsNextCalendarDay() {
        let model = AppModel(container: memoryModel())
        let trip = model.createTrip(name: "Lisbon", isPro: true)!
        let day1 = trip.sortedDays.first!
        let day2 = model.addDay(to: trip)
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: day1.date)!
        XCTAssertEqual(Calendar.current.startOfDay(for: day2.date),
                       Calendar.current.startOfDay(for: expected))
        XCTAssertEqual(trip.sortedDays.count, 2)
    }

    // MARK: Blocks CRUD + clamping

    func testAddBlockClampsDurationAndStart() {
        let model = AppModel(container: memoryModel())
        let trip = model.createTrip(name: "Lisbon", isPro: true)!
        let day = trip.sortedDays.first!

        let b = model.addBlock(to: day, label: "Lunch", startMinute: 99999,
                               durationMins: 1, transitMins: -5)
        XCTAssertEqual(b.startMinute, Planner.minutesInDay)   // clamped to end of day
        XCTAssertEqual(b.durationMins, 5)                     // floored to a 5-min minimum
        XCTAssertEqual(b.transitMins, 0)                      // negatives clamped to 0
        XCTAssertEqual(day.sortedBlocks.count, 1)

        model.deleteBlock(b)
        XCTAssertEqual(day.sortedBlocks.count, 0)
    }

    func testSortedBlocksOrderByStart() {
        let model = AppModel(container: memoryModel())
        let trip = model.createTrip(name: "Lisbon", isPro: true)!
        let day = trip.sortedDays.first!
        model.addBlock(to: day, label: "Dinner", startMinute: 1140, durationMins: 90)  // 19:00
        model.addBlock(to: day, label: "Breakfast", startMinute: 480, durationMins: 45) // 8:00
        let labels = day.sortedBlocks.map { $0.label }
        XCTAssertEqual(labels, ["Breakfast", "Dinner"])
    }

    // MARK: Delete all

    func testDeleteAllDataClearsEverything() {
        let model = AppModel(container: memoryModel())
        let trip = model.createTrip(name: "Lisbon", isPro: true)!
        model.addBlock(to: trip.sortedDays.first!, label: "Walk", startMinute: 600, durationMins: 60)
        model.deleteAllData()
        XCTAssertEqual(model.tripCount, 0)
        XCTAssertTrue(model.allTrips().isEmpty)
    }

    // MARK: Store

    func testStoreStartsLockedAtRightPrice() async {
        let store = Store()
        try? await Task.sleep(for: .seconds(0.3))
        XCTAssertEqual(Store.productID, "daymap_pro_unlock")
        XCTAssertEqual(store.displayPrice, "$0.99")
        XCTAssertFalse(store.isPro, "Pro must start locked")
    }
}
