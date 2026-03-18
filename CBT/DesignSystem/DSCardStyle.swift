import SwiftUI

enum DSMetricTone {
    case neutral
    case success
    case warning
    case destructive
}

struct DSSectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    init(title: String, subtitle: String? = nil) where Trailing == EmptyView {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.medium) {
            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                Text(title)
                    .font(DSTypography.sectionHeader)
                    .foregroundStyle(DSTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            Spacer(minLength: DSSpacing.small)
            trailing
        }
    }
}

struct DSCardContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(DSSpacing.large)
            .background(DSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                    .stroke(DSTheme.separator.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.14 : 0),
                radius: colorScheme == .dark ? 10 : 0,
                x: 0,
                y: colorScheme == .dark ? 5 : 0
            )
    }
}

struct DSListRow<Trailing: View>: View {
    let icon: String?
    let iconColor: Color?
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(
        icon: String? = nil,
        iconColor: Color? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.medium) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor ?? DSTheme.secondaryText)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DSTypography.listLabel)
                    .foregroundStyle(DSTheme.primaryText)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .foregroundStyle(DSTheme.secondaryText)
        }
        .frame(minHeight: 44)
    }
}

struct DSMetricCard: View {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String
    let icon: String
    let subtitle: String?
    let tone: DSMetricTone

    init(
        title: String,
        value: String,
        icon: String,
        subtitle: String? = nil,
        tone: DSMetricTone = .neutral
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.subtitle = subtitle
        self.tone = tone
    }

    private var accent: Color {
        switch tone {
        case .neutral:
            return themeManager?.selectedColor ?? .accentColor
        case .success:
            return DSTheme.success
        case .warning:
            return DSTheme.warning
        case .destructive:
            return DSTheme.destructive
        }
    }

    private var background: Color {
        switch tone {
        case .neutral:
            return colorScheme == .dark ? Color(white: 0.12) : DSTheme.cardBackground
        case .success, .warning, .destructive:
            return accent.opacity(colorScheme == .dark ? 0.15 : 0.08)
        }
    }

    private var border: Color {
        switch tone {
        case .neutral:
            return Color.primary.opacity(0.04)
        case .success, .warning, .destructive:
            return accent.opacity(0.3)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(DSTypography.cardTitle)
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(accent)
            .textCase(.uppercase)

            Text(value)
                .font(DSTypography.metricValue)
                .foregroundStyle(accent)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(DSTypography.caption)
                    .foregroundStyle(accent.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                        .stroke(border, lineWidth: 1.5)
                )
        )
    }
}
