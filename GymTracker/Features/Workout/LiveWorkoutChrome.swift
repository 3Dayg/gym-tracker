import SwiftUI

/// Completion, next cue, and the exercise map. Elapsed time is still
/// recorded from `startedAt` at finish — it is not shown live.
struct WorkoutProgressHeader: View {
    let progress: LiveWorkoutProgress
    var showsNextLine = true
    var addSetTitle: String?
    var onAddSet: (() -> Void)?
    var onShowExercises: (() -> Void)?
    var cardFill: Color = GymTheme.cardFill

    var body: some View {
        GymCard(padding: 0, fill: cardFill) {
            VStack(alignment: .leading, spacing: GymTheme.pt(8)) {
                Text(progress.displayCaption)
                    .font(GymTheme.progressCaption)
                    .accessibilityIdentifier("workoutProgress")
                    .accessibilityValue(progress.caption)

                GymProgressTrack(fraction: progress.fractionComplete)

                if showsNextLine {
                    Text(progress.upNextLine)
                        .font(GymTheme.meta)
                        .foregroundStyle(GymTheme.muted)
                        .accessibilityIdentifier("nextSetCue")
                }

                if let addSetTitle, let onAddSet {
                    Button(action: onAddSet) {
                        Label(addSetTitle, systemImage: "plus")
                    }
                    .font(GymTheme.caption)
                    .accessibilityIdentifier("addSetToCurrent")
                }

                if let onShowExercises {
                    Button(action: onShowExercises) {
                        Label("Exercises", systemImage: "dumbbell")
                    }
                    .gymExercisesButton()
                    .accessibilityIdentifier("showExerciseMap")
                    .accessibilityHint("Shows every exercise so you can jump or come back later")
                }
            }
            .padding(.horizontal, GymTheme.rowPadX)
            .padding(.vertical, GymTheme.rowPadY)
        }
        .animation(.easeInOut(duration: 0.25), value: progress.fractionComplete)
    }
}

struct RestTakeoverCard: View {
    let remainingSeconds: Int
    let nextLine: String
    var combinedIdentifier: String?

    var body: some View {
        VStack(spacing: GymTheme.pt(12)) {
            Text("Rest")
                .font(GymTheme.section)
                .foregroundStyle(GymTheme.muted)
            CountdownText(
                seconds: remainingSeconds,
                identifier: "restBarCountdown",
                color: Color.primary
            )
            Text(nextLine)
                .font(GymTheme.meta)
                .foregroundStyle(GymTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, GymTheme.pt(28))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifierIfPresent(combinedIdentifier)
        .accessibilityHint("Rest countdown. Adjust or skip from the bar below.")
    }
}

struct RestAdjustControls: View {
    let sessionTimer: SessionTimer

    var body: some View {
        VStack(spacing: GymTheme.pt(8)) {
            Button("Skip rest") { sessionTimer.stop() }
                .gymPrimaryButton()
                .accessibilityIdentifier("skipRest")
                .accessibilityLabel("Skip rest")

            HStack(spacing: GymTheme.pt(8)) {
                Button {
                    sessionTimer.adjustRest(by: -15)
                } label: {
                    Text("−15")
                }
                .gymGhostButton()
                .accessibilityIdentifier("decrementRest")
                .accessibilityLabel("Subtract 15 seconds of rest")

                Button {
                    sessionTimer.adjustRest(by: 15)
                } label: {
                    Text("+15")
                }
                .gymGhostButton()
                .accessibilityIdentifier("incrementRest")
                .accessibilityLabel("Add 15 seconds of rest")
            }
        }
    }
}

/// Mock 3-column live nav: Discard | title | Finish. Avoids iOS 26 glass pills.
struct LiveWorkoutNavBar: View {
    let title: String
    var onDiscard: () -> Void
    var onFinish: () -> Void
    var onAddExercise: (() -> Void)?
    var onAddSet: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: GymTheme.pt(6)) {
            Button("Discard", action: onDiscard)
                .font(GymTheme.navAction)
                .foregroundStyle(GymTheme.fail)
                .buttonStyle(.plain)
                .accessibilityIdentifier("discardWorkout")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .font(GymTheme.navTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("liveWorkoutTitle")

            HStack(spacing: GymTheme.pt(8)) {
                if let onAddExercise {
                    Menu {
                        Button("Add Exercise", systemImage: "plus", action: onAddExercise)
                            .accessibilityIdentifier("addExerciseToolbar")
                        if let onAddSet {
                            Button("Add Set", systemImage: "plus", action: onAddSet)
                        }
                        WorkoutSettingsPickers()
                    } label: {
                        Text("···")
                            .font(GymTheme.navActionEmph)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More")
                }

                Button("Finish", action: onFinish)
                    .font(GymTheme.navActionEmph)
                    .foregroundStyle(.primary)
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityIdentifier("finishWorkout")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, GymTheme.pageGutter)
        .padding(.vertical, GymTheme.pt(8))
        .background(GymTheme.pageFill)
        .background {
            HStack {
                if let onAddExercise {
                    Button("Add Exercise", action: onAddExercise)
                        .accessibilityIdentifier("addExercise")
                }
                if let onAddSet {
                    Button("Add Set", action: onAddSet)
                        .accessibilityIdentifier("addSetToCurrent")
                }
            }
            .font(GymTheme.navAction)
            .opacity(0.015)
        }
    }
}
