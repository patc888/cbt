import SwiftUI

enum PlanCardCompletionState {
    case notTracked
    case incomplete
    case completed

    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }

    var accessibilityStatus: String? {
        switch self {
        case .completed:
            return "completed"
        case .incomplete:
            return "not completed"
        case .notTracked:
            return nil
        }
    }
}

struct PlanCard<CTAContent: View>: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let trailingSymbol: String?
    let completionState: PlanCardCompletionState
    let ctaContent: CTAContent
    let action: () -> Void

    init(
        title: String,
        subtitle: String,
        trailingSymbol: String? = nil,
        completionState: PlanCardCompletionState = .notTracked,
        @ViewBuilder ctaContent: () -> CTAContent,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingSymbol = trailingSymbol
        self.completionState = completionState
        self.ctaContent = ctaContent()
        self.action = action
    }

    private var checkboxSymbol: String {
        completionState.isCompleted ? "checkmark.circle.fill" : "circle"
    }

    private var checkboxForegroundStyle: AnyShapeStyle {
        if completionState.isCompleted {
            return AnyShapeStyle(themeManager.selectedColor)
        }
        return AnyShapeStyle(Theme.tertiaryText)
    }

    private var checkboxBackground: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: checkboxBackgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 34, height: 34)
            .overlay {
                Circle()
                    .stroke(themeManager.selectedColor.opacity(completionState.isCompleted ? 0.28 : 0.14), lineWidth: 1)
            }
    }

    private var titleStyle: Color {
        completionState.isCompleted ? Theme.primaryText.opacity(0.72) : Theme.primaryText
    }

    private var subtitleStyle: Color {
        completionState.isCompleted ? Theme.secondaryText.opacity(0.72) : Theme.secondaryText
    }

    private var textOpacity: Double {
        completionState.isCompleted ? 0.86 : 1.0
    }

    private var accessibilityLabelText: String {
        if let status = completionState.accessibilityStatus {
            return "\(title), \(status)"
        }
        return title
    }

    private var checkboxBackgroundColors: [Color] {
        if completionState.isCompleted {
            return [
                themeManager.selectedColor.opacity(colorScheme == .dark ? 0.28 : 0.18),
                themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.18 : 0.1)
            ]
        }
        return [
            themeManager.selectedColor.opacity(colorScheme == .dark ? 0.14 : 0.07),
            Theme.tertiaryText.opacity(0.08)
        ]
    }

    private var cardBorderColor: Color {
        completionState.isCompleted
            ? themeManager.selectedColor.opacity(0.24)
            : themeManager.selectedColor.opacity(0.14)
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.mediumImpact()
            action()
        }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        checkboxBackground

                        Image(systemName: checkboxSymbol)
                            .font(.system(size: 20, weight: completionState.isCompleted ? .bold : .semibold))
                            .foregroundStyle(checkboxForegroundStyle)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(titleStyle)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                            .strikethrough(completionState.isCompleted, color: Theme.secondaryText.opacity(0.7))
                        Text(subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(subtitleStyle)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(textOpacity)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 8)

                    if let trailingSymbol {
                        Image(systemName: trailingSymbol)
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(
                                LinearGradient(
                                    colors: [themeManager.selectedColor, themeManager.secondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: Circle()
                            )
                            .shadow(color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.26 : 0.16), radius: 10, x: 0, y: 6)
                            .accessibilityHidden(true)
                    }
                }

                ctaContent
                    .opacity(textOpacity)
            }
            .padding(Theme.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DSTheme.cardBackground)
                    .overlay {
                        LinearGradient(
                            colors: [
                                themeManager.selectedColor.opacity(colorScheme == .dark ? 0.16 : 0.08),
                                themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.1 : 0.04),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(cardBorderColor, lineWidth: 1)
                    }
            }
            .shadow(
                color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.14 : 0.05),
                radius: colorScheme == .dark ? 14 : 8,
                x: 0,
                y: colorScheme == .dark ? 9 : 5
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("Tap to open")
    }
}

extension PlanCard where CTAContent == EmptyView {
    init(
        title: String,
        subtitle: String,
        trailingSymbol: String? = nil,
        completionState: PlanCardCompletionState = .notTracked,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            trailingSymbol: trailingSymbol,
            completionState: completionState,
            ctaContent: { EmptyView() },
            action: action
        )
    }
}
