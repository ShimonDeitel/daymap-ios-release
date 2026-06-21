import SwiftUI
import SwiftData

/// Home — the list of trips, a prominent "New trip", and entry to Settings.
struct HomeView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]

    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showNewTrip = false
    @State private var newTripName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DMBackground()
                content
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("home-settings")
                }
            }
            .tint(Color.dmAccent)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("New trip", isPresented: $showNewTrip) {
                TextField("Trip name", text: $newTripName)
                Button("Create") { createTrip() }
                Button("Cancel", role: .cancel) { newTripName = "" }
            } message: {
                Text("Give your trip a name. You can add days and activities next.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if trips.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(trips) { trip in
                        NavigationLink {
                            TripView(trip: trip)
                        } label: {
                            TripCard(trip: trip)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("trip-\(trip.id)")
                    }

                    newTripButton
                        .padding(.top, 4)
                }
                .padding()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "map")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(Color.dmAccent)
            VStack(spacing: 6) {
                Text("Plan your first trip").font(.title2.weight(.bold))
                Text("Map each day hour by hour — activities,\ntimings and travel buffers in one place.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button { startNewTrip() } label: {
                Text("New trip").frame(maxWidth: 220)
            }
            .prominentButton()
            .accessibilityIdentifier("home-new-trip")
        }
        .padding(32)
    }

    private var newTripButton: some View {
        Button { startNewTrip() } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text(store.isPro || trips.count < AppModel.freeTripLimit
                     ? "New trip" : "Unlock more trips")
                    .font(.headline)
                Spacer()
                if !store.isPro && trips.count >= AppModel.freeTripLimit {
                    Image(systemName: "lock.fill").font(.footnote)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.dmCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(Color.dmAccent)
        }
        .buttonStyle(.plain)
    }

    private func startNewTrip() {
        if appModel.canCreateTrip(isPro: store.isPro) {
            newTripName = ""
            showNewTrip = true
        } else {
            Haptics.warning()
            showPaywall = true
        }
    }

    private func createTrip() {
        let name = newTripName.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = appModel.createTrip(name: name, isPro: store.isPro)
        newTripName = ""
        Haptics.success()
    }
}

/// A trip summary card on Home.
private struct TripCard: View {
    let trip: Trip

    private var dayCount: Int { (trip.days ?? []).count }
    private var activityCount: Int { (trip.days ?? []).reduce(0) { $0 + (($1.blocks ?? []).count) } }
    private var dateRange: String {
        let days = trip.sortedDays
        guard let first = days.first?.date else { return "No days yet" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        if days.count == 1 { return f.string(from: first) }
        let last = days.last?.date ?? first
        return "\(f.string(from: first)) – \(f.string(from: last))"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Color.dmAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name).font(.headline).lineLimit(1)
                Text(dateRange).font(.subheadline).foregroundStyle(.secondary)
                Text("\(dayCount) \(dayCount == 1 ? "day" : "days") · \(activityCount) \(activityCount == 1 ? "activity" : "activities")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.dmCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
