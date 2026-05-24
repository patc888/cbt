import SwiftUI

struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSTypography.button)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.large)
            .background(themeManager?.selectedColor ?? .accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.24, dampingFraction: 0.76), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled {
                    HapticManager.shared.primaryAction()
                }
            }
    }
}

struct DSSecondaryButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let accent = themeManager?.selectedColor ?? .accentColor
        return configuration.label
            .font(DSTypography.button)
            .foregroundStyle(accent)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.large)
            .background(accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.24, dampingFraction: 0.76), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled {
                    HapticManager.shared.lightImpact()
                }
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
