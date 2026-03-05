import SwiftUI
import Observation

#if canImport(UIKit)
import UIKit
#endif

struct Theme {
    // Immersive Mode (Full Color Background)
    static var isImmersive: Bool {
        UserDefaults.standard.bool(forKey: "appThemeImmersive")
    }

    // Brand Colors - Dynamic based on Theme
    static var activeColorTheme: AppColorTheme {
        if let stored = UserDefaults.standard.string(forKey: "appColorTheme"),
           let theme = AppColorTheme(rawValue: stored) {
            return theme
        }
        return .purple
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var primaryColor: Color {
        Color(hex: activeColorTheme.primaryHex)
    }

    static var secondaryColor: Color {
        Color(hex: activeColorTheme.secondaryHex)
    }

    // Legacy support (points to primaryColor)
    static var primaryPurple: Color { primaryColor }
    static var secondaryPurple: Color { secondaryColor }

    // UI Colors
    static var cardBackground: AnyView {
        AnyView(ThemeCardBackground())
    }

    #if canImport(UIKit)
    static var backgroundColor: Color {
        Color(UIColor.secondarySystemBackground)
    }
    #else
    static var backgroundColor: Color {
        Color(white: 0.95)
    }
    #endif

    static var secondaryBackground: AnyView {
        if isImmersive {
            return AnyView(AuroraBackground(activeColorTheme: activeColorTheme))
        }
        return AnyView(backgroundColor)
    }

    static var tertiaryBackground: Color {
        #if canImport(UIKit)
        if isImmersive {
            return Color(uiColor: .secondarySystemBackground)
        }
        return Color(uiColor: .tertiarySystemBackground)
        #else
        return Color.secondary.opacity(0.1)
        #endif
    }

    // Text Colors
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color.secondary.opacity(0.7)

    static func unselectedOptionColor(for scheme: ColorScheme) -> Color {
        if scheme == .dark && !isImmersive {
            return Color.gray
        }
        return secondaryText
    }

    static func toggleBackgroundColor(for scheme: ColorScheme) -> Color {
        if scheme == .dark && !isImmersive {
            return Color.white.opacity(0.12)
        }
        return Color.gray.opacity(0.08)
    }

    static func trackBackgroundColor(for scheme: ColorScheme) -> Color {
        if scheme == .dark {
            return Color.white.opacity(0.25)
        }
        return Color.gray.opacity(0.12)
    }

    // Accent Colors
    static let successGreen = Color.green
    static let warningOrange = Color.orange
    static let errorRed = Color.red

    // Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let paddingXLarge: CGFloat = 32

    // Corner Radius
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXLarge: CGFloat = 24

    // Shadows
    static let shadowRadius: CGFloat = 10
    static let shadowOpacity: Double = 0.1
}
