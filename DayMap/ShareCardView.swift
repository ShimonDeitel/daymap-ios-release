import SwiftUI

/// A clean, shareable itinerary card for one day. Renders to a PNG via ImageRenderer and offers the
/// system share sheet. (Export is a Pro feature — reached only after the Pro gate in TripView.)
struct ShareCardView: View {
    @Environment(\.dismiss) private var dismiss
    let trip: Trip
    let day: Day

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                DMBackground()
                ScrollView {
                    card
                        .padding()
                }
            }
            .navigationTitle("Share day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { share() } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityIdentifier("export-share")
                }
            }
            .tint(Color.dmAccent)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }

    private var dayTitle: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: day.date)
    }

    private var card: some View {
        ItineraryCard(tripName: trip.name, dayTitle: dayTitle, blocks: day.sortedBlocks)
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity)
    }

    private func share() {
        let renderer = ImageRenderer(
            content: ItineraryCard(tripName: trip.name, dayTitle: dayTitle, blocks: day.sortedBlocks)
                .frame(width: 360)
        )
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            shareItems = [image, textItinerary()]
        } else {
            shareItems = [textItinerary()]
        }
        Haptics.tap()
        showShareSheet = true
    }

    /// Plain-text fallback / companion of the visual card.
    private func textItinerary() -> String {
        var lines = ["\(trip.name) — \(dayTitle)", ""]
        for b in day.sortedBlocks {
            lines.append("\(Planner.clockLabel(b.startMinute))  \(b.label) (\(Planner.durationLabel(b.durationMins)))")
        }
        lines.append("")
        lines.append("Planned with DayMap")
        return lines.joined(separator: "\n")
    }
}

/// The rendered card content — kept separate so ImageRenderer can rasterize an identical copy.
private struct ItineraryCard: View {
    let tripName: String
    let dayTitle: String
    let blocks: [Block]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "map.fill").foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.dmAccent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(tripName).font(.headline)
                    Text(dayTitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 14) {
                if blocks.isEmpty {
                    Text("No activities planned.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { idx, block in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle().fill(Color.dmAccent).frame(width: 10, height: 10).padding(.top, 4)
                                if idx < blocks.count - 1 {
                                    Rectangle().fill(Color.dmAccent.opacity(0.2))
                                        .frame(width: 2).frame(maxHeight: .infinity)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Planner.clockLabel(block.startMinute))
                                    .font(.caption.weight(.bold)).foregroundStyle(Color.dmAccent)
                                Text(block.label).font(.subheadline.weight(.semibold))
                                Text(Planner.durationLabel(block.durationMins))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            Divider().padding(.vertical, 14)
            HStack {
                Text("Planned with DayMap").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "map.fill").font(.caption).foregroundStyle(Color.dmAccent)
            }
        }
        .padding(22)
        .background(Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
