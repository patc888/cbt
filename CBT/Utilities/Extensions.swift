import SwiftUI

struct CardStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadiusXLarge)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge)
                    .strokeBorder(
                        Theme.isImmersive ? Color.clear : Color.primary.opacity(0.05),
                        lineWidth: 0.5
                    )
            )
            .cardShadow(colorScheme: colorScheme)
    }
}

extension View {
    func weightTrackerCardShadow(
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
