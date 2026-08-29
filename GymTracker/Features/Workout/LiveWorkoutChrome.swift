import SwiftUI

/// Completion, next cue, and the exercise map. Elapsed time is still
/// recorded from `startedAt` at finish — it is not shown live.
struct WorkoutProgressHeader: View {
    let progress: LiveWorkoutProgress
    var addSetTitle: String?
    var onAddSet: (() -> Void)?
    var onShowExercises: (() -> Void)?

    var body: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    ProgressView(value: progress.fractionComplete)
                        .progressViewStyle(.linear)
                        .tint(Color.primary)
                        .accessibilityHidden(true)
                    Text(progress.percentCaption)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .accessibilityIdentifier("workoutProgress")
                        .accessibilityValue(progress.caption)
                }

                Text(progress.nextLine)
                    .font(GymTheme.meta)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("nextSetCue")

                if let addSetTitle, let onAddSet {
                    Button(action: onAddSet) {
                        Label(addSetTitle, systemImage: "plus")
                    }
                    .accessibilityIdentifier("addSetToCurrent")
                }

                if let onShowExercises {
                    Button("Exercises", action: onShowExercises)
                        .accessibilityIdentifier("showExerciseMap")
                        .accessibilityHint("Shows every exercise so you can jump or come back later")
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: progress.fractionComplete)
    }
}

struct RestTakeoverCard: View {
    let remainingSeconds: Int
    let nextLine: String
    var combinedIdentifier: String?

    var body: some View {
        GymCard {
            VStack(spacing: 16) {
                Text("Rest")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(GymTheme.rest)
                CountdownText(
                    seconds: remainingSeconds,
                    identifier: "restBarCountdown",
                    color: GymTheme.rest
                )
                Text(nextLine)
                    .font(GymTheme.meta)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifierIfPresent(combinedIdentifier)
        .accessibilityHint("Rest countdown. Adjust or skip from the bar below.")
    }
}

struct RestAdjustControls: View {
    let sessionTimer: SessionTimer
    var skipProminent = true

    var body: some View {
        HStack(spacing: 8) {
            Button {
                sessionTimer.adjustRest(by: -15)
            } label: {
                Text("−15")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .gymSecondaryButton()
            .accessibilityIdentifier("decrementRest")
            .accessibilityLabel("Subtract 15 seconds of rest")

            Button {
                sessionTimer.adjustRest(by: 15)
            } label: {
                Text("+15")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .gymSecondaryButton()
            .accessibilityIdentifier("incrementRest")
            .accessibilityLabel("Add 15 seconds of rest")

            Button("Skip") { sessionTimer.stop() }
                .modifier(RestSkipStyle(prominent: skipProminent))
                .controlSize(.large)
                .accessibilityIdentifier("skipRest")
                .accessibilityLabel("Skip rest")
        }
    }
}

private struct RestSkipStyle: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content.gymPrimaryButton()
        } else {
            content.gymSecondaryButton()
        }
    }
}
