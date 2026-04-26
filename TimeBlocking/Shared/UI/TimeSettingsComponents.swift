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
                    .font(.system(size: 25, weight: .bold, design: .rounded))
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
                    .foregroundStyle(iconColor ?? Theme.primaryAccent)
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
            .background {
                ZStack {
                    if colorScheme == .light {
                        Color.white
                    } else {
                        Color.black.opacity(0.1)
                    }

                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous))
            .shadow(
                color: Color.black.opacity(colorScheme == .light ? 0.03 : 0.2),
                radius: colorScheme == .light ? 5 : 15,
                x: 0,
                y: colorScheme == .light ? 2 : 8
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(colorScheme == .light ? 0.05 : 0.1),
                                Color.primary.opacity(colorScheme == .light ? 0.02 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }

}
struct WhatIsTimeBlockingCard: View {
    var body: some View {
        NavigationLink(destination: TimeBlockingEducationView()) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What is Time Blocking")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("The secret to extreme productivity.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 38))
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 10) {
                    benefitRow(icon: "target", text: "Turn abstract goals into concrete appointments.")
                    benefitRow(icon: "bolt.fill", text: "Minimize distractions by focusing on one task.")
                    benefitRow(icon: "sparkles", text: "Perfect for deep work and avoiding burnout.")
                }

                HStack {
                    Spacer()
                    Text("Learn More")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(Theme.primaryAccent.gradient)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous))
            .shadow(color: Theme.primaryAccent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}
