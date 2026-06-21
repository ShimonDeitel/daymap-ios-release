import Foundation

/// One pre-made activity suggestion (label + a sensible default duration in minutes).
struct ActivitySuggestion: Identifiable, Equatable, Codable {
    var id: String { label }
    let label: String
    let duration: Int
}

/// A named group of suggestions with an SF Symbol name.
struct ActivityCategory: Identifiable, Equatable, Codable {
    var id: String { name }
    let name: String
    let icon: String
    let suggestions: [ActivitySuggestion]
}

/// Loads the bundled `activities.json` (a Resources build-phase file) once at launch. The data is
/// original and factual (generic travel activity names), so it carries no licensing concerns and
/// stays family-friendly. Falls back to a small built-in set if the resource is ever missing.
enum ActivityLibrary {
    private struct Payload: Codable { let version: Int; let categories: [ActivityCategory] }

    static let categories: [ActivityCategory] = load()

    /// Flattened, de-duplicated list of every suggestion across categories.
    static let all: [ActivitySuggestion] = {
        var seen = Set<String>()
        var out: [ActivitySuggestion] = []
        for c in categories {
            for s in c.suggestions where !seen.contains(s.label) {
                seen.insert(s.label)
                out.append(s)
            }
        }
        return out
    }()

    private static func load() -> [ActivityCategory] {
        if let url = Bundle.main.url(forResource: "activities", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let payload = try? JSONDecoder().decode(Payload.self, from: data),
           !payload.categories.isEmpty {
            return payload.categories
        }
        return fallback
    }

    /// Minimal built-in set guaranteeing the picker is never empty.
    private static let fallback: [ActivityCategory] = [
        ActivityCategory(name: "Essentials", icon: "star.fill", suggestions: [
            ActivitySuggestion(label: "Breakfast", duration: 45),
            ActivitySuggestion(label: "Sightseeing", duration: 120),
            ActivitySuggestion(label: "Lunch", duration: 60),
            ActivitySuggestion(label: "Walk", duration: 60),
            ActivitySuggestion(label: "Dinner", duration: 90)
        ])
    ]
}
