import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


// MARK: - Design System (Ported from Weight Tracker)

enum Theme {
    static var activeColorTheme: AppColorTheme {
        if let stored = UserDefaults.standard.string(forKey: "appColorTheme"),
           let theme = AppColorTheme(rawValue: stored) {
            return theme
        }
        return .purple
    }

    static var isImmersive: Bool {
        UserDefaults.standard.bool(forKey: "appThemeImmersive")
    }

    static var primaryPurple: Color {
        Color(hex: activeColorTheme.primaryHex)
    }

    static var secondaryPurple: Color {
        Color(hex: activeColorTheme.secondaryHex)
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryPurple, secondaryPurple],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // UI Colors
    static var backgroundColor: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    static var secondaryBackground: AnyView {
        if isImmersive {
            return AnyView(AuroraBackground())
        }
        return AnyView(backgroundColor)
    }
    
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    
    // Spacing
    static let paddingSmall: CGFloat = 12
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 20
    static let paddingXLarge: CGFloat = 24
    
    // Font Sizes
    static let fontSizeTitle: CGFloat = 28
    static let fontSizeSection: CGFloat = 22
    static let fontSizeSubsection: CGFloat = 18
    static let fontSizeBody: CGFloat = 16
    static let fontSizeSmall: CGFloat = 13
    
    // Corner Radius
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 18
    static let cornerRadiusXLarge: CGFloat = 24
    
    static func unselectedOptionColor(for scheme: ColorScheme) -> Color {
        return scheme == .dark ? Color.gray : Color.secondary
    }
    
    static func toggleBackgroundColor(for scheme: ColorScheme) -> Color {
        return scheme == .dark ? Color.white.opacity(0.12) : Color.gray.opacity(0.08)
    }
}

// MARK: - App Icon

struct AppIconView: View {
    var size: CGFloat = 60
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(Theme.primaryPurple.gradient)
                .frame(width: size, height: size)
            
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: Theme.primaryPurple.opacity(0.3), radius: size * 0.1, x: 0, y: size * 0.05)
    }
}

// MARK: - Backgrounds

struct AuroraBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let activeTheme = Theme.activeColorTheme
        let primary = Color(hex: activeTheme.primaryHex)
        let secondary = Color(hex: activeTheme.secondaryHex)
        
        ZStack {
            if colorScheme == .dark {
                Color(hex: "08080C")
            } else {
                Color(hex: "FAFAFA")
            }
            
            GeometryReader { proxy in
                RadialGradient(
                    colors: [
                        primary.opacity(colorScheme == .dark ? 0.35 : 0.25),
                        primary.opacity(0)
                    ],
                    center: UnitPoint(x: 0.5, y: -0.1),
                    startRadius: 0,
                    endRadius: proxy.size.height * 1.5
                )
            }
            
            GeometryReader { proxy in
                RadialGradient(
                    colors: [
                        secondary.opacity(colorScheme == .dark ? 0.25 : 0.18),
                        secondary.opacity(0)
                    ],
                    center: UnitPoint(x: 0.9, y: 0.9),
                    startRadius: 0,
                    endRadius: proxy.size.width * 1.8
                )
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Components

struct TimeSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: Theme.fontSizeSection, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: Theme.fontSizeSmall, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TimeCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = Theme.paddingLarge
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if colorScheme == .light {
                Color.white
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous))
        .shadow(
            color: Color.black.opacity(colorScheme == .light ? 0.03 : 0.1),
            radius: colorScheme == .light ? 5 : 10,
            x: 0,
            y: colorScheme == .light ? 2 : 5
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .light ? 0.05 : 0.1), lineWidth: 0.5)
        }
    }
}

struct TimeFullAccessCard: View {
    let isPremium: Bool
    var subtitle: String? = nil
    var footnote: String? = nil
    var isLoading: Bool = false
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if !isPremium {
            TimeProUpgradeCard(
                title: "Full Access",
                subtitle: subtitle ?? "Unlock unlimited planning power.",
                ctaTitle: "Update to Full Access",
                footnote: footnote,
                action: action,
                isLoading: isLoading
            )
        } else {
            HStack(alignment: .top, spacing: 16) {
                AppIconView(size: 60)
                    .cornerRadius(14)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("Full Access")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                        
                        statusChip(title: "Activated")
                    }
                    
                    Text(subtitle ?? "All premium features are unlocked.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func statusChip(title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.primaryPurple)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.primaryPurple.opacity(0.1))
            .clipShape(Capsule())
    }
}

struct TimeProUpgradeCard: View {
    var title: String
    var subtitle: String
    var ctaTitle: String
    var footnote: String? = nil
    var action: () -> Void
    var isLoading: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Content
            HStack(alignment: .center, spacing: 16) {
                AppIconView(size: 50)
                    .shadow(color: Theme.primaryPurple.opacity(0.3), radius: 5, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            
            Button(action: {
                HapticManager.shared.mediumImpact()
                action()
            }) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
                .background(Theme.primaryPurple)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .premiumPressEffect()
            .disabled(isLoading)
            
            if let footnote = footnote {
                Text(footnote)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, -4)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.lightImpact()
            action()
        }
    }
}

struct TimeMetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        TimeCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primaryPurple)
                        .padding(8)
                        .background(Theme.primaryPurple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    
                    Text(title)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }
}

// MARK: - Button Styles

struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension View {
    func premiumPressEffect() -> some View {
        self.buttonStyle(PremiumButtonStyle())
    }
    
    @ViewBuilder
    func timeInlineNavigationTitle() -> some View {
#if os(iOS)
        navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}

// Color hex support ported from donor
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}
