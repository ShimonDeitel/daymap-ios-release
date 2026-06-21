import Foundation

// MARK: - Pure planning logic
//
// Deterministic, value-type helpers with no UI / SwiftData / StoreKit dependencies, so they are
// trivially unit-testable. The 24h grid, overlap detection, transit-aware "next start" suggestion,
// and time formatting all live here.

/// A lightweight, value-type view of a block used by the pure planning functions and tests.
/// (Decoupled from the SwiftData `Block` so logic can be tested without a ModelContainer.)
struct PlanBlock: Equatable {
    var id: UUID
    var label: String
    var startMinute: Int
    var durationMins: Int
    var transitMins: Int

    init(id: UUID = UUID(), label: String = "Activity",
         startMinute: Int, durationMins: Int, transitMins: Int = 0) {
        self.id = id
        self.label = label
        self.startMinute = startMinute
        self.durationMins = durationMins
        self.transitMins = transitMins
    }

    var endMinute: Int { min(startMinute + max(0, durationMins), Planner.minutesInDay) }
    /// Where the following activity may begin once the transit buffer is honored.
    var endWithTransit: Int { min(endMinute + max(0, transitMins), Planner.minutesInDay) }
}

enum Planner {
    static let minutesInDay = 24 * 60   // 1440

    // MARK: Time formatting

    /// "9:00 AM" style label for a minute-of-day value. Clamped to 0...1440.
    static func clockLabel(_ minute: Int, use24h: Bool = false) -> String {
        let m = max(0, min(minute, minutesInDay))
        let h = (m / 60) % 24
        let mm = m % 60
        if use24h {
            return String(format: "%02d:%02d", h, mm)
        }
        let period = h < 12 ? "AM" : "PM"
        var h12 = h % 12
        if h12 == 0 { h12 = 12 }
        return String(format: "%d:%02d %@", h12, mm, period)
    }

    /// Human duration, e.g. 90 -> "1h 30m", 60 -> "1h", 45 -> "45m".
    static func durationLabel(_ minutes: Int) -> String {
        let m = max(0, minutes)
        let h = m / 60
        let mm = m % 60
        if h == 0 { return "\(mm)m" }
        if mm == 0 { return "\(h)h" }
        return "\(h)h \(mm)m"
    }

    /// Snap an arbitrary minute to the nearest `step` (default 5 min), clamped to the day.
    static func snap(_ minute: Int, step: Int = 5) -> Int {
        guard step > 0 else { return max(0, min(minute, minutesInDay)) }
        let snapped = Int((Double(minute) / Double(step)).rounded()) * step
        return max(0, min(snapped, minutesInDay))
    }

    // MARK: Overlap detection

    /// True if two activity windows [start,end) intersect. Transit buffers are NOT treated as a hard
    /// conflict here — they only inform the suggested next start — so back-to-back activities are fine.
    static func overlaps(_ a: PlanBlock, _ b: PlanBlock) -> Bool {
        a.startMinute < b.endMinute && b.startMinute < a.endMinute
    }

    /// The set of block ids that overlap at least one other block in the list.
    static func overlappingIDs(_ blocks: [PlanBlock]) -> Set<UUID> {
        var result = Set<UUID>()
        let sorted = blocks.sorted { $0.startMinute < $1.startMinute }
        for i in 0..<sorted.count {
            for j in (i + 1)..<sorted.count {
                // Sorted by start; once b starts at/after a's end, no later block can overlap a.
                if sorted[j].startMinute >= sorted[i].endMinute { break }
                if overlaps(sorted[i], sorted[j]) {
                    result.insert(sorted[i].id)
                    result.insert(sorted[j].id)
                }
            }
        }
        return result
    }

    /// Whether ANY pair of blocks overlaps.
    static func hasOverlap(_ blocks: [PlanBlock]) -> Bool {
        !overlappingIDs(blocks).isEmpty
    }

    // MARK: Suggested next start

    /// Suggests the start minute for a NEW activity of `duration` minutes: the earliest free slot
    /// at or after the latest block's transit-adjusted end. Falls back to a sensible default
    /// (`defaultStart`, e.g. 9:00) when the day is empty, and never runs the activity past midnight.
    static func suggestedStart(after blocks: [PlanBlock], duration: Int,
                               defaultStart: Int = 540) -> Int {
        guard !blocks.isEmpty else {
            return clampStart(defaultStart, duration: duration)
        }
        let latestEnd = blocks.map { $0.endWithTransit }.max() ?? defaultStart
        return clampStart(latestEnd, duration: duration)
    }

    /// Clamp a desired start so the activity fits before midnight (pushing earlier if needed).
    static func clampStart(_ start: Int, duration: Int) -> Int {
        let d = max(0, min(duration, minutesInDay))
        let latestStart = minutesInDay - d
        return max(0, min(start, max(0, latestStart)))
    }

    // MARK: Day totals

    /// Total scheduled activity minutes (excluding transit) for a day.
    static func scheduledMinutes(_ blocks: [PlanBlock]) -> Int {
        blocks.reduce(0) { $0 + max(0, $1.durationMins) }
    }

    /// Total transit-buffer minutes for a day.
    static func transitMinutes(_ blocks: [PlanBlock]) -> Int {
        blocks.reduce(0) { $0 + max(0, $1.transitMins) }
    }
}
