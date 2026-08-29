import SwiftData
import SwiftUI

/// Overview of the live session: jump to a pending exercise or open a
/// finished one to edit a past row. Not a second logging screen.
struct FollowAlongExerciseMap: View {
    let session: WorkoutSession
    let onJump: (SessionExercise) -> Void
    let onEdit: (SessionExercise) -> Void

    private var items: [FollowAlongExerciseItem] {
        LiveWorkoutProgress.exerciseItems(in: session)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        if let exercise = session.orderedExercises.first(
                            where: { $0.sortOrder == item.sortOrder }
                        ) {
                            Button {
                                if item.hasPending {
                                    onJump(exercise)
                                } else {
                                    onEdit(exercise)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: item.hasPending ? "circle" : "checkmark.circle.fill")
                                        .foregroundStyle(item.hasPending ? Color.secondary : Color.primary)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .foregroundStyle(.primary)
                                        Text(item.hasPending ? item.caption : "\(item.caption) · Edit")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if item.isFocused, item.hasPending {
                                        Text("Now")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityIdentifier("exerciseMapRow-\(item.sortOrder)")
                            .accessibilityHint(
                                item.hasPending
                                    ? "Shows this exercise on the card"
                                    : "Opens this exercise to edit a logged row"
                            )
                        }
                    }
                } footer: {
                    Text("A busy machine can wait. Jump to something else, then come back — nothing is skipped.")
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("exerciseMap")
    }
}

struct FollowAlongEditSheet: View {
    let sessionExercise: SessionExercise
    let unitSystem: UnitSystem
    let sessionTimer: SessionTimer
    let restSeconds: Int
    let nextPendingSet: SetEntry?
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                SessionExerciseSection(
                    sessionExercise: sessionExercise,
                    unitSystem: unitSystem,
                    sessionTimer: sessionTimer,
                    followOnRestSeconds: sessionExercise.kind.startsRestTimer ? restSeconds : 0,
                    nextPendingSet: nextPendingSet,
                    onDidWork: {
                        if sessionExercise.kind.startsRestTimer, sessionTimer.phase != .work {
                            sessionTimer.startRest(seconds: restSeconds)
                        }
                    }
                )
            }
            .navigationTitle(sessionExercise.exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                        .accessibilityIdentifier("closeExerciseEdit")
                }
            }
        }
    }
}
