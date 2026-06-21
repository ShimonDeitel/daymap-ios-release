import SwiftUI
import SwiftData

/// A single trip: horizontal day tabs and, below, the selected day's hour-by-hour timeline.
struct TripView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Bindable var trip: Trip

    @State private var selectedDayID: UUID?
    @State private var showAddBlock = false
    @State private var editingBlock: Block?
    @State private var showShare = false
    @State private var showPaywall = false
    @State private var showRename = false
    @State private var renameText = ""

    private var days: [Day] { trip.sortedDays }
    private var selectedDay: Day? {
        days.first { $0.id == selectedDayID } ?? days.first
    }

    var body: some View {
        ZStack {
            DMBackground()
            VStack(spacing: 0) {
                dayTabs
                Divider()
                if let day = selectedDay {
                    DayTimelineView(
                        day: day,
                        showTransit: store.isPro,
                        onEdit: { editingBlock = $0 },
                        onDelete: { appModel.deleteBlock($0) }
                    )
                } else {
                    Spacer()
                    Text("No days yet").foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { renameText = trip.name; showRename = true } label: {
                        Label("Rename trip", systemImage: "pencil")
                    }
                    Button { shareTapped() } label: {
                        Label("Share itinerary", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("trip-menu")
            }
        }
        .tint(Color.dmAccent)
        .safeAreaInset(edge: .bottom) { addBlockBar }
        .sheet(isPresented: $showAddBlock) {
            if let day = selectedDay {
                AddBlockView(day: day)
            }
        }
        .sheet(item: $editingBlock) { block in
            AddBlockView(day: block.day ?? selectedDay, editing: block)
        }
        .sheet(isPresented: $showShare) {
            if let day = selectedDay {
                ShareCardView(trip: trip, day: day)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("Rename trip", isPresented: $showRename) {
            TextField("Trip name", text: $renameText)
            Button("Save") { appModel.renameTrip(trip, to: renameText) }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { if selectedDayID == nil { selectedDayID = days.first?.id } }
    }

    private var dayTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                    DayTab(index: idx, date: day.date,
                           selected: day.id == (selectedDay?.id))
                    .onTapGesture { Haptics.tap(); selectedDayID = day.id }
                }
                Button { appModel.addDay(to: trip); selectedDayID = trip.sortedDays.last?.id } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "plus")
                        Text("Day").font(.caption2)
                    }
                    .frame(width: 52, height: 52)
                    .background(Color.dmCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color.dmAccent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("add-day")
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private var addBlockBar: some View {
        Button { Haptics.tap(); showAddBlock = true } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add activity").font(.headline)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .prominentButton()
        .padding(.horizontal)
        .padding(.bottom, 8)
        .disabled(selectedDay == nil)
        .accessibilityIdentifier("add-block")
    }

    private func shareTapped() {
        // Sharing the polished card is a Pro export feature; free users see the paywall.
        if store.isPro { showShare = true }
        else { Haptics.warning(); showPaywall = true }
    }
}

/// A compact day tab showing the weekday + day-of-month.
private struct DayTab: View {
    let index: Int
    let date: Date
    let selected: Bool

    private var weekday: String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date)
    }
    private var dayNum: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("Day \(index + 1)").font(.caption2.weight(.semibold))
                .foregroundStyle(selected ? .white.opacity(0.9) : .secondary)
            Text(dayNum).font(.title3.weight(.bold))
            Text(weekday).font(.caption2)
                .foregroundStyle(selected ? .white.opacity(0.9) : .secondary)
        }
        .frame(width: 56, height: 62)
        .background(selected ? Color.dmAccent : Color.dmCard,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(selected ? .white : .primary)
    }
}

/// The scrollable timeline for one day: a header strip of totals, then the ordered activity rows
/// with overlap warnings. Empty days get a gentle prompt.
private struct DayTimelineView: View {
    @Bindable var day: Day
    let showTransit: Bool
    let onEdit: (Block) -> Void
    let onDelete: (Block) -> Void

    private var blocks: [Block] { day.sortedBlocks }
    private var planBlocks: [PlanBlock] {
        blocks.map { PlanBlock(id: $0.id, label: $0.label, startMinute: $0.startMinute,
                               durationMins: $0.durationMins, transitMins: $0.transitMins) }
    }
    private var overlappingIDs: Set<UUID> { Planner.overlappingIDs(planBlocks) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if blocks.isEmpty {
                    emptyDay
                } else {
                    if !overlappingIDs.isEmpty {
                        Label("Some activities overlap. Tap one to adjust its time.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.orange.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    ForEach(blocks) { block in
                        Button { Haptics.tap(); onEdit(block) } label: {
                            BlockRow(block: block,
                                     overlapping: overlappingIDs.contains(block.id),
                                     showTransit: showTransit)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { onDelete(block) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            MetricTile(value: "\(blocks.count)", label: blocks.count == 1 ? "Activity" : "Activities")
            MetricTile(value: Planner.durationLabel(Planner.scheduledMinutes(planBlocks)),
                       label: "Planned")
            if showTransit {
                MetricTile(value: Planner.durationLabel(Planner.transitMinutes(planBlocks)),
                           label: "Transit")
            }
        }
    }

    private var emptyDay: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.day.timeline.left")
                .font(.system(size: 40)).foregroundStyle(Color.dmAccent)
            Text("Nothing planned yet").font(.headline)
            Text("Add your first activity below to start\nmapping out this day.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}
