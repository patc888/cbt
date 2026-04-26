import SwiftUI

struct TimeSettingsSection<Content: View>: View {
    let title: String
    let content: () -> Content

    init(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: title.isEmpty ? 0 : 16) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.horizontal, 4)
            }

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .cardStyle()
    }
}

struct TimeSettingsRow<Content: View>: View {
    let icon: String?
    let iconColor: Color?
    let title: String
    let subtitle: String?
    let content: () -> Content

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
        HStack(spacing: 12) {
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
                        .lineLimit(1)
                }
            }

            Spacer()

            content()
                .layoutPriority(1)
        }
        .padding(.vertical, 4)
    }
}


extension View {
    func timeSettingsValueStyle() -> some View {
        self
            .foregroundStyle(Theme.primaryAccent)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.primaryAccent.opacity(0.1), in: Capsule())
    }
}

struct WhatIsTimeBlockingCard: View {
    var body: some View {
        NavigationLink(destination: TimeBlockingEducationView()) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What is Time Blocking")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("The secret to extreme productivity.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    benefitRow(icon: "target", text: "Turn abstract goals into concrete appointments.")
                    benefitRow(icon: "bolt.fill", text: "Minimize distractions by focusing on one task.")
                    benefitRow(icon: "sparkles", text: "Perfect for deep work and avoiding burnout.")
                }
                .padding(.vertical, 4)

                HStack {
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("Learn More")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Theme.primaryAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white)
                    .clipShape(Capsule())
                    .adaptiveShadow(color: .black.opacity(0.1), radius: 5, y: 2)
                }
            }
            .padding(24)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Theme.primaryAccent, Theme.primaryAccent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Subtle pattern/shapes
                    GeometryReader { geo in
                        Circle()
                            .fill(.white.opacity(0.05))
                            .frame(width: 150, height: 150)
                            .offset(x: geo.size.width - 75, y: -75)
                        
                        Circle()
                            .fill(.white.opacity(0.05))
                            .frame(width: 100, height: 100)
                            .offset(x: -50, y: geo.size.height - 50)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .adaptiveShadow(color: Theme.primaryAccent.opacity(0.4), radius: 15, x: 0, y: 10)
        }
        .contentShape(Rectangle())
        .buttonStyle(TimeScaleButtonStyle())
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.primaryAccent)
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.95))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
        }
    }
}

struct TimeScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
