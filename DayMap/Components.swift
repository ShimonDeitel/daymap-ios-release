import SwiftUI

/// A small labelled metric tile (used on the trip header / share card).
struct MetricTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dmAccent)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.dmCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// A category chip used in the Add-block sheet's suggestion picker.
struct CategoryChip: View {
    let category: ActivityCategory
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon).font(.system(size: 12, weight: .semibold))
                Text(category.name).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(selected ? Color.dmAccent : Color.dmCard, in: Capsule())
            .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// One row in a day's timeline: time rail on the left, a tappable activity card on the right.
/// Shows an overlap warning and (Pro) a transit-buffer badge.
struct BlockRow: View {
    let block: Block
    let overlapping: Bool
    let showTransit: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(Planner.clockLabel(block.startMinute))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dmAccent)
                    .monospacedDigit()
                Text(Planner.clockLabel(block.endMinute))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(width: 78, alignment: .trailing)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(block.label).font(.body.weight(.semibold))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if overlapping {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                            .accessibilityLabel("Overlaps another activity")
                    }
                }
                HStack(spacing: 8) {
                    Label(Planner.durationLabel(block.durationMins), systemImage: "clock")
                        .font(.caption).foregroundStyle(.secondary)
                    if showTransit && block.transitMins > 0 {
                        Label("\(block.transitMins)m transit", systemImage: "figure.walk")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !block.note.isEmpty {
                    Text(block.note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dmCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(overlapping ? Color.orange.opacity(0.5) : .clear, lineWidth: 1.5)
            )
        }
    }
}

/// Wraps UIActivityViewController so we can share a rendered itinerary card image or text.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

func mmss(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}
