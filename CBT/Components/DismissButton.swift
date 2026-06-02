import SwiftUI

struct DismissButton: View {
    enum Style {
        case chevron
        case xmarkCircle(background: Color, foreground: Color)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    var style: Style = .chevron

    private var tint: Color {
        switch style {
        case .chevron:
            return themeManager.selectedColor
        case let .xmarkCircle(_, foreground):
            return foreground
        }
    }

    var body: some View {
        Button(action: { dismiss() }) {
            switch style {
            case .chevron:
                Image(systemName: "chevron.right")
                    .accessibilityLabel("Go back")
            case .xmarkCircle:
                Image(systemName: "xmark")
                    .accessibilityLabel("Dismiss")
            }
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(44), expands: false, tint: tint, hapticType: .light))
#if targetEnvironment(macCatalyst)
        .focusable(true)
        .keyboardShortcut(.cancelAction)
#endif
    }
}
