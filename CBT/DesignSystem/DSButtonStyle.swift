import SwiftUI

enum DSButtonVariant {
    case primary
    case secondary
    case neutral
    case destructive
    case inverted
}

enum DSButtonSize {
    case large
    case medium
    case compact
    case icon(CGFloat)

    var font: Font {
        switch self {
        case .large:
            return DSTypography.button
        case .medium:
            return .system(size: 15, weight: .bold, design: .rounded)
        case .compact:
            return .system(size: 13, weight: .bold, design: .rounded)
        case .icon(let size):
            return .system(size: min(max(size * 0.38, 13), 22), weight: .bold, design: .rounded)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .large:
            return DSSpacing.large
        case .medium:
            return DSSpacing.medium
        case .compact:
            return DSSpacing.medium
        case .icon:
            return 0
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .large:
            return DSSpacing.large
        case .medium:
            return DSSpacing.medium
        case .compact:
            return DSSpacing.small
        case .icon:
            return 0
        }
    }

    var minHeight: CGFloat? {
        switch self {
        case .large:
            return 54
        case .medium:
            return 44
        case .compact:
            return 34
        case .icon:
            return nil
        }
    }

    var fixedSide: CGFloat? {
        if case .icon(let side) = self {
            return side
        }
        return nil
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact, .icon:
            return DSCornerRadius.small
        case .large, .medium:
            return DSCornerRadius.medium
        }
    }
}

struct DSButtonStyle: ButtonStyle {
    var variant: DSButtonVariant = .primary
    var size: DSButtonSize = .large
    var expands: Bool = true
    var tint: Color? = nil
    var hapticType: HapticType? = .medium

    func makeBody(configuration: Configuration) -> some View {
        DSButtonStyleBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            variant: variant,
            size: size,
            expands: expands,
            tint: tint,
            hapticType: hapticType
        )
    }
}

struct DSPrimaryButtonStyle: ButtonStyle {
    var size: DSButtonSize = .large
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        DSButtonStyle(variant: .primary, size: size, expands: expands, hapticType: .medium)
            .makeBody(configuration: configuration)
    }
}

struct DSSecondaryButtonStyle: ButtonStyle {
    var size: DSButtonSize = .large
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        DSButtonStyle(variant: .secondary, size: size, expands: expands, hapticType: .light)
            .makeBody(configuration: configuration)
    }
}

struct DSDestructiveButtonStyle: ButtonStyle {
    var size: DSButtonSize = .large
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        DSButtonStyle(variant: .destructive, size: size, expands: expands, hapticType: .warning)
            .makeBody(configuration: configuration)
    }
}

struct DSSelectionButtonStyle: ButtonStyle {
    let isSelected: Bool
    var selectedColor: Color? = nil
    var size: DSButtonSize = .medium
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        DSButtonStyle(
            variant: isSelected ? .primary : .neutral,
            size: size,
            expands: expands,
            tint: selectedColor,
            hapticType: .selection
        )
        .makeBody(configuration: configuration)
    }
}

private struct DSButtonStyleBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let variant: DSButtonVariant
    let size: DSButtonSize
    let expands: Bool
    let tint: Color?
    let hapticType: HapticType?

    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    private var accent: Color {
        tint ?? themeManager?.selectedColor ?? .accentColor
    }

    private var foreground: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return accent
        case .neutral:
            return DSTheme.primaryText
        case .destructive:
            return DSTheme.destructive
        case .inverted:
            return accent
        }
    }

    private var fill: Color {
        switch variant {
        case .primary:
            return accent
        case .secondary:
            return accent.opacity(0.12)
        case .neutral:
            return DSTheme.elevatedFill
        case .destructive:
            return DSTheme.destructive.opacity(0.12)
        case .inverted:
            return .white
        }
    }

    private var stroke: Color {
        switch variant {
        case .primary:
            return accent.opacity(0.0)
        case .secondary:
            return accent.opacity(0.18)
        case .neutral:
            return DSTheme.separator.opacity(0.24)
        case .destructive:
            return DSTheme.destructive.opacity(0.22)
        case .inverted:
            return .white.opacity(0.35)
        }
    }

    var body: some View {
        label
            .font(size.font)
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .lineLimit(size.fixedSide == nil ? 3 : 1)
            .minimumScaleFactor(0.72)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(maxWidth: expands && size.fixedSide == nil ? .infinity : nil)
            .frame(width: size.fixedSide, height: size.fixedSide)
            .frame(minHeight: size.minHeight)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            }
            .opacity(isEnabled ? (isPressed ? 0.86 : 1) : 0.48)
            .saturation(isEnabled ? 1 : 0.55)
            .scaleEffect(isPressed && !reduceMotion ? 0.985 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.24, dampingFraction: 0.76),
                value: isPressed
            )
            .onChange(of: isPressed) { _, isPressed in
                guard isPressed && isEnabled, let hapticType else { return }
                HapticManager.shared.trigger(hapticType)
            }
    }
}

struct DSPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(DSPrimaryButtonStyle())
    }
}

struct DSSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(DSSecondaryButtonStyle())
    }
}
