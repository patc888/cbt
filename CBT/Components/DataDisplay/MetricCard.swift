import SwiftUI

struct MetricCard: View {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let accentColor: Color?

    init(
        icon: String,
        title: String,
        value: String,
        subtitle: String? = nil,
        accentColor: Color? = nil
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.accentColor = accentColor
    }

    private var resolvedAccentColor: Color {
        accentColor ?? themeManager?.selectedColor ?? .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(resolvedAccentColor)

                Spacer(minLength: 0)
            }

            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

enum StatState {
    case neutral
    case success
    case warning
    case urgent
}

struct MiniStatCard: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    var value: String
    var unit: String? = nil
    let icon: String
    var iconColor: Color = Theme.primaryColor
    var valueColor: Color = Theme.primaryText
    var state: StatState = .neutral

    private var backgroundColor: Color {
        switch state {
        case .neutral:
            return colorScheme == .dark ? Color(white: 0.12) : .white
        case .success:
            return Theme.successGreen.opacity(colorScheme == .dark ? 0.15 : 0.08)
        case .warning:
            return Theme.warningOrange.opacity(colorScheme == .dark ? 0.15 : 0.08)
        case .urgent:
            return Theme.errorRed.opacity(colorScheme == .dark ? 0.15 : 0.08)
        }
    }

    private var borderColor: Color {
        switch state {
        case .neutral:
            return Color.primary.opacity(0.04)
        case .success:
            return Theme.successGreen.opacity(0.3)
        case .warning:
            return Theme.warningOrange.opacity(0.3)
        case .urgent:
            return Theme.errorRed.opacity(0.3)
        }
    }

    private var displayIconColor: Color {
        switch state {
        case .neutral: return iconColor
        case .success: return Theme.successGreen
        case .warning: return Theme.warningOrange
        case .urgent: return Theme.errorRed
        }
    }

    private var displayValueColor: Color {
        switch state {
        case .neutral: return valueColor
        case .success: return Theme.successGreen
        case .warning: return Theme.warningOrange
        case .urgent: return Theme.errorRed
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .tracking(1.0)
            }
            .foregroundColor(displayIconColor)
            .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(displayValueColor)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)

                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(displayValueColor.opacity(0.8))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(borderColor, lineWidth: 1.5)
                )
        )
        .weightTrackerCardShadow(colorScheme: colorScheme, opacity: colorScheme == .dark ? (state == .neutral ? 0.02 : 0.05) : 0, radius: colorScheme == .dark ? 4 : 0, y: colorScheme == .dark ? 2 : 0)
    }
}
