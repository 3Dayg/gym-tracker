import SwiftUI
import UIKit

/// Type and spacing from the 240px mock, scaled to the device.
/// Full match is `screenWidth / 240` (~1.64 on iPhone 17); we use 82% of
/// that so type stays large without oversized chrome.
enum GymTheme {
    static let mockArtboard: CGFloat = 240
    static let scaleDamping: CGFloat = 0.82

    static var scale: CGFloat {
        let full = max(UIScreen.main.bounds.width / mockArtboard, 1)
        return max(full * scaleDamping, 1)
    }

    static func pt(_ mockPx: CGFloat) -> CGFloat {
        (mockPx * scale).rounded()
    }

    static let sport = Color(red: 1, green: 0.231, blue: 0.071)
    static let fail = Color(red: 208 / 255, green: 20 / 255, blue: 40 / 255)
    static let red = fail
    static let work = sport
    static let rest = Color.primary
    static let failed = fail
    static let ink = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
    static let muted = Color(red: 92 / 255, green: 92 / 255, blue: 97 / 255)

    static let skippedOpacity = 0.40
    static let completeFillOpacity = 0.08
    static let nextFillOpacity = 0.12
    static let failedFillOpacity = 0.10

    static var cardRadius: CGFloat { pt(12) }
    static var chipRadius: CGFloat { pt(10) }
    static var buttonRadius: CGFloat { pt(12) }
    static var primaryHeight: CGFloat { pt(48) }
    static var ghostHeight: CGFloat { pt(40) }
    static var stepperSize: CGFloat { pt(40) }
    static var stepperGap: CGFloat { pt(12) }
    static var pageGutter: CGFloat { pt(10) }
    static var cardGap: CGFloat { pt(14) }
    static var rowPadY: CGFloat { pt(11) }
    static var rowPadX: CGFloat { pt(12) }
    static var titlePadTop: CGFloat { pt(2) }
    static var titlePadBottom: CGFloat { pt(10) }
    static var progressTrack: CGFloat { pt(4) }
    static var boltMark: CGFloat { pt(36) }

    static var pageFill: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 18 / 255, green: 18 / 255, blue: 18 / 255, alpha: 1)
            }
            return UIColor(red: 243 / 255, green: 238 / 255, blue: 232 / 255, alpha: 1)
        })
    }

    static var cardFill: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 31 / 255, green: 31 / 255, blue: 31 / 255, alpha: 1)
            }
            return .white
        })
    }

    static var hairline: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 58 / 255, green: 58 / 255, blue: 58 / 255, alpha: 1)
            }
            return UIColor(red: 217 / 255, green: 212 / 255, blue: 206 / 255, alpha: 1)
        })
    }

    static var valueWell: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 13 / 255, green: 13 / 255, blue: 13 / 255, alpha: 1)
            }
            return .white
        })
    }

    static var stepperFill: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 42 / 255, green: 42 / 255, blue: 42 / 255, alpha: 1)
            }
            return .white
        })
    }

    static var liveFloor: Color { pageFill }
    static var liveCard: Color { cardFill }

    static var title: Font { .system(size: pt(28), weight: .bold) }
    static var titleTracking: CGFloat { pt(28) * -0.03 }
    static var metricTracking: CGFloat { pt(22) * -0.02 }
    static var sheetTitle: Font { .system(size: pt(20), weight: .semibold) }
    static var exerciseName: Font { .system(size: pt(22), weight: .semibold) }
    static var rowName: Font { .system(size: pt(15), weight: .semibold) }
    static var setIndex: Font { .system(size: pt(12), weight: .regular) }
    static var fieldLabel: Font { .system(size: pt(12), weight: .semibold) }
    static var caption: Font { .system(size: pt(12), weight: .regular) }
    static var progressCaption: Font { .system(size: pt(12), weight: .semibold).monospacedDigit() }
    static var metricNumber: Font { .system(size: pt(22), weight: .bold).monospacedDigit() }
    static var metricUnit: Font { .system(size: pt(11), weight: .semibold) }
    static var primaryButton: Font { .system(size: pt(16), weight: .semibold) }
    static var ghostButton: Font { .system(size: pt(15), weight: .medium) }
    static var exercisesButton: Font { .system(size: pt(16), weight: .bold) }
    static var metricValue: Font { .system(size: pt(22), weight: .bold).monospacedDigit() }
    static var meta: Font { .system(size: pt(12), weight: .regular) }
    static var workLabel: Font { .system(size: pt(13), weight: .semibold) }
    static var navTitle: Font { .system(size: pt(13), weight: .semibold) }
    static var navAction: Font { .system(size: pt(11), weight: .regular) }
    static var navActionEmph: Font { .system(size: pt(11), weight: .semibold) }
    static var section: Font { .system(size: pt(12), weight: .regular) }

    static func applyChrome() {
        let inline = UIFont.systemFont(ofSize: pt(13), weight: .semibold)
        let action = UIFont.systemFont(ofSize: pt(11), weight: .regular)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.font: inline]
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: pt(28), weight: .bold),
            .kern: pt(28) * -0.03
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        let actionAttributes: [NSAttributedString.Key: Any] = [.font: action]
        UIBarButtonItem.appearance().setTitleTextAttributes(actionAttributes, for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes(actionAttributes, for: .highlighted)

        let tabFont = UIFont.systemFont(ofSize: pt(8), weight: .semibold)
        let mutedUI = UIColor(red: 92 / 255, green: 92 / 255, blue: 97 / 255, alpha: 1)
        let sportUI = UIColor(red: 1, green: 0.231, blue: 0.071, alpha: 1)
        let tabItem = UITabBarItemAppearance()
        tabItem.normal.titleTextAttributes = [.font: tabFont, .foregroundColor: mutedUI]
        tabItem.selected.titleTextAttributes = [.font: tabFont, .foregroundColor: sportUI]
        tabItem.normal.iconColor = mutedUI
        tabItem.selected.iconColor = sportUI
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 18 / 255, green: 18 / 255, blue: 18 / 255, alpha: 0.96)
            }
            return UIColor(red: 1, green: 252 / 255, blue: 248 / 255, alpha: 0.96)
        }
        tab.shadowColor = UIColor(red: 217 / 255, green: 212 / 255, blue: 206 / 255, alpha: 1)
        tab.stackedLayoutAppearance = tabItem
        tab.inlineLayoutAppearance = tabItem
        tab.compactInlineLayoutAppearance = tabItem
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = sportUI
        UITabBar.appearance().unselectedItemTintColor = mutedUI
    }

    static var countdown: Font {
        let size = pt(52)
        let base = UIFont.systemFont(ofSize: size, weight: .semibold)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return Font(UIFont(descriptor: descriptor, size: size))
    }

    static var failWell: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 208 / 255, green: 20 / 255, blue: 40 / 255, alpha: 0.22)
            }
            return UIColor(red: 248 / 255, green: 228 / 255, blue: 230 / 255, alpha: 1)
        })
    }
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
        buttonStyle(GymFillButtonStyle(
            fill: GymTheme.sport,
            foreground: .white,
            font: GymTheme.primaryButton,
            height: GymTheme.primaryHeight
        ))
    }

    func gymSecondaryButton() -> some View {
        buttonStyle(.bordered)
            .tint(Color.primary)
            .foregroundStyle(Color.primary)
    }

    func gymGhostButton() -> some View {
        buttonStyle(GymFillButtonStyle(
            fill: .clear,
            foreground: .primary,
            font: GymTheme.ghostButton,
            height: GymTheme.ghostHeight
        ))
    }

    func gymFailButton() -> some View {
        buttonStyle(GymFillButtonStyle(
            fill: GymTheme.failWell,
            foreground: GymTheme.fail,
            font: GymTheme.ghostButton,
            height: GymTheme.ghostHeight
        ))
    }

    func gymExercisesButton() -> some View {
        buttonStyle(GymExercisesButtonStyle())
    }

    func gymMockScreenChrome(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                }
            }
    }
}

struct GymScreenTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(GymTheme.title)
            .tracking(GymTheme.titleTracking)
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, GymTheme.titlePadTop)
            .padding(.bottom, GymTheme.titlePadBottom)
            .accessibilityAddTraits(.isHeader)
    }
}

struct GymSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(GymTheme.section)
            .foregroundStyle(GymTheme.muted)
            .textCase(nil)
            .padding(.horizontal, GymTheme.pt(4))
            .padding(.bottom, GymTheme.pt(6))
    }
}

struct GymProgressTrack: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(GymTheme.hairline.opacity(0.65))
                Capsule()
                    .fill(GymTheme.sport)
                    .frame(width: max(geo.size.width * min(max(fraction, 0), 1), 0))
            }
        }
        .frame(height: GymTheme.progressTrack)
        .accessibilityHidden(true)
    }
}

struct GymFillButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color
    var font: Font = GymTheme.primaryButton
    var height: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(foreground)
            .background(
                fill.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: GymTheme.buttonRadius, style: .continuous)
            )
    }
}

struct GymExercisesButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GymTheme.exercisesButton)
            .frame(maxWidth: .infinity, minHeight: GymTheme.primaryHeight)
            .foregroundStyle(GymTheme.sport)
            .background(fill, in: RoundedRectangle(cornerRadius: GymTheme.buttonRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GymTheme.buttonRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }

    private var fill: Color {
        colorScheme == .dark ? .white : GymTheme.cardFill
    }

    private var border: Color {
        colorScheme == .dark ? .white : GymTheme.sport
    }
}

struct GymStepperButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: GymTheme.pt(16), weight: .semibold))
                .frame(width: GymTheme.stepperSize, height: GymTheme.stepperSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(GymTheme.stepperFill, in: Circle())
        .overlay(Circle().strokeBorder(GymTheme.hairline, lineWidth: 1))
    }
}

struct GymCard<Content: View>: View {
    var padding: CGFloat? = nil
    var fill: Color = GymTheme.cardFill
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding ?? GymTheme.rowPadX)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: GymTheme.cardRadius, style: .continuous))
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
    var font: Font = GymTheme.metricValue
    var controlSize: ControlSize = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(font)
        }
        .buttonStyle(.bordered)
        .tint(Color.primary)
        .foregroundStyle(Color.primary)
        .controlSize(controlSize)
    }
}

struct MetricValueButton: View {
    let value: String
    let unit: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: GymTheme.pt(5)) {
                Text(value)
                    .font(GymTheme.metricNumber)
                    .tracking(GymTheme.metricTracking)
                Text(unit)
                    .font(GymTheme.metricUnit)
                    .foregroundStyle(GymTheme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: GymTheme.pt(44))
            .padding(.horizontal, GymTheme.pt(10))
            .background(
                GymTheme.valueWell,
                in: RoundedRectangle(cornerRadius: GymTheme.pt(10), style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GymTheme.pt(10), style: .continuous)
                    .strokeBorder(GymTheme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) \(unit)")
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
                        .font(GymTheme.caption)
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

    var body: some View {
        Text(Formatters.countdown(seconds))
            .font(GymTheme.countdown)
            .tracking(GymTheme.pt(52) * -0.03)
            .monospacedDigit()
            .foregroundStyle(color)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .accessibilityIdentifierIfPresent(identifier)
            .accessibilityLabel(Formatters.countdown(seconds))
            .accessibilityAddTraits(.updatesFrequently)
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
                .font(GymTheme.caption)
                .foregroundStyle(GymTheme.muted)
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
