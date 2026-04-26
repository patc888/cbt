import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


// MARK: - Design System

enum Theme {
    static var activeColorTheme: AppColorTheme {
        if let stored = UserDefaults.standard.string(forKey: "appColorTheme"),
           let theme = AppColorTheme(rawValue: stored) {
            return theme
        }
        return .red
    }

    static var isImmersive: Bool {
        UserDefaults.standard.bool(forKey: "appThemeImmersive")
    }

    static var primaryAccent: Color {
        Color(hex: activeColorTheme.primaryHex)
    }

    static var secondaryAccent: Color {
        Color(hex: activeColorTheme.secondaryHex)
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryAccent, secondaryAccent],
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

    static var background: Color { backgroundColor }

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
    static let fontSizeSection: CGFloat = 24
    static let fontSizeSubsection: CGFloat = 19
    static let fontSizeBody: CGFloat = 17
    static let fontSizeSmall: CGFloat = 14

    // Status Colors
    static var successGreen: Color { Color(hex: "34C759") }
    static var warningOrange: Color { Color(hex: "FF9F0A") }
    static var errorRed: Color { Color(hex: "FF453A") }

    // Corner Radius
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 18
    static let cornerRadiusXLarge: CGFloat = 24

    // Category Colors
    static var categoryFocus: Color { primaryAccent }
    static var categoryPersonal: Color { Color(hex: "F59E0B") } // Amber
    static var categoryAdmin: Color { Color(hex: "0EA5E9") }    // Sky
    static var categoryRoutine: Color { Color(hex: "10B981") }  // Emerald
    static var categoryCustom: Color { Color(hex: "64748B") }   // Slate

    static func color(for category: TimeBlockCategory) -> Color {
        switch category {
        case .focus: return categoryFocus
        case .personal: return categoryPersonal
        case .admin: return categoryAdmin
        case .routine: return categoryRoutine
        case .custom: return categoryCustom
        }
    }


    static func unselectedOptionColor(for scheme: ColorScheme) -> Color {
        return scheme == .dark ? Color.gray : Color.secondary
    }

    static func toggleBackgroundColor(for scheme: ColorScheme) -> Color {
        return scheme == .dark ? Color.white.opacity(0.12) : Color.gray.opacity(0.08)
    }

    // Card Backgrounds
    static var cardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var secondaryCardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .tertiarySystemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

// MARK: - Backgrounds

struct AuroraBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var phase: CGFloat = 0
    @State private var phase2: CGFloat = 0

    var body: some View {
        let activeTheme = Theme.activeColorTheme
        let primary = Color(hex: activeTheme.primaryHex)
        let secondary = Color(hex: activeTheme.secondaryHex)

        ZStack {
            // Base layer
            if colorScheme == .dark {
                Color(hex: "050508")
            } else {
                Color(hex: "FCFCFF")
            }

            // Primary Glow
            GeometryReader { proxy in
                Circle()
                    .fill(primary.opacity(colorScheme == .dark ? 0.35 : 0.18))
                    .frame(width: proxy.size.width * 1.6, height: proxy.size.width * 1.6)
                    .blur(radius: 100)
                    .offset(
                        x: -proxy.size.width * 0.3 + sin(phase) * 40,
                        y: -proxy.size.height * 0.4 + cos(phase) * 30
                    )
            }

            // Secondary Glow
            GeometryReader { proxy in
                Circle()
                    .fill(secondary.opacity(colorScheme == .dark ? 0.25 : 0.15))
                    .frame(width: proxy.size.width * 1.3, height: proxy.size.width * 1.3)
                    .blur(radius: 120)
                    .offset(
                        x: proxy.size.width * 0.5 + cos(phase2) * 50,
                        y: proxy.size.height * 0.6 + sin(phase2) * 40
                    )
            }

            // Center Accent
            GeometryReader { proxy in
                RadialGradient(
                    colors: [
                        primary.opacity(colorScheme == .dark ? 0.12 : 0.06),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: proxy.size.height * 0.6
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: true)) {
                phase2 = .pi * 2
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

struct TimeMetricTile: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let value: String
    let systemImage: String
    var unit: String? = nil
    var iconColor: Color? = nil
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(iconColor ?? Theme.primaryAccent)

                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .tracking(1.0)
                    .foregroundStyle(Theme.primaryText.opacity(0.8))
            }
            .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.primaryText)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)

                if let unit {
                    Text(unit)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.leading, 1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.12) : .white)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(isPressed ? 0.2 : 0.04), lineWidth: 1.5)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            HapticManager.shared.lightImpact()
            withAnimation {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Extensions

extension View {
    @ViewBuilder
    func timeInlineNavigationTitle() -> some View {
#if os(iOS)
        navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}

// Color hex support
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
