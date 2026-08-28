import SwiftUI
import UIKit

/// Red / white / black tokens. Neutrals are black or white at opacity —
/// never a fourth named hue.
enum GymTheme {
    static let red = Color.accentColor
    static let work = red
    static let rest = Color.primary
    static let failed = red

    static let skippedOpacity = 0.40
    static let completeFillOpacity = 0.08
    static let nextFillOpacity = 0.12
    static let failedFillOpacity = 0.10

    static let cardRadius: CGFloat = 16
    static let chipRadius: CGFloat = 10

    static var cardFill: Color { Color(.systemBackground) }

    static var countdown: Font {
        let base = UIFont.systemFont(ofSize: 64, weight: .semibold)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let rounded = UIFont(descriptor: descriptor, size: 64)
        return Font(UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: rounded, maximumPointSize: 64))
    }

    static var exerciseName: Font { .title.weight(.semibold) }
    static var setIndex: Font { .headline }
    static var metricValue: Font { .title3.monospacedDigit() }
    static var meta: Font { .subheadline }
}

extension View {
    @ViewBuilder
    func accessibilityIdentifierIfPresent(_ identifier: String?) -> some View {
        if let identifier {
            self.accessibilityIdentifier(identifier)
        } else {
            self
        }
    }

    func gymPrimaryButton() -> some View {
        buttonStyle(.borderedProminent)
            .tint(Color.primary)
    }

    func gymSecondaryButton() -> some View {
        buttonStyle(.bordered)
            .tint(Color.primary)
    }

    func gymFailButton() -> some View {
        buttonStyle(.bordered)
            .tint(GymTheme.red)
            .foregroundStyle(GymTheme.red)
    }
}

struct GymCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GymTheme.cardFill, in: RoundedRectangle(cornerRadius: GymTheme.cardRadius))
    }
}

struct EmptyStateBlock: View {
    let title: String
    let systemImage: String
    let description: String
    var descriptionIdentifier: String?
    var actionTitle: String?
    var actionIdentifier: String?
    var action: (() -> Void)?
    var secondaryActionTitle: String?
    var secondaryActionIdentifier: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
                .accessibilityIdentifierIfPresent(descriptionIdentifier)
        } actions: {
            if let secondaryActionTitle, let secondaryAction {
                Button(secondaryActionTitle, action: secondaryAction)
                    .accessibilityIdentifierIfPresent(secondaryActionIdentifier)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .accessibilityIdentifierIfPresent(actionIdentifier)
            }
        }
    }
}

struct MetricChip: View {
    let text: String
    var font: Font = .subheadline.monospacedDigit()
    var controlSize: ControlSize = .small
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(font)
        }
        .buttonStyle(.bordered)
        .tint(Color.primary)
        .controlSize(controlSize)
    }
}

struct ConfirmDestructiveSheet: View {
    let title: String
    let message: String
    let keepTitle: String
    let deleteTitle: String
    var keepIdentifier: String
    var deleteIdentifier: String
    var warningIdentifier: String?
    let onKeep: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifierIfPresent(warningIdentifier)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(keepTitle, action: onKeep)
                        .accessibilityIdentifier(keepIdentifier)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(deleteTitle, role: .destructive, action: onDelete)
                        .accessibilityIdentifier(deleteIdentifier)
                }
            }
        }
    }
}

struct CountdownText: View {
    let seconds: Int
    var identifier: String?
    var color: Color = Color.primary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Text(Formatters.countdown(seconds))
            .font(GymTheme.countdown)
            .monospacedDigit()
            .foregroundStyle(color)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .accessibilityIdentifierIfPresent(identifier)
            .accessibilityLabel(Formatters.countdown(seconds))
            .accessibilityAddTraits(.updatesFrequently)
            .id(dynamicTypeSize)
    }
}

struct ChartLegendStroke: View {
    var color: Color
    var dashed: Bool = false
    var dotted: Bool = false
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .stroke(color, style: stroke)
                .frame(width: 18, height: 3)
                .accessibilityHidden(true)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .padding(.trailing, 8)
    }

    private var stroke: StrokeStyle {
        if dotted {
            return StrokeStyle(lineWidth: 2, dash: [2, 3])
        }
        if dashed {
            return StrokeStyle(lineWidth: 2, dash: [5, 3])
        }
        return StrokeStyle(lineWidth: 2)
    }
}
