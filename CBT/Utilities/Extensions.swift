import SwiftUI

struct CardStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(DSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                    .strokeBorder(
                        Theme.isImmersive ? Color.clear : DSTheme.separator.opacity(0.18),
                        lineWidth: 0.8
                    )
            )
            .cardShadow(colorScheme: colorScheme)
    }
}

extension View {
    func cbtCardShadow(
        colorScheme: ColorScheme,
        opacity: Double = Theme.shadowOpacity,
        radius: CGFloat = Theme.shadowRadius,
        x: CGFloat = 0,
        y: CGFloat = 5
    ) -> some View {
        cardShadow(colorScheme: colorScheme, opacity: opacity, radius: radius, x: x, y: y)
    }

    func cardShadow(
        colorScheme: ColorScheme,
        opacity: Double = Theme.shadowOpacity,
        radius: CGFloat = Theme.shadowRadius,
        x: CGFloat = 0,
        y: CGFloat = 5
    ) -> some View {
        self.shadow(
            color: Color.black.opacity(colorScheme == .light ? 0 : opacity),
            radius: colorScheme == .light ? 0 : radius,
            x: x,
            y: colorScheme == .light ? 0 : y
        )
    }

    func cardStyle() -> some View {
        modifier(CardStyleModifier())
    }

    func dsContentLayout(maxWidth: CGFloat = 800, horizontalPadding: CGFloat = DSSpacing.large) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
    }

    func cbtInputSurface(minHeight: CGFloat? = nil) -> some View {
        self
            .padding(DSSpacing.medium)
            .if(minHeight != nil) { view in
                view.frame(minHeight: minHeight!)
            }
            .background(DSTheme.elevatedFill)
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                    .stroke(DSTheme.separator.opacity(0.18), lineWidth: 1)
            )
    }

    func responsiveMaxWidth(maxWidth: CGFloat? = 800) -> some View {
        frame(maxWidth: maxWidth)
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies a premium press effect with scaling, opacity reduction, and haptic feedback.
    /// - Parameter style: The type of haptic to trigger on press. Pass nil to disable haptics.
    func premiumPressEffect(style: HapticType? = .medium) -> some View {
        self.buttonStyle(PremiumButtonStyle(hapticStyle: style))
    }
}

// MARK: - Premium UI Polish

/// A premium button style that provides scale, opacity, and haptic feedback.
struct PremiumButtonStyle: ButtonStyle {
    var hapticStyle: HapticType? = .medium
    var id: String? = nil // Optional ID to prevent double-firing if nested
    
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled, let style = hapticStyle {
                    HapticManager.shared.trigger(style)
                }
            }
    }
}

struct LayoutMetrics {
    var contentMaxWidth: CGFloat = 800
    var horizontalPadding: CGFloat = 16
    static let floatingToolbarBottomInset: CGFloat = 90

    static func metrics(for sizeClass: UserInterfaceSizeClass?) -> LayoutMetrics {
        var metrics = LayoutMetrics()
        if sizeClass == .regular {
            metrics.horizontalPadding = 24
        }
        return metrics
    }
}
extension Date {
    var timeOnly: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
