import SwiftUI

struct PlanCard<CTAContent: View>: View {
    let title: String
    let subtitle: String
    let trailingSymbol: String?
    let ctaContent: CTAContent
    let action: () -> Void

    init(
        title: String,
        subtitle: String,
        trailingSymbol: String? = nil,
        @ViewBuilder ctaContent: () -> CTAContent,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingSymbol = trailingSymbol
        self.ctaContent = ctaContent()
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                        Text(subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if let trailingSymbol {
                        Image(systemName: trailingSymbol)
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(Theme.primaryColor)
                            .frame(width: 36, height: 36)
                            .background(Theme.primaryColor.opacity(0.12), in: Circle())
                            .accessibilityHidden(true)
                    }
                }

                ctaContent
            }
            .padding(Theme.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tap to open")
    }
}

extension PlanCard where CTAContent == EmptyView {
    init(
        title: String,
        subtitle: String,
        trailingSymbol: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(title: title, subtitle: subtitle, trailingSymbol: trailingSymbol, ctaContent: { EmptyView() }, action: action)
    }
}
