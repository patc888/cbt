import SwiftUI

struct TimeSettingsSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: title.isEmpty ? 0 : 10) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
        HStack(alignment: .center, spacing: 10) {
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
                    .fixedSize(horizontal: false, vertical: true)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)
            
            Spacer()
            
            content()
                .layoutPriority(1)
        }
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

struct TimeTopHeadlineView: View {
    let title: String
    var subtitle: String? = nil
    var size: CGFloat = 28
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer()
        }
        .frame(height: 44)
    }
}



struct TimeDismissButton: View {
    enum Style {
        case chevron
        case chevronLeft
        case xmarkCircle(background: Color, foreground: Color)
    }

    @Environment(\.dismiss) private var dismiss

    var style: Style = .chevron
    var accessibilityLabel: String = "Close"
    var accessibilityHint: String = "Dismisses this screen"
    var enableHaptics: Bool = true

    var body: some View {
        Button(action: dismissAction) {
            switch style {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.primaryAccent)
                    .padding(8)
            case .chevronLeft:
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.primaryAccent)
                    .padding(8)
            case let .xmarkCircle(background, foreground):
                ZStack {
                    Circle()
                        .fill(background)
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(foreground)
                }
                .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
#if targetEnvironment(macCatalyst)
        .focusable(true)
        .keyboardShortcut(.cancelAction)
#endif
    }

    private func dismissAction() {
        if enableHaptics {
            HapticManager.shared.lightImpact()
        }
        dismiss()
    }
}

struct VersionFooterView: View {
    private var appVersionText: String {
        let shortVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        
        #if DEBUG
        if let buildVersion, !buildVersion.isEmpty {
            return "Version \(shortVersion) (\(buildVersion))"
        }
        #endif
        
        return "Version \(shortVersion)"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(appVersionText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
