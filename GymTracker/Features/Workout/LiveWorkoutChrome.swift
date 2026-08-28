import SwiftUI

/// Elapsed / logged / next, plus All sets ↔ Follow along. Shared so the
/// two live presentations feel like the same product.
struct WorkoutProgressHeader: View {
    let startedAt: Date
    let progress: LiveWorkoutProgress
    var isFollowAlong = false
    var showsPresentationToggle = false
    var onTogglePresentation: (() -> Void)?
    var addSetTitle: String?
    var onAddSet: (() -> Void)?

    var body: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 6) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    LabeledContent(
                        "Elapsed",
                        value: Formatters.elapsed(context.date.timeIntervalSince(startedAt))
                    )
                    .accessibilityIdentifier("elapsedWorkoutTime")
                }
                LabeledContent("Logged", value: progress.caption)
                    .accessibilityIdentifier("workoutProgress")
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

                if showsPresentationToggle, let onTogglePresentation {
                    if isFollowAlong {
                        Button("All sets", action: onTogglePresentation)
                            .accessibilityIdentifier("showAllSets")
                            .accessibilityHint("Shows every set in a list")
                    } else {
                        Button("Follow along", action: onTogglePresentation)
                            .accessibilityIdentifier("enterFollowAlong")
                            .accessibilityHint("Shows one set at a time")
                    }
                }
            }
        }
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
