import SwiftUI

enum DSElevation {
    case none
    case low
    case medium

    var radius: CGFloat {
        switch self {
        case .none: return 0
        case .low: return 8
        case .medium: return 14
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .none: return 0
        case .low: return 3
        case .medium: return 6
        }
    }

    var darkOpacity: Double {
        switch self {
        case .none: return 0
        case .low: return 0.08
        case .medium: return 0.14
        }
    }
}

enum DSContentWidth {
    static let readable: CGFloat = 600
    static let standard: CGFloat = 800
}

struct DSScreenPaddingModifier: ViewModifier {
    let maxWidth: CGFloat
    let horizontal: CGFloat
    let bottom: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontal)
            .padding(.bottom, bottom)
    }
}

struct DSCardSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let padding: CGFloat
    let cornerRadius: CGFloat
    let elevation: DSElevation
    let borderOpacity: Double

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DSTheme.separator.opacity(borderOpacity), lineWidth: 0.8)
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? elevation.darkOpacity : 0),
                radius: colorScheme == .dark ? elevation.radius : 0,
                x: 0,
                y: colorScheme == .dark ? elevation.yOffset : 0
            )
    }
}

struct DSInsetSurfaceModifier: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DSTheme.elevatedFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DSTheme.separator.opacity(0.18), lineWidth: 1)
            }
    }
}

extension View {
    func dsScreenContent(
        maxWidth: CGFloat = DSContentWidth.standard,
        horizontalPadding: CGFloat = DSSpacing.large,
        bottomPadding: CGFloat = DSSpacing.xLarge
    ) -> some View {
        modifier(
            DSScreenPaddingModifier(
                maxWidth: maxWidth,
                horizontal: horizontalPadding,
                bottom: bottomPadding
            )
        )
    }

    func dsCardSurface(
        padding: CGFloat = DSSpacing.large,
        cornerRadius: CGFloat = DSCornerRadius.large,
        elevation: DSElevation = .low,
        borderOpacity: Double = 0.18
    ) -> some View {
        modifier(
            DSCardSurfaceModifier(
                padding: padding,
                cornerRadius: cornerRadius,
                elevation: elevation,
                borderOpacity: borderOpacity
            )
        )
    }

    func dsInsetSurface(
        padding: CGFloat = DSSpacing.medium,
        cornerRadius: CGFloat = DSCornerRadius.medium
    ) -> some View {
        modifier(DSInsetSurfaceModifier(padding: padding, cornerRadius: cornerRadius))
    }

    func dsHitTarget(minHeight: CGFloat = 44) -> some View {
        frame(minHeight: minHeight)
            .contentShape(Rectangle())
    }
}
