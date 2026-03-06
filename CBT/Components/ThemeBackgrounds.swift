import SwiftUI

struct ThemeCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if Theme.isImmersive {
            if colorScheme == .light {
                Color.white
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        } else {
            // Standard Mode
            if colorScheme == .light {
                Color.white
            } else {
                Color(uiColor: .tertiarySystemBackground)
            }
        }
    }
}

struct AuroraBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let activeColorTheme: AppColorTheme

    var body: some View {
        let primary = Color(hex: activeColorTheme.primaryHex)
        let secondary = Color(hex: activeColorTheme.secondaryHex)

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
                        primary.opacity(colorScheme == .dark ? 0.15 : 0.12),
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
                        secondary.opacity(colorScheme == .dark ? 0.10 : 0.06),
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

struct ThemedBackground: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        if themeManager.isImmersive {
            AuroraBackground(activeColorTheme: themeManager.selectedTheme)
        } else {
            Theme.backgroundColor
        }
    }
}
