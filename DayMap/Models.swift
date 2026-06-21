import Foundation
import SwiftData

// MARK: - SwiftData models
//
// All properties have defaults and relationships are optional, so the schema is CloudKit
// mirroring–compatible (CloudKit requires every attribute to be optional or have a default,
// and relationships to be optional). Deletes cascade Trip -> Day -> Block.

/// A planned trip. Owns an ordered set of days.
@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = "New Trip"
    var createdAt: Date = Date.now
    /// Notes are a Pro feature in the UI, but the column always exists.
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Day.trip)
    var days: [Day]? = []

    init(id: UUID = UUID(), name: String = "New Trip", createdAt: Date = .now, notes: String = "") {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.notes = notes
    }

    /// Days sorted by their calendar date (CloudKit relationships are unordered).
    var sortedDays: [Day] {
        (days ?? []).sorted { $0.date < $1.date }
    }
}

/// One calendar day inside a trip. Owns the activity blocks for that day.
@Model
final class Day {
    var id: UUID = UUID()
    var date: Date = Date.now
    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \Block.day)
    var blocks: [Block]? = []

    init(id: UUID = UUID(), date: Date = .now, trip: Trip? = nil) {
        self.id = id
        self.date = date
        self.trip = trip
    }

    /// Blocks sorted by start minute (CloudKit relationships are unordered).
    var sortedBlocks: [Block] {
        (blocks ?? []).sorted { $0.startMinute < $1.startMinute }
    }
}

/// A single scheduled activity inside a day.
/// `startMinute` is minutes from midnight (0...1439). `durationMins` is the activity length.
@Model
final class Block {
    var id: UUID = UUID()
    var label: String = "Activity"
    /// Minutes from midnight, 0...1439.
    var startMinute: Int = 540   // 09:00
    var durationMins: Int = 60
    /// Optional travel buffer (minutes) reserved AFTER this block to reach the next stop. Pro.
    var transitMins: Int = 0
    /// Per-block note (Pro).
    var note: String = ""
    var day: Day?

    init(id: UUID = UUID(), label: String = "Activity", startMinute: Int = 540,
         durationMins: Int = 60, transitMins: Int = 0, note: String = "", day: Day? = nil) {
        self.id = id
        self.label = label
        self.startMinute = startMinute
        self.durationMins = durationMins
        self.transitMins = transitMins
        self.note = note
        self.day = day
    }

    /// Inclusive start, exclusive end of the activity itself (excluding transit), clamped to a day.
    var endMinute: Int { min(startMinute + max(0, durationMins), 24 * 60) }
    /// End of the reserved transit buffer (where the next activity could begin).
    var endWithTransit: Int { min(endMinute + max(0, transitMins), 24 * 60) }
}
