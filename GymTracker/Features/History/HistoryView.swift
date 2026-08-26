import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.unitSystem) private var unitSystem: UnitSystem = .metric

    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
        sort: \WorkoutSession.startedAt,
        order: .reverse
    )
    private var sessions: [WorkoutSession]

    @Environment(AppNavigation.self) private var navigation
    @State private var path: [WorkoutSession] = []

    /// Sessions grouped by month, newest first.
    private var groupedSessions: [(month: Date, sessions: [WorkoutSession])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .month, for: session.startedAt)?.start ?? session.startedAt
        }
        return groups
            .sorted { $0.key > $1.key }
            .map { (month: $0.key, sessions: $0.value) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(groupedSessions, id: \.month) { group in
                    Section(group.month.formatted(.dateTime.month(.wide).year())) {
                        ForEach(group.sessions) { session in
                            NavigationLink(value: session) {
                                SessionSummaryRow(session: session, unitSystem: unitSystem)
                            }
                        }
                        .onDelete { offsets in
                            deleteSessions(at: offsets, in: group.sessions)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileToolbarButton()
                }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finished workouts will show up here.")
                    )
                }
            }
            .onChange(of: navigation.sessionToReveal) { _, session in
                revealIfNeeded(session)
            }
            .onAppear {
                revealIfNeeded(navigation.sessionToReveal)
            }
        }
    }

    private func revealIfNeeded(_ session: WorkoutSession?) {
        guard let session else { return }
        path = [session]
        navigation.sessionToReveal = nil
    }

    private func deleteSessions(at offsets: IndexSet, in group: [WorkoutSession]) {
        for index in offsets {
            modelContext.delete(group[index])
        }
    }
}

private struct SessionSummaryRow: View {
    let session: WorkoutSession
    let unitSystem: UnitSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.planName ?? "Workout")
                    .font(.headline)
                Spacer()
                Text(session.startedAt, format: .dateTime.day().month())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(Formatters.duration(session.duration), systemImage: "clock")
                if session.completedCardioSeconds > 0 {
                    Label(
                        Formatters.durationSeconds(session.completedCardioSeconds),
                        systemImage: "figure.walk"
                    )
                } else {
                    Label("\(session.completedSetCount) sets", systemImage: "checkmark.circle")
                    Label(
                        Formatters.weight(session.totalVolume, unit: unitSystem),
                        systemImage: "scalemass"
                    )
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
