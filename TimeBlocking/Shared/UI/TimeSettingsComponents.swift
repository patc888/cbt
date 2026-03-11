import SwiftUI

struct TimeSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: title.isEmpty ? 0 : 16) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: Theme.fontSizeSection, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
            }

            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .timeSettingsCardStyle()
    }
}

struct TimeSettingsRow<Content: View>: View {
    let icon: String?
    let iconColor: Color?
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(
        icon: String? = nil,
        iconColor: Color? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor ?? Theme.secondaryText)
                    .font(.system(size: 18))
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Spacer()

            content()
                .layoutPriority(1)
        }
    }
}

extension View {
    func timeSettingsCardStyle() -> some View {
        self.modifier(TimeSettingsCardStyleModifier())
    }

    func timeSettingsValueStyle() -> some View {
        self
            .foregroundStyle(.secondary)
            .font(.system(size: 13, weight: .bold, design: .rounded))
    }
}

struct TimeSettingsCardStyleModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .light ? Color.white : Color.black.opacity(0.1))
            .background(.ultraThinMaterial)
            .cornerRadius(Theme.cornerRadiusXLarge)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge)
                    .strokeBorder(
                        Color.primary.opacity(0.05),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .light ? 0 : 0.1),
                radius: colorScheme == .light ? 0 : 10,
                x: 0,
                y: colorScheme == .light ? 0 : 5
            )
    }
}
