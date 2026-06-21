import SwiftUI

/// Add or edit one activity block. Suggestions come from the bundled activity library; start time
/// is pre-filled with a transit-aware suggestion. Transit buffers and notes are Pro.
struct AddBlockView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let day: Day?
    var editing: Block?

    @State private var label = ""
    @State private var startMinute = 540          // 9:00
    @State private var durationMins = 60
    @State private var transitMins = 0
    @State private var note = ""
    @State private var selectedCategory: String?
    @State private var showPaywall = false

    private var isEditing: Bool { editing != nil }

    private let durations: [Int] = [15, 30, 45, 60, 90, 120, 150, 180]

    var body: some View {
        NavigationStack {
            Form {
                activitySection
                timeSection
                if store.isPro { transitSection; noteSection } else { proUpsellSection }
            }
            .navigationTitle(isEditing ? "Edit activity" : "New activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("save-block")
                }
            }
            .tint(Color.dmAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear(perform: prime)
        }
    }

    // MARK: Sections

    private var activitySection: some View {
        Section("Activity") {
            TextField("What are you doing?", text: $label)
                .accessibilityIdentifier("block-label")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ActivityLibrary.categories) { cat in
                        CategoryChip(category: cat, selected: selectedCategory == cat.name) {
                            Haptics.tap()
                            selectedCategory = selectedCategory == cat.name ? nil : cat.name
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 0))
            if let cat = ActivityLibrary.categories.first(where: { $0.name == selectedCategory }) {
                ForEach(cat.suggestions) { s in
                    Button {
                        Haptics.tap()
                        label = s.label
                        durationMins = s.duration
                    } label: {
                        HStack {
                            Text(s.label)
                            Spacer()
                            Text(Planner.durationLabel(s.duration))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
            }
        }
    }

    private var timeSection: some View {
        Section("When") {
            DatePicker("Start time", selection: startBinding, displayedComponents: .hourAndMinute)
            Picker("Duration", selection: $durationMins) {
                ForEach(durations, id: \.self) { d in
                    Text(Planner.durationLabel(d)).tag(d)
                }
            }
            HStack {
                Text("Ends")
                Spacer()
                Text(Planner.clockLabel(min(startMinute + durationMins, Planner.minutesInDay)))
                    .foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }

    private var transitSection: some View {
        Section("Transit buffer") {
            Stepper(value: $transitMins, in: 0...120, step: 5) {
                HStack {
                    Label("Travel to next stop", systemImage: "figure.walk")
                    Spacer()
                    Text(transitMins == 0 ? "None" : "\(transitMins)m")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var noteSection: some View {
        Section("Note") {
            TextField("Optional note", text: $note, axis: .vertical)
                .lineLimit(1...4)
        }
    }

    private var proUpsellSection: some View {
        Section {
            Button { Haptics.tap(); showPaywall = true } label: {
                HStack {
                    Label("Add transit buffers & notes", systemImage: "sparkles")
                    Spacer()
                    Image(systemName: "lock.fill").font(.footnote)
                }
            }
        } footer: {
            Text("DayMap Pro adds automatic travel buffers between stops and per-activity notes.")
        }
    }

    // MARK: Bindings

    private var startBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: startMinute / 60,
                                                            minute: startMinute % 60)) ?? Date()
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                startMinute = (c.hour ?? 9) * 60 + (c.minute ?? 0)
            }
        )
    }

    // MARK: Lifecycle

    private func prime() {
        if let b = editing {
            label = b.label
            startMinute = b.startMinute
            durationMins = b.durationMins
            transitMins = b.transitMins
            note = b.note
        } else if let day {
            let existing = day.sortedBlocks.map {
                PlanBlock(id: $0.id, label: $0.label, startMinute: $0.startMinute,
                          durationMins: $0.durationMins, transitMins: $0.transitMins)
            }
            startMinute = Planner.suggestedStart(after: existing, duration: durationMins)
        }
    }

    private func save() {
        guard let day else { dismiss(); return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = store.isPro ? transitMins : 0
        let n = store.isPro ? note : ""
        if let b = editing {
            appModel.updateBlock(b, label: trimmed, startMinute: startMinute,
                                 durationMins: durationMins, transitMins: t, note: n)
        } else {
            appModel.addBlock(to: day, label: trimmed, startMinute: startMinute,
                              durationMins: durationMins, transitMins: t, note: n)
        }
        Haptics.success()
        dismiss()
    }
}
