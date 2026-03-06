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
            .fill(completionState.isCompleted ? themeManager.selectedColor.opacity(0.14) : Theme.tertiaryText.opacity(0.08))
            .frame(width: 30, height: 30)
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

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
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
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(titleStyle)
                            .strikethrough(completionState.isCompleted, color: Theme.secondaryText.opacity(0.7))
                        Text(subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(subtitleStyle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(textOpacity)

                    Spacer(minLength: 8)

                    if let trailingSymbol {
                        Image(systemName: trailingSymbol)
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(themeManager.selectedColor)
                            .frame(width: 36, height: 36)
                            .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                            .accessibilityHidden(true)
                    }
                }

                ctaContent
                    .opacity(textOpacity)
            }
            .padding(Theme.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
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
