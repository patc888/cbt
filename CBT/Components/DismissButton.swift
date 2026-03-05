import SwiftUI

struct DismissButton: View {
    enum Style {
        case chevron
        case xmarkCircle(background: Color, foreground: Color)
    }

    @Environment(\.dismiss) private var dismiss

    var style: Style = .chevron

    var body: some View {
        Button(action: { dismiss() }) {
            switch style {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.primaryColor)
                    .padding(8)
            case let .xmarkCircle(background, foreground):
                ZStack {
                    Circle()
                        .fill(background)
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(foreground)
                }
                .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
#if targetEnvironment(macCatalyst)
        .focusable(true)
        .keyboardShortcut(.cancelAction)
#endif
    }
}
