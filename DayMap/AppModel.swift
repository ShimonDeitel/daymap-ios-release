import Foundation
import SwiftData
import SwiftUI

/// App state: owns the SwiftData store (fully local, on-device persistence only),
/// creates trips/days/blocks, and enforces the free-tier "one trip" gate.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    /// Free tier allows exactly one trip; Pro lifts the cap.
    static let freeTripLimit = 1

    @Published private(set) var tripCount = 0

    init(container: ModelContainer) {
        self.container = container
        #if DEBUG
        seedIfRequested()
        #endif
        refresh()
    }

    // MARK: Container

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Trip.self, Day.self, Block.self])
        // Fully local, on-device persistence — no CloudKit, no special capabilities.
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        // Last resort so the app never crashes on launch.
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Trips

    func allTrips() -> [Trip] {
        let d = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? container.mainContext.fetch(d)) ?? []
    }

    /// Whether a NEW trip can be created given the current Pro state and trip count.
    func canCreateTrip(isPro: Bool) -> Bool {
        isPro || tripCount < Self.freeTripLimit
    }

    /// Creates a trip seeded with one day (today). Returns nil if the free cap blocks it.
    @discardableResult
    func createTrip(name: String, isPro: Bool, startDate: Date = .now) -> Trip? {
        guard canCreateTrip(isPro: isPro) else { return nil }
        let ctx = container.mainContext
        let trip = Trip(name: name.isEmpty ? "New Trip" : name)
        ctx.insert(trip)
        let day = Day(date: Calendar.current.startOfDay(for: startDate), trip: trip)
        ctx.insert(day)
        trip.days = [day]
        try? ctx.save()
        refresh()
        return trip
    }

    func renameTrip(_ trip: Trip, to name: String) {
        trip.name = name.isEmpty ? "New Trip" : name
        try? container.mainContext.save()
        refresh()
    }

    func setNotes(_ trip: Trip, notes: String) {
        trip.notes = notes
        try? container.mainContext.save()
    }

    func deleteTrip(_ trip: Trip) {
        container.mainContext.delete(trip)
        try? container.mainContext.save()
        refresh()
    }

    // MARK: Days

    /// Adds the next consecutive day to a trip and returns it.
    @discardableResult
    func addDay(to trip: Trip) -> Day {
        let ctx = container.mainContext
        let cal = Calendar.current
        let lastDate = trip.sortedDays.last?.date ?? cal.startOfDay(for: .now)
        let next = cal.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate
        let day = Day(date: cal.startOfDay(for: next), trip: trip)
        ctx.insert(day)
        var existing = trip.days ?? []
        existing.append(day)
        trip.days = existing
        try? ctx.save()
        refresh()
        return day
    }

    func deleteDay(_ day: Day) {
        container.mainContext.delete(day)
        try? container.mainContext.save()
        refresh()
    }

    // MARK: Blocks

    @discardableResult
    func addBlock(to day: Day, label: String, startMinute: Int, durationMins: Int,
                  transitMins: Int = 0, note: String = "") -> Block {
        let ctx = container.mainContext
        let block = Block(label: label.isEmpty ? "Activity" : label,
                          startMinute: max(0, min(startMinute, Planner.minutesInDay)),
                          durationMins: max(5, durationMins),
                          transitMins: max(0, transitMins),
                          note: note,
                          day: day)
        ctx.insert(block)
        var existing = day.blocks ?? []
        existing.append(block)
        day.blocks = existing
        try? ctx.save()
        objectWillChange.send()
        return block
    }

    func updateBlock(_ block: Block, label: String, startMinute: Int, durationMins: Int,
                     transitMins: Int, note: String) {
        block.label = label.isEmpty ? "Activity" : label
        block.startMinute = max(0, min(startMinute, Planner.minutesInDay))
        block.durationMins = max(5, durationMins)
        block.transitMins = max(0, transitMins)
        block.note = note
        try? container.mainContext.save()
        objectWillChange.send()
    }

    func deleteBlock(_ block: Block) {
        container.mainContext.delete(block)
        try? container.mainContext.save()
        objectWillChange.send()
    }

    // MARK: Stats / refresh

    func refresh() {
        tripCount = (try? container.mainContext.fetchCount(FetchDescriptor<Trip>())) ?? 0
    }

    /// Erase all on-device data (used by Delete Account).
    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: Block.self)
        try? ctx.delete(model: Day.self)
        try? ctx.delete(model: Trip.self)
        try? ctx.save()
        refresh()
    }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard env["DAYMAP_SEED"] == "1" else { return }
        let ctx = container.mainContext
        guard ((try? ctx.fetchCount(FetchDescriptor<Trip>())) ?? 0) == 0 else { return }
        let trip = Trip(name: "Lisbon Weekend")
        ctx.insert(trip)
        let cal = Calendar.current
        let day = Day(date: cal.startOfDay(for: .now), trip: trip)
        ctx.insert(day)
        let seedBlocks: [(String, Int, Int, Int)] = [
            ("Hotel breakfast", 8 * 60, 45, 15),
            ("Old town walking tour", 10 * 60, 90, 20),
            ("Lunch", 13 * 60, 60, 10),
            ("Museum visit", 15 * 60, 120, 0)
        ]
        var blocks: [Block] = []
        for (label, start, dur, transit) in seedBlocks {
            let b = Block(label: label, startMinute: start, durationMins: dur, transitMins: transit, day: day)
            ctx.insert(b)
            blocks.append(b)
        }
        day.blocks = blocks
        trip.days = [day]
        try? ctx.save()
    }
    #endif
}
