import SwiftUI

struct DSBullet: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let text: String
}

struct DSFeatureModal: View {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    let title: String
    let subtitle: String?
    let bullets: [DSBullet]
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?
    let showsCloseButton: Bool
    let closeAction: (() -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        bullets: [DSBullet] = [],
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        showsCloseButton: Bool = true,
        closeAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.bullets = bullets
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.showsCloseButton = showsCloseButton
        self.closeAction = closeAction
    }

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                HStack(alignment: .top, spacing: DSSpacing.small) {
                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        Text(title)
                            .font(DSTypography.sectionTitle)
                            .foregroundStyle(DSTheme.primaryText)
                            .multilineTextAlignment(.leading)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.secondaryText)
                        }
                    }

                    Spacer(minLength: DSSpacing.small)

                    if showsCloseButton {
                        Button {
                            closeAction?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(DSTheme.tertiaryText.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !bullets.isEmpty {
                    VStack(alignment: .leading, spacing: DSSpacing.medium) {
                        ForEach(bullets) { bullet in
                            HStack(alignment: .top, spacing: DSSpacing.small) {
                                Image(systemName: bullet.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(accent)
                                    .frame(width: 18)
                                Text(bullet.text)
                                    .font(DSTypography.body)
                                    .foregroundStyle(DSTheme.primaryText)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                VStack(spacing: DSSpacing.small) {
                    DSPrimaryButton(title: primaryTitle, action: primaryAction)

                    if let secondaryTitle, let secondaryAction {
                        DSSecondaryButton(title: secondaryTitle, action: secondaryAction)
                    }
                }
                .padding(.top, DSSpacing.xSmall)
            }
        }
    }
}
