import SwiftUI

struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSTypography.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.large)
            .background(themeManager?.selectedColor ?? .accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
    }
}

struct DSSecondaryButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let accent = themeManager?.selectedColor ?? .accentColor
        return configuration.label
            .font(DSTypography.button)
            .foregroundStyle(accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.large)
            .background(accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
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
