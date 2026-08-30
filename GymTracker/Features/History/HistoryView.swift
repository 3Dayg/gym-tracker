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
    @State private var sessionPendingDelete: WorkoutSession?

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
                            .accessibilityIdentifier("historyRow-\(session.planName ?? "Workout")")
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete") {
                                    sessionPendingDelete = session
                                }
                                .tint(.red)
                                .accessibilityIdentifier("deleteHistoryWorkout")
                            }
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
                    EmptyStateBlock(
                        title: "No Workouts Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: "Finish a workout and it will show up here.",
                        actionTitle: "Start Workout",
                        actionIdentifier: "emptyHistoryStartWorkout",
                        action: { navigation.openWorkout() }
                    )
                }
            }
            .onChange(of: navigation.sessionToReveal) { _, session in
                revealIfNeeded(session)
            }
            .onAppear {
                revealIfNeeded(navigation.sessionToReveal)
            }
            .sheet(isPresented: Binding(
                get: { sessionPendingDelete != nil },
                set: { if !$0 { sessionPendingDelete = nil } }
            )) {
                ConfirmDestructiveSheet(
                    title: "Delete this workout?",
                    message: "\(sessionPendingDelete?.planName ?? "Workout") will be removed from History. This cannot be undone.",
                    keepTitle: "Keep Workout",
                    deleteTitle: "Delete Workout",
                    keepIdentifier: "cancelDeleteHistory",
                    deleteIdentifier: "confirmDeleteHistory",
                    onKeep: { sessionPendingDelete = nil },
                    onDelete: {
                        if let sessionPendingDelete {
                            modelContext.delete(sessionPendingDelete)
                            try? modelContext.save()
                        }
                        sessionPendingDelete = nil
                    }
                )
                .presentationDetents([.medium])
                .interactiveDismissDisabled()
            }
        }
    }

    private func revealIfNeeded(_ session: WorkoutSession?) {
        guard let session else { return }
        path = [session]
        navigation.sessionToReveal = nil
    }
}

private struct SessionSummaryRow: View {
    let session: WorkoutSession
    let unitSystem: UnitSystem

    private var caption: String {
        SessionHistorySummary.from(session).caption(duration: session.duration, unit: unitSystem)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: SessionHistorySummary.from(session).modalitySymbol)
                .foregroundStyle(Color.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.planName ?? "Workout")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(session.startedAt, format: .dateTime.day().month())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .accessibilityIdentifier("historySummary-\(session.planName ?? "Workout")")
            }
        }
        .padding(.vertical, 2)
    }
}

